#!/usr/bin/env bash
# points: 11
# topic: crictl, container runtime, node access
set -euo pipefail
# shellcheck source=cluster/lib.sh disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../cluster" && pwd)/lib.sh"
require_cluster
load_vars 06
A="$(answers_dir 06)"
T="$A/pod-container.txt"
L="$A/pod-container.log"
score_reset

_pod_ok()   { kx -n "$S06_NS" get pod "$S06_POD" >/dev/null 2>&1; }
_pod_node() { [ "$(kx -n "$S06_NS" get pod "$S06_POD" -o jsonpath='{.spec.nodeName}' 2>/dev/null)" = "$S06_NODE" ]; }
_pod_label(){ [ "$(kx -n "$S06_NS" get pod "$S06_POD" -o "jsonpath={.metadata.labels.$S06_LABEL_KEY}" 2>/dev/null)" = "$S06_LABEL_VAL" ]; }
_pod_running() { [ "$(kx -n "$S06_NS" get pod "$S06_POD" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }

# the id kubelet recorded, e.g. containerd://0123abcd...
_live_id() {
  kx -n "$S06_NS" get pod "$S06_POD" -o jsonpath='{.status.containerStatuses[0].containerID}' 2>/dev/null \
    | sed 's#.*://##'
}

_id_matches() {
  local want given
  want="$(_live_id)"; [ -n "$want" ] || return 1
  given="$(awk 'NR==1{print $1}' "$T" 2>/dev/null)"
  [ -n "$given" ] || return 1
  [ "${#given}" -ge 12 ] || return 1
  # crictl prints a truncated id; accept any prefix of the real one
  case "$want" in "$given"*) return 0 ;; *) return 1 ;; esac
}

_runtime_matches() {
  local given want id
  given="$(awk 'NR==1{print $2}' "$T" 2>/dev/null)"
  [ -n "$given" ] || return 1
  id="$(_live_id)"
  want="$(nodex "$S06_NODE" crictl inspect "$id" 2>/dev/null | jq -r '.info.runtimeType' 2>/dev/null)"
  [ -n "$want" ] && [ "$want" != "null" ] || want="io.containerd.runc.v2"
  [ "$given" = "$want" ]
}

_crictl_sees_it() {
  local id; id="$(_live_id)"; [ -n "$id" ] || return 1
  nodex "$S06_NODE" crictl ps -q --no-trunc 2>/dev/null | grep -q "^$id$"
}

_log_has_token() { [ -f "$L" ] && grep -q "$S06_TOKEN" "$L"; }

expect 1 "Pod $S06_POD exists in $S06_NS" \
  "kubectl -n $S06_NS get pod $S06_POD failed" \
  _pod_ok
expect 1 "Pod is Running" \
  "the Pod is not in phase Running" \
  _pod_running
expect 1 "Pod has label $S06_LABEL_KEY=$S06_LABEL_VAL" \
  "the label is missing or has a different value" \
  _pod_label
expect 2 "Pod is scheduled on $S06_NODE" \
  "spec.nodeName is not $S06_NODE -- use nodeName or a nodeSelector on kubernetes.io/hostname" \
  _pod_node
expect 1 "crictl on $S06_NODE sees the container" \
  "the container id from the Pod status is not in 'crictl ps' on $S06_NODE" \
  _crictl_sees_it
expect 3 "pod-container.txt field 1 is the container id" \
  "answers/06/pod-container.txt is missing, or its first field is not (a prefix of) the container id of $S06_POD" \
  _id_matches
expect 1 "pod-container.txt field 2 is the runtimeType" \
  "the second field does not match the runtimeType from 'crictl inspect' (expected io.containerd.runc.v2)" \
  _runtime_matches
expect 1 "pod-container.log contains the expected log line" \
  "answers/06/pod-container.log is missing or does not contain '$S06_TOKEN'" \
  _log_has_token

score_summary 06
