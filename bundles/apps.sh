#!/usr/bin/env bash
# Shared starting state for the workload scenarios:
#   01 - Helm + cert-manager CRDs      (provides the ClusterIssuer file to edit)
#   02 - Kustomize overlays + HPA      (provides base/staging/prod + live state)
#   07 - Deployment spread             (namespace only)
#   08 - NetworkPolicy                 (backend/db1/db2/vault StatefulSets)
#   09 - Quick wins                    (StatefulSet, QoS zoo, a kubeconfig)
# Sourced by ensure_bundle, so lib.sh is already loaded. Idempotent.

gen_vars 01 <<VARS
S01_NS=cert-manager
S01_RELEASE=cert-manager
S01_ISSUER=selfsigned-$(rand_tag)
S01_CRL=http://crl.cka-lab.local/$(rand_tag).crl
VARS

_min=$(rand_int 2 3)
gen_vars 02 <<VARS
S02_STAGING_NS=cka-02-staging
S02_PROD_NS=cka-02-prod
S02_APP=web
S02_MIN=$_min
S02_MAX=$(( _min + 2 ))
S02_PROD_MAX=$(( _min + 4 ))
S02_CPU=$(rand_pick 50 60 70)
VARS
unset _min

gen_vars 07 <<VARS
S07_NS=cka-07
S07_DEPLOY=spread-$(rand_tag)
S07_REPLICAS=3
S07_C1=web-$(rand_tag)
S07_C2=side-$(rand_tag)
S07_IMAGE1=nginx:1.27-alpine
S07_IMAGE2=busybox:1.36
VARS

gen_vars 08 <<VARS
S08_NS=cka-08
S08_DB1_PORT=$(rand_pick 1111 1211 1311)
S08_DB2_PORT=$(rand_pick 2222 2322 2422)
S08_VAULT_PORT=$(rand_pick 3333 3433 3533)
S08_POLICY=backend-egress
S08_IMAGE=curlimages/curl:8.11.1
VARS

gen_vars 09 <<VARS
S09_NS=cka-09
S09_STS=web
S09_REPLICAS=$(rand_int 3 5)
S09_CTX=$(rand_pick purple-context orange-context silver-context)
S09_CERT_CN=cka-lab-$(rand_tag)
VARS

ns_ensure "$S02_STAGING_NS"
ns_ensure "$S02_PROD_NS"
ns_ensure "$S07_NS"
ns_ensure "$S08_NS"
ns_ensure "$S09_NS"

# ===================================================================== 01 ===
# A ClusterIssuer manifest that is missing spec.selfSigned.crlDistributionPoints.
_a01="$(answers_dir 01)"
if [ ! -f "$_a01/clusterissuer.yaml" ]; then
  cat > "$_a01/clusterissuer.yaml" <<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: $S01_ISSUER
spec:
  selfSigned: {}
YAML
fi

# ===================================================================== 02 ===
_a02="$(answers_dir 02)"
if [ ! -d "$_a02/base" ]; then
  mkdir -p "$_a02/base" "$_a02/staging" "$_a02/prod"

  cat > "$_a02/base/deployment.yaml" <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $S02_APP
spec:
  replicas: 1
  selector:
    matchLabels: { app: $S02_APP }
  template:
    metadata:
      labels: { app: $S02_APP }
    spec:
      containers:
        - name: nginx
          image: nginx:1.27-alpine
          ports: [{ containerPort: 80 }]
          resources:
            requests: { cpu: 50m, memory: 32Mi }
            limits: { cpu: 200m, memory: 128Mi }
YAML

  cat > "$_a02/base/configmap.yaml" <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: $S02_APP-config
data:
  GREETING: hello
  LOG_LEVEL: info
YAML

  cat > "$_a02/base/kustomization.yaml" <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - configmap.yaml
YAML

  cat > "$_a02/staging/namespace-transformer.yaml" <<YAML
apiVersion: builtin
kind: NamespaceTransformer
metadata:
  name: set-namespace
  namespace: $S02_STAGING_NS
