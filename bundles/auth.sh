#!/usr/bin/env bash
# Shared starting state for the authentication/authorization scenarios:
#   04 - RBAC (ServiceAccount + Role + RoleBinding)
#   05 - talking to the API server from a Pod with a ServiceAccount token
# Sourced by ensure_bundle, so lib.sh is already loaded. Idempotent.

gen_vars 04 <<VARS
S04_NS=cka-04
S04_SA=sa-$(rand_tag)
S04_ROLE=role-$(rand_tag)
S04_RB=rb-$(rand_tag)
S04_OTHER_NS=cka-04-other
VARS

gen_vars 05 <<VARS
S05_NS=cka-05
S05_SA=api-$(rand_tag)
S05_POD=api-pod-$(rand_tag)
S05_SECRET=known-$(rand_tag)
S05_IMAGE=curlimages/curl:8.11.1
VARS

ns_ensure "$S04_NS"
ns_ensure "$S04_OTHER_NS"
ns_ensure "$S05_NS"

# --- 04: nothing but the namespaces; the SA/Role/RoleBinding are the task. ---

# --- 05: the ServiceAccount and its read access to Secrets are provided. -----
kx -n "$S05_NS" apply -f - >/dev/null <<YAML
apiVersion: v1
kind: ServiceAccount
metadata:
  name: $S05_SA
  namespace: $S05_NS
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
  namespace: $S05_NS
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: secret-reader
  namespace: $S05_NS
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: secret-reader
subjects:
  - kind: ServiceAccount
    name: $S05_SA
    namespace: $S05_NS
---
apiVersion: v1
kind: Secret
metadata:
  name: $S05_SECRET
  namespace: $S05_NS
type: Opaque
stringData:
  flag: cka-lab
YAML
