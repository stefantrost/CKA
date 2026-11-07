#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=cluster/lib.sh disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../cluster" && pwd)/lib.sh"
require_cluster
load_vars 01 || true
NS="${S01_NS:-cert-manager}"
REL="${S01_RELEASE:-cert-manager}"
ISSUER="${S01_ISSUER:-}"

if [ -n "$ISSUER" ]; then
  kx delete clusterissuer "$ISSUER" --ignore-not-found >/dev/null 2>&1 || true
fi
helm --kube-context "$KCTX" -n "$NS" uninstall "$REL" >/dev/null 2>&1 || true
for crd in $(kx get crd -o name 2>/dev/null | grep 'cert-manager.io' || true); do
  kx delete "$crd" --ignore-not-found >/dev/null 2>&1 || true
done
ns_delete "$NS"
rm -rf "$LAB_ANSWERS/01"
bundle_clear apps
info "01 reset: release, CRDs, namespace $NS and answers/01 removed"
