#!/usr/bin/env bash
# points: 13
# topic: RBAC, ServiceAccounts, auth can-i
set -euo pipefail
# shellcheck source=cluster/lib.sh disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../cluster" && pwd)/lib.sh"
require_cluster
load_vars 04
score_reset
AS="system:serviceaccount:$S04_NS:$S04_SA"

_can()    { kx auth can-i "$1" "$2" --as "$AS" -n "${3:-$S04_NS}" >/dev/null 2>&1; }
_cannot() { ! _can "$1" "$2" "${3:-$S04_NS}"; }

_rb_binds_sa() {
  kx -n "$S04_NS" get rolebinding "$S04_RB" -o json 2>/dev/null | jq -e \
    --arg sa "$S04_SA" --arg ns "$S04_NS" \
    '.subjects[] | select(.kind=="ServiceAccount" and .name==$sa and ((.namespace // $ns)==$ns))' >/dev/null
}
_rb_role_ref() {
  kx -n "$S04_NS" get rolebinding "$S04_RB" -o json 2>/dev/null | jq -e \
    --arg r "$S04_ROLE" 'select(.roleRef.kind=="Role" and .roleRef.name==$r)' >/dev/null
}

expect 1 "ServiceAccount $S04_SA exists in $S04_NS" \
  "kubectl -n $S04_NS get sa $S04_SA failed" \
  kx -n "$S04_NS" get sa "$S04_SA"
expect 1 "Role $S04_ROLE exists in $S04_NS" \
  "kubectl -n $S04_NS get role $S04_ROLE failed" \
  kx -n "$S04_NS" get role "$S04_ROLE"
expect 1 "RoleBinding $S04_RB references Role $S04_ROLE" \
  "the RoleBinding is missing, or its roleRef is not Role/$S04_ROLE" \
  _rb_role_ref
expect 1 "RoleBinding $S04_RB has the ServiceAccount as subject" \
  "no subject of kind ServiceAccount named $S04_SA in namespace $S04_NS" \
  _rb_binds_sa
expect 2 "can create secrets in $S04_NS" \
  "auth can-i create secrets is 'no' for $AS" \
  _can create secrets
expect 2 "can create configmaps in $S04_NS" \
  "auth can-i create configmaps is 'no' for $AS" \
  _can create configmaps
expect 1 "cannot get secrets in $S04_NS" \
  "the Role grants 'get' on secrets -- only 'create' was asked for" \
  _cannot get secrets
expect 1 "cannot list secrets in $S04_NS" \
  "the Role grants 'list' on secrets" \
  _cannot list secrets
expect 1 "cannot delete configmaps in $S04_NS" \
  "the Role grants 'delete' on configmaps" \
  _cannot delete configmaps
expect 1 "cannot create pods in $S04_NS" \
  "the Role grants create on pods -- resources must be limited to secrets and configmaps" \
  _cannot create pods
expect 1 "cannot create secrets in $S04_OTHER_NS" \
  "the permission leaks into $S04_OTHER_NS -- use a Role+RoleBinding, not a ClusterRoleBinding" \
  _cannot create secrets "$S04_OTHER_NS"

score_summary 04
