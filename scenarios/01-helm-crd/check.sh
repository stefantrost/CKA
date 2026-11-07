#!/usr/bin/env bash
# points: 10
# topic: Helm, chart values, CRDs
set -euo pipefail
# shellcheck source=cluster/lib.sh disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../cluster" && pwd)/lib.sh"
require_cluster
load_vars 01
A="$(answers_dir 01)"
F="$A/clusterissuer.yaml"
score_reset

_release_exists() { helm --kube-context "$KCTX" -n "$S01_NS" list -o json | jq -e --arg r "$S01_RELEASE" '.[]|select(.name==$r)'; }
_release_deployed() { helm --kube-context "$KCTX" -n "$S01_NS" list -o json | jq -e --arg r "$S01_RELEASE" '.[]|select(.name==$r and .status=="deployed")'; }
_file_has_crl() { grep -q 'crlDistributionPoints' "$F" && grep -qF "$S01_CRL" "$F"; }
_live_has_crl() {
  kx get clusterissuer "$S01_ISSUER" \
    -o jsonpath='{.spec.selfSigned.crlDistributionPoints[*]}' 2>/dev/null | grep -qF "$S01_CRL"
}
_issuer_ready() {
  [ "$(kx get clusterissuer "$S01_ISSUER" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)" = "True" ]
}

expect 1 "namespace $S01_NS exists" \
  "kubectl get ns $S01_NS failed" \
  kx get ns "$S01_NS"
expect 2 "helm release $S01_RELEASE exists in $S01_NS" \
  "helm -n $S01_NS list shows no release named $S01_RELEASE" \
  _release_exists
expect 1 "helm release status is deployed" \
  "the release exists but its status is not 'deployed'" \
  _release_deployed
expect 1 "cert-manager CRDs are installed" \
  "CRD clusterissuers.cert-manager.io not found -- was the chart installed with crds.enabled=true?" \
  kx get crd clusterissuers.cert-manager.io
expect 2 "answers/01/clusterissuer.yaml contains the CRL entry" \
  "the file does not contain both 'crlDistributionPoints' and $S01_CRL" \
  _file_has_crl
expect 2 "live ClusterIssuer $S01_ISSUER has the CRL entry" \
  "spec.selfSigned.crlDistributionPoints of ClusterIssuer $S01_ISSUER does not contain $S01_CRL (did you apply the file?)" \
  _live_has_crl
expect 1 "ClusterIssuer $S01_ISSUER is Ready" \
  "the ClusterIssuer has no Ready=True condition" \
  _issuer_ready

score_summary 01