setRoleBindingSubjects: none
unsetOnly: false
fieldSpecs:
  - path: metadata/namespace
    create: true
YAML

  cat > "$_a02/staging/patch-deployment.yaml" <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $S02_APP
spec:
  replicas: 1
  template:
    spec:
      containers:
        - name: nginx
          envFrom:
            - configMapRef:
                name: $S02_APP-config
YAML

  cat > "$_a02/staging/kustomization.yaml" <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../base
transformers:
  - namespace-transformer.yaml
patches:
  - path: patch-deployment.yaml
YAML

  sed "s/$S02_STAGING_NS/$S02_PROD_NS/" "$_a02/staging/namespace-transformer.yaml" \
    > "$_a02/prod/namespace-transformer.yaml"
  sed 's/replicas: 1/replicas: 2/' "$_a02/staging/patch-deployment.yaml" \
    > "$_a02/prod/patch-deployment.yaml"
  cp "$_a02/staging/kustomization.yaml" "$_a02/prod/kustomization.yaml"
fi

# the live "before" state: both overlays as provided, ConfigMaps included
kx apply -k "$_a02/staging" >/dev/null
kx apply -k "$_a02/prod" >/dev/null

# ===================================================================== 07 ===
# Namespace only -- building the Deployment is the task.

# ===================================================================== 08 ===
kx -n "$S08_NS" apply -f - >/dev/null <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-ports
  namespace: $S08_NS
data:
  db1.conf: |
    server { listen $S08_DB1_PORT; location / { return 200 "db1\n"; } }
    server { listen $S08_VAULT_PORT; location / { return 200 "db1-alt\n"; } }
  db2.conf: |
    server { listen $S08_DB2_PORT; location / { return 200 "db2\n"; } }
  vault.conf: |
    server { listen $S08_VAULT_PORT; location / { return 200 "vault\n"; } }
YAML

# db1 also listens on the vault port, so the checker can tell a policy that
# restricts by destination Pod from one that restricts by destination + port.
_s08_db() {   # _s08_db NAME PORT [EXTRA_PORT]
  _extra=""
  [ -n "${3:-}" ] && _extra=", { name: alt, port: $3, targetPort: $3 }"
  kx -n "$S08_NS" apply -f - >/dev/null <<YAML
apiVersion: v1
kind: Service
metadata:
  name: $1
  namespace: $S08_NS
spec:
  selector: { app: $1 }
  ports: [{ name: main, port: $2, targetPort: $2 }$_extra]
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: $1
  namespace: $S08_NS
spec:
  serviceName: $1
  replicas: 1
  selector:
    matchLabels: { app: $1 }
  template:
    metadata:
      labels: { app: $1 }
    spec:
      containers:
        - name: nginx
          image: nginx:1.27-alpine
          ports: [{ containerPort: $2 }]
          volumeMounts:
            - name: conf
              mountPath: /etc/nginx/conf.d/default.conf
              subPath: $1.conf
      volumes:
        - name: conf
          configMap:
            name: nginx-ports
YAML
}

_s08_db db1 "$S08_DB1_PORT" "$S08_VAULT_PORT"
unset _extra
_s08_db db2 "$S08_DB2_PORT"
_s08_db vault "$S08_VAULT_PORT"

kx -n "$S08_NS" apply -f - >/dev/null <<YAML
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: $S08_NS
spec:
  clusterIP: None
  selector: { app: backend }
  ports: [{ port: 80 }]
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: backend
  namespace: $S08_NS
spec:
  serviceName: backend
  replicas: 1
  selector:
    matchLabels: { app: backend }
  template:
    metadata:
      labels: { app: backend }
    spec:
      containers:
        - name: curl
          image: $S08_IMAGE
          command: ["sleep", "infinity"]
---
apiVersion: v1
kind: Pod
metadata:
  name: probe
  namespace: $S08_NS
  labels: { app: probe }
spec:
  containers:
    - name: curl
      image: $S08_IMAGE
      command: ["sleep", "infinity"]
