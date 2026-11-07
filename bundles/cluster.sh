#!/usr/bin/env bash
# Shared starting state for the scenarios that touch the cluster itself:
#   03 - CoreDNS custom domain
#   06 - crictl on a worker node
#   10 - etcd / kube-apiserver static Pod manifests
# Sourced by ensure_bundle, so lib.sh is already loaded. Idempotent.
#
# This bundle also takes the backups that the reset scripts restore from:
#   .state/03/coredns-original.yaml
#   .state/10/kube-apiserver-original.yaml

gen_vars 03 <<VARS
S03_NS=cka-03
S03_SVC=web
S03_DOMAIN=custom-domain
VARS

gen_vars 06 <<VARS
S06_NS=cka-06
S06_NODE=$(rand_pick cka-worker cka-worker2)
S06_POD=inspect-$(rand_tag)
S06_LABEL_KEY=tier
S06_LABEL_VAL=$(rand_pick frontend backend cache edge)
S06_TOKEN=cka-$(rand_tag)
S06_IMAGE=busybox:1.36
VARS

_np_lo=$(rand_pick 30500 31500 32100)
gen_vars 10 <<VARS
S10_NS=cka-10
S10_NODEPORT_LO=$_np_lo
S10_NODEPORT_HI=$(( _np_lo + 100 ))
S10_CIDR_NAME=extra-$(rand_tag)
S10_CIDR=10.97.0.0/24
S10_SVC_IP=10.97.0.10
S10_SVC=extra-svc
VARS
unset _np_lo

ns_ensure "$S03_NS"
ns_ensure "$S06_NS"
ns_ensure "$S10_NS"

# --- 03: a Service to resolve, and a busybox Pod with a working nslookup ----
# A Pod spec is almost entirely immutable, so a dns-test Pod that is not
# healthy gets replaced rather than re-applied.
if kx -n "$S03_NS" get pod dns-test >/dev/null 2>&1 \
   && [ "$(kx -n "$S03_NS" get pod dns-test -o jsonpath='{.status.phase}')" != "Running" ]; then
  kx -n "$S03_NS" delete pod dns-test --now >/dev/null 2>&1 || true
fi
kx -n "$S03_NS" apply -f - >/dev/null <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $S03_SVC
  namespace: $S03_NS
spec:
  replicas: 1
  selector:
    matchLabels: { app: $S03_SVC }
  template:
    metadata:
      labels: { app: $S03_SVC }
    spec:
      containers:
        - name: nginx
          image: nginx:1.27-alpine
          ports: [{ containerPort: 80 }]
---
apiVersion: v1
kind: Service
metadata:
  name: $S03_SVC
  namespace: $S03_NS
spec:
  selector: { app: $S03_SVC }
  ports: [{ port: 80, targetPort: 80 }]
---
apiVersion: v1
kind: Pod
metadata:
  name: dns-test
  namespace: $S03_NS
spec:
  containers:
    - name: busybox
      image: busybox:1.28
      command: ["sh", "-c", "while true; do sleep 3600; done"]
YAML

# keep a pristine copy of the CoreDNS ConfigMap for reset.sh
ensure_state_dir 03
if [ ! -f "$(state_dir 03)/coredns-original.yaml" ]; then
  kx -n kube-system get configmap coredns -o yaml > "$(state_dir 03)/coredns-original.yaml"
fi

# --- 06: nothing but the namespace; creating the Pod is the task. ----------

# --- 10: keep a pristine copy of the kube-apiserver static Pod manifest ----
ensure_state_dir 10
if [ ! -f "$(state_dir 10)/kube-apiserver-original.yaml" ]; then
  nodex cka-control-plane cat /etc/kubernetes/manifests/kube-apiserver.yaml \
    > "$(state_dir 10)/kube-apiserver-original.yaml"
fi

wait_rollout "$S03_NS" deploy "$S03_SVC" 180s || warn "deployment $S03_SVC is not ready yet"
kx -n "$S03_NS" wait --for=condition=Ready pod/dns-test --timeout=120s >/dev/null 2>&1 \
  || warn "pod dns-test in $S03_NS is not Ready yet" 
