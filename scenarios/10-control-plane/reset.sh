#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=cluster/lib.sh disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../cluster" && pwd)/lib.sh"
load_vars 10 || true
CP=cka-control-plane
ORIG="$(state_dir 10)/kube-apiserver-original.yaml"

if [ -f "$ORIG" ]; then
  info "restoring the original kube-apiserver manifest on $CP"
  docker cp "$ORIG" "$CP:/etc/kubernetes/manifests/kube-apiserver.yaml"
  info "waiting for the API server to come back"
  retry 180 kx get --raw /readyz || warn "the API server did not become ready within 180s"
else
  warn "no kube-apiserver backup in .state/10 -- leaving the manifest alone"
fi

# the namespace goes first: a ServiceCIDR keeps a finalizer until every
# address allocated from it has been released, so deleting it while the
# Service still holds one blocks indefinitely
ns_delete "${S10_NS:-cka-10}"
_sc_gone() { ! kx get servicecidr "$1" >/dev/null 2>&1; }
if [ -n "${S10_CIDR_NAME:-}" ]; then
  kx delete servicecidr "$S10_CIDR_NAME" --ignore-not-found --timeout=120s >/dev/null 2>&1 || true
  retry 120 _sc_gone "$S10_CIDR_NAME" || \
    warn "ServiceCIDR $S10_CIDR_NAME is still being finalized; it disappears once its addresses are released"
fi
rm -rf "$LAB_ANSWERS/10"
bundle_clear cluster
info "10 reset: manifest restored, ServiceCIDR, namespace and answers/10 removed"
