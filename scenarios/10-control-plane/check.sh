#!/usr/bin/env bash
# points: 16
# topic: static Pods, kube-apiserver flags, ServiceCIDR
set -euo pipefail
# shellcheck source=cluster/lib.sh disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../cluster" && pwd)/lib.sh"
require_cluster
load_vars 10
A="$(answers_dir 10)"
F="$A/etcd-info.txt"
CP=cka-control-plane
score_reset

_norm()  { tr -s ' ' ' ' | tr -d '\r'; }
_file_norm() { [ -f "$F" ] && _norm < "$F"; }

_expected_key()  { nodex "$CP" grep -oE '\-\-key-file=[^ ]+' /etc/kubernetes/manifests/etcd.yaml | head -1 | cut -d= -f2-; }
_expected_expiry() { nodex "$CP" openssl x509 -in /etc/kubernetes/pki/etcd/server.crt -noout -enddate | cut -d= -f2-; }
_expected_cca()  { nodex "$CP" grep -oE '\-\-client-cert-auth=[^ ]+' /etc/kubernetes/manifests/etcd.yaml | head -1 | cut -d= -f2-; }

_has_key()    { _file_norm | grep -qF "$(_expected_key)"; }
_has_expiry() { _file_norm | grep -qF "$(_expected_expiry | _norm)"; }
_has_cca()    { _file_norm | grep -qiE "client-cert-auth:[[:space:]]*$(_expected_cca)"; }

_manifest_flag() {
  nodex "$CP" grep -q -- "--service-node-port-range=$S10_NODEPORT_LO-$S10_NODEPORT_HI" \
    /etc/kubernetes/manifests/kube-apiserver.yaml
}
_live_flag() {
  kx -n kube-system get "pod/kube-apiserver-$CP" -o jsonpath='{.spec.containers[0].command}' 2>/dev/null \
    | grep -q -- "--service-node-port-range=$S10_NODEPORT_LO-$S10_NODEPORT_HI"
}
# Four probes, not one: with the default 30000-32767 range a single random
# nodePort lands inside the new window often enough to pass by accident.
_nodeport_in_range() {
  local i p ok=0
  for i in 1 2 3 4; do
    kx -n "$S10_NS" delete svc "np-probe-$i" --ignore-not-found >/dev/null 2>&1
    kx -n "$S10_NS" create svc nodeport "np-probe-$i" --tcp=80:80 >/dev/null 2>&1 || ok=1
  done
  for i in 1 2 3 4; do
    p="$(kx -n "$S10_NS" get svc "np-probe-$i" -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)"
    if [ -z "$p" ] || [ "$p" -lt "$S10_NODEPORT_LO" ] || [ "$p" -gt "$S10_NODEPORT_HI" ]; then
      ok=1
    fi
    kx -n "$S10_NS" delete svc "np-probe-$i" --ignore-not-found >/dev/null 2>&1
  done
  [ "$ok" -eq 0 ]
}

# Guards so a failing check fails fast: retrying for minutes only makes sense
# once the thing being waited for actually exists.
_wait_live_flag()  { _manifest_flag || return 1; retry 120 _live_flag; }
_wait_nodeport()   { _manifest_flag || return 1; retry 60 _nodeport_in_range; }
_wait_cidr_ready() { kx get servicecidr "$S10_CIDR_NAME" >/dev/null 2>&1 || return 1; retry 180 _cidr_ready; }

_cidr_ok() { [ "$(kx get servicecidr "$S10_CIDR_NAME" -o jsonpath='{.spec.cidrs[0]}' 2>/dev/null)" = "$S10_CIDR" ]; }
_cidr_ready() { [ "$(kx get servicecidr "$S10_CIDR_NAME" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)" = "True" ]; }
_svc_ip_ok() { [ "$(kx -n "$S10_NS" get svc "$S10_SVC" -o jsonpath='{.spec.clusterIP}' 2>/dev/null)" = "$S10_SVC_IP" ]; }

expect 1 "answers/10/etcd-info.txt exists" \
  "the file is missing" \
  test -f "$F"
expect 2 "etcd-info.txt names the etcd key file" \
  "the file does not contain $(_expected_key)" \
  _has_key
expect 2 "etcd-info.txt holds the server certificate expiry" \
  "the file does not contain '$(_expected_expiry)' (take the value after notAfter= verbatim)" \
  _has_expiry
expect 1 "etcd-info.txt holds the client-cert-auth value" \
  "expected a line 'client-cert-auth: $(_expected_cca)'" \
  _has_cca
expect 2 "kube-apiserver.yaml sets --service-node-port-range=$S10_NODEPORT_LO-$S10_NODEPORT_HI" \
  "the flag is not in /etc/kubernetes/manifests/kube-apiserver.yaml on $CP" \
  _manifest_flag
expect 1 "the running kube-apiserver Pod has the flag" \
  "the static Pod has not picked the change up yet, or the manifest is invalid and the Pod never restarted" \
  _wait_live_flag
expect 2 "a new NodePort Service gets a port from the new range" \
  "the nodePort allocated to a test Service is outside $S10_NODEPORT_LO-$S10_NODEPORT_HI" \
  _wait_nodeport
expect 2 "ServiceCIDR $S10_CIDR_NAME covers $S10_CIDR" \
  "kubectl get servicecidr $S10_CIDR_NAME does not report spec.cidrs[0] = $S10_CIDR" \
  _cidr_ok
expect 1 "ServiceCIDR $S10_CIDR_NAME is Ready" \
  "the ServiceCIDR has no Ready=True condition" \
  _wait_cidr_ready
expect 2 "Service $S10_SVC in $S10_NS has clusterIP $S10_SVC_IP" \
  "the Service is missing or its clusterIP is not $S10_SVC_IP -- without the ServiceCIDR the API server rejects that address" \
  _svc_ip_ok

score_summary 10