YAML

# ===================================================================== 09 ===
kx -n "$S09_NS" apply -f - >/dev/null <<YAML
apiVersion: v1
kind: Service
metadata:
  name: $S09_STS
  namespace: $S09_NS
spec:
  clusterIP: None
  selector: { app: $S09_STS }
  ports: [{ port: 80 }]
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: $S09_STS
  namespace: $S09_NS
spec:
  serviceName: $S09_STS
  replicas: 1
  selector:
    matchLabels: { app: $S09_STS }
  template:
    metadata:
      labels: { app: $S09_STS }
    spec:
      containers:
        - name: nginx
          image: nginx:1.27-alpine
          resources:
            requests: { cpu: 20m, memory: 32Mi }
---
apiVersion: v1
kind: Pod
metadata:
  name: qos-alpha
  namespace: $S09_NS
spec:
  containers: [{ name: c, image: nginx:1.27-alpine }]
---
apiVersion: v1
kind: Pod
metadata:
  name: qos-bravo
  namespace: $S09_NS
spec:
  containers:
    - name: c
      image: nginx:1.27-alpine
      resources:
        requests: { cpu: 10m, memory: 16Mi }
---
apiVersion: v1
kind: Pod
metadata:
  name: qos-charlie
  namespace: $S09_NS
spec:
  containers: [{ name: c, image: nginx:1.27-alpine }]
---
apiVersion: v1
kind: Pod
metadata:
  name: qos-delta
  namespace: $S09_NS
spec:
  containers:
    - name: c
      image: nginx:1.27-alpine
      resources:
        requests: { cpu: 10m, memory: 16Mi }
        limits: { cpu: 10m, memory: 16Mi }
YAML

# a stand-alone kubeconfig to pick apart (not a working cluster credential)
_a09="$(answers_dir 09)"
if [ ! -f "$_a09/kubeconfig" ]; then
  _tmp="$(mktemp -d)"
  openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
    -subj "/CN=$S09_CERT_CN/O=cka-lab-admins" \
    -keyout "$_tmp/tls.key" -out "$_tmp/tls.crt" >/dev/null 2>&1
  _crt="$(base64 < "$_tmp/tls.crt" | tr -d '\n')"
  _key="$(base64 < "$_tmp/tls.key" | tr -d '\n')"
  cat > "$_a09/kubeconfig" <<YAML
apiVersion: v1
kind: Config
current-context: $S09_CTX
clusters:
  - name: purple-cluster
    cluster: { server: https://purple.cka-lab.local:6443 }
  - name: orange-cluster
    cluster: { server: https://orange.cka-lab.local:6443 }
  - name: silver-cluster
    cluster: { server: https://silver.cka-lab.local:6443 }
contexts:
  - name: purple-context
    context: { cluster: purple-cluster, user: purple-user }
  - name: orange-context
    context: { cluster: orange-cluster, user: orange-user }
  - name: silver-context
    context: { cluster: silver-cluster, user: silver-user }
users:
  - name: purple-user
    user:
      client-certificate-data: $_crt
      client-key-data: $_key
  - name: orange-user
    user: { token: orange-token }
  - name: silver-user
    user: { token: silver-token }
YAML
  rm -rf "$_tmp"
  unset _tmp _crt _key
fi

# ------------------------------------------------------------------ waits ---
wait_rollout "$S02_STAGING_NS" deploy "$S02_APP" 180s || warn "02 staging deployment not ready"
wait_rollout "$S02_PROD_NS"    deploy "$S02_APP" 180s || warn "02 prod deployment not ready"
for _n in db1 db2 vault backend; do
  kx -n "$S08_NS" rollout status "sts/$_n" --timeout=180s >/dev/null 2>&1 \
    || warn "08: statefulset $_n not ready"
done
unset _n
kx -n "$S09_NS" rollout status "sts/$S09_STS" --timeout=180s >/dev/null 2>&1 \
  || warn "09: statefulset $S09_STS not ready"
unset _a01 _a02 _a09
