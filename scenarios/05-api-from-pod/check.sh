#!/usr/bin/env bash
# points: 10
# topic: ServiceAccount tokens, API access from a Pod
set -euo pipefail
# shellcheck source=cluster/lib.sh disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../cluster" && pwd)/lib.sh"
require_cluster
load_vars 05
A="$(answers_dir 05)"
R="$A/result.json"
score_reset

_pod_running() { [ "$(kx -n "$S05_NS" get pod "$S05_POD" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ]; }
_pod_sa()      { [ "$(kx -n "$S05_NS" get pod "$S05_POD" -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null)" = "$S05_SA" ]; }
_pod_image()   { kx -n "$S05_NS" get pod "$S05_POD" -o jsonpath='{.spec.containers[*].image}' 2>/dev/null | grep -q "$S05_IMAGE"; }
_json_valid()  { [ -f "$R" ] && jq -e . "$R" >/dev/null 2>&1; }
_json_kind()   { [ "$(jq -r '.kind' "$R" 2>/dev/null)" = "SecretList" ]; }
_json_secret() { jq -e --arg n "$S05_SECRET" '.items[] | select(.metadata.name==$n)' "$R" >/dev/null 2>&1; }
# the token really has to work from inside the Pod, not just from your laptop
_live_api_call() {
  # shellcheck disable=SC2016  # $(cat ...) must expand inside the Pod
  kx -n "$S05_NS" exec "$S05_POD" -- sh -c \
    'curl -s --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
       -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
       https://kubernetes.default.svc/api/v1/namespaces/$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)/secrets' \
    2>/dev/null | grep -q '"kind": *"SecretList"'
}

expect 1 "Pod $S05_POD exists in $S05_NS" \
  "kubectl -n $S05_NS get pod $S05_POD failed" \
  kx -n "$S05_NS" get pod "$S05_POD"
expect 1 "Pod $S05_POD is Running" \
  "the Pod is not in phase Running" \
  _pod_running
expect 1 "Pod uses image $S05_IMAGE" \
  "the Pod does not run image $S05_IMAGE" \
  _pod_image
expect 2 "Pod runs as ServiceAccount $S05_SA" \
  "spec.serviceAccountName is not $S05_SA -- without it the Pod gets the 'default' SA and the API answers 403" \
  _pod_sa
expect 1 "the SA token works from inside the Pod" \
  "curl from inside the Pod did not return a SecretList (403 means the wrong ServiceAccount, 401 a bad token path)" \
  _live_api_call
expect 2 "answers/05/result.json is valid JSON" \
  "the file is missing or jq cannot parse it" \
  _json_valid
expect 1 "result.json has kind SecretList" \
  "the top-level .kind is not 'SecretList' -- save the whole API response, not just a part" \
  _json_kind
expect 1 "result.json contains secret $S05_SECRET" \
  "no item named $S05_SECRET in .items[] -- did you list the secrets of namespace $S05_NS?" \
  _json_secret

score_summary 05
