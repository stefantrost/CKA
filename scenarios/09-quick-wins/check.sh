#!/usr/bin/env bash
# points: 16
# topic: scaling, QoS classes, kubectl top, kubeconfig
set -euo pipefail
# shellcheck source=cluster/lib.sh disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../cluster" && pwd)/lib.sh"
require_cluster
load_vars 09
A="$(answers_dir 09)"
score_reset

_scaled()  { [ "$(kx -n "$S09_NS" get sts "$S09_STS" -o jsonpath='{.spec.replicas}' 2>/dev/null)" = "$S09_REPLICAS" ]; }
_wait_ready() { _scaled || return 1; retry 120 _ready; }
_ready()   { [ "$(kx -n "$S09_NS" get sts "$S09_STS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)" = "$S09_REPLICAS" ]; }

_besteffort_expected() {
  kx -n "$S09_NS" get pods -o json \
    | jq -r '.items[] | select(.status.qosClass=="BestEffort") | .metadata.name' | sort
}
_besteffort_ok() {
  [ -f "$A/besteffort.txt" ] || return 1
  local want got
  want="$(_besteffort_expected)"
  got="$(grep -v '^[[:space:]]*$' "$A/besteffort.txt" | tr -d '\r' | sort)"
  [ -n "$want" ] && [ "$want" = "$got" ]
}

_exec_ok() { [ -x "$A/$1" ]; }
_top_node_ok() {
  local out; out="$("$A/top-node.sh" 2>/dev/null)" || return 1
  printf '%s' "$out" | grep -q cka-control-plane \
    && printf '%s' "$out" | grep -q cka-worker \
    && printf '%s' "$out" | grep -q cka-worker2
}
_top_pod_ok() {
  local out; out="$("$A/top-pod.sh" 2>/dev/null)" || return 1
  printf '%s' "$out" | grep -q "^$S09_STS-0"
}

# the metrics API can be briefly unavailable (e.g. right after the API server
# restarted), so give the scripts a chance rather than failing on one call
_wait_top_node() { _exec_ok top-node.sh || return 1; retry 90 _top_node_ok; }
_wait_top_pod()  { _exec_ok top-pod.sh  || return 1; retry 90 _top_pod_ok; }

_contexts_ok() {
  [ -f "$A/contexts.txt" ] || return 1
  local n
  n="$(grep -c -E 'purple-context|orange-context|silver-context' "$A/contexts.txt" || true)"
  [ "$n" = "3" ]
}
_current_ctx_ok() { [ -f "$A/current-context.txt" ] && grep -qx "$S09_CTX" "$A/current-context.txt"; }
_cert_ok() {
  [ -f "$A/client-cert.txt" ] || return 1
  openssl x509 -in "$A/client-cert.txt" -noout -subject 2>/dev/null | grep -q "$S09_CERT_CN"
}

expect 2 "a) StatefulSet $S09_STS is scaled to $S09_REPLICAS" \
  "spec.replicas of sts/$S09_STS is not $S09_REPLICAS" \
  _scaled
expect 1 "a) all $S09_REPLICAS Pods are Ready" \
  "status.readyReplicas is not $S09_REPLICAS yet" \
  _wait_ready
expect 3 "b) besteffort.txt lists exactly the BestEffort Pods" \
  "the file is missing or its lines do not match the BestEffort Pods in $S09_NS (expected: $(_besteffort_expected | tr '\n' ' '))" \
  _besteffort_ok
expect 1 "c) top-node.sh is executable" \
  "answers/09/top-node.sh is missing or not executable (chmod +x)" \
  _exec_ok top-node.sh
expect 1 "c) top-node.sh reports all three nodes" \
  "running the script did not print cka-control-plane, cka-worker and cka-worker2 (is 'kubectl top node' answering?)" \
  _wait_top_node
expect 1 "c) top-pod.sh is executable" \
  "answers/09/top-pod.sh is missing or not executable (chmod +x)" \
  _exec_ok top-pod.sh
expect 1 "c) top-pod.sh reports the Pods of $S09_NS" \
  "running the script did not print $S09_STS-0" \
  _wait_top_pod
expect 2 "d) contexts.txt lists all three contexts" \
  "answers/09/contexts.txt does not contain purple-context, orange-context and silver-context" \
  _contexts_ok
expect 1 "d) current-context.txt holds the current context" \
  "answers/09/current-context.txt does not contain exactly '$S09_CTX'" \
  _current_ctx_ok
expect 3 "e) client-cert.txt is the decoded client certificate" \
  "openssl cannot read answers/09/client-cert.txt as a certificate, or its subject is not CN=$S09_CERT_CN" \
  _cert_ok

score_summary 09
