#!/usr/bin/env bash
# points: 16
# topic: NetworkPolicy, egress rules, DNS
set -euo pipefail
# shellcheck source=cluster/lib.sh disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../cluster" && pwd)/lib.sh"
require_cluster
load_vars 08
score_reset

_np_json() { kx -n "$S08_NS" get networkpolicy "$S08_POLICY" -o json 2>/dev/null; }
_np_egress()   { _np_json | jq -e '.spec.policyTypes | index("Egress")' >/dev/null 2>&1; }
_np_selects()  { _np_json | jq -e '.spec.podSelector.matchLabels.app == "backend"' >/dev/null 2>&1; }

_curl() {   # _curl POD HOST PORT
  kx -n "$S08_NS" exec "$1" -- curl -s -m 4 -o /dev/null "http://$2:$3/"
}
_reaches()  { retry 30 _curl "$@"; }
_blocked()  { ! _curl "$@"; }

expect 1 "NetworkPolicy $S08_POLICY exists in $S08_NS" \
  "kubectl -n $S08_NS get networkpolicy $S08_POLICY failed" \
  kx -n "$S08_NS" get networkpolicy "$S08_POLICY"
expect 1 "policyTypes contains Egress" \
  "spec.policyTypes does not list Egress -- a policy with only egress rules still needs it to be explicit" \
  _np_egress
expect 1 "podSelector selects app=backend" \
  "spec.podSelector does not select app=backend (an empty selector would hit every Pod in the namespace)" \
  _np_selects
expect 3 "backend-0 reaches db1:$S08_DB1_PORT" \
  "curl from backend-0 to db1:$S08_DB1_PORT failed -- either the egress rule or DNS egress (UDP/TCP 53 to kube-system) is missing" \
  _reaches backend-0 db1 "$S08_DB1_PORT"
expect 3 "backend-0 reaches db2:$S08_DB2_PORT" \
  "curl from backend-0 to db2:$S08_DB2_PORT failed" \
  _reaches backend-0 db2 "$S08_DB2_PORT"
expect 3 "backend-0 is blocked from vault:$S08_VAULT_PORT" \
  "backend-0 still reaches vault:$S08_VAULT_PORT -- the egress rules are too wide" \
  _blocked backend-0 vault "$S08_VAULT_PORT"
expect 2 "backend-0 is blocked from db1 on the vault port" \
  "backend-0 reached db1:$S08_VAULT_PORT; restrict the rules by port, not only by destination Pod" \
  _blocked backend-0 db1 "$S08_VAULT_PORT"
expect 2 "the probe Pod still reaches vault:$S08_VAULT_PORT" \
  "Pod 'probe' lost its connectivity -- the policy must only apply to app=backend" \
  _reaches probe vault "$S08_VAULT_PORT"

score_summary 08
