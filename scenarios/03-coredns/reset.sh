#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=cluster/lib.sh disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../cluster" && pwd)/lib.sh"
require_cluster
load_vars 03 || true
ORIG="$(state_dir 03)/coredns-original.yaml"
if [ -f "$ORIG" ]; then
  info "restoring the original CoreDNS ConfigMap"
  # patch the Corefile back rather than replacing the object: the stored copy
  # carries a stale resourceVersion and `replace` would fail with a conflict
  COREFILE="$(kx apply --dry-run=client -f "$ORIG" -o jsonpath='{.data.Corefile}')"
  kx -n kube-system patch configmap coredns --type=merge \
    -p "$(jq -n --arg c "$COREFILE" '{data:{Corefile:$c}}')" >/dev/null
  # the restart only shortens the wait -- CoreDNS reloads the Corefile by
  # itself, so a slow rollout must not abort the rest of the reset
  kx -n kube-system rollout restart deploy/coredns >/dev/null
  kx -n kube-system rollout status deploy/coredns --timeout=180s >/dev/null 2>&1 \
    || warn "CoreDNS is still rolling out; the restored Corefile is already in place"
else
  warn "no CoreDNS backup in .state/03 -- leaving the live ConfigMap alone"
fi
ns_delete "${S03_NS:-cka-03}"
rm -rf "$LAB_ANSWERS/03"
bundle_clear cluster
info "03 reset: namespace and answers/03 removed"
