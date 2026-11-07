#!/usr/bin/env bash
# points: 12
# topic: scheduling, podAntiAffinity, topology spread
set -euo pipefail
# shellcheck source=cluster/lib.sh disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../cluster" && pwd)/lib.sh"
require_cluster
load_vars 07
score_reset
JP_PODS='{range .items[*]}{.metadata.name}{" "}{.status.phase}{" "}{.spec.nodeName}{"\n"}{end}'

_deploy_json() { kx -n "$S07_NS" get deploy "$S07_DEPLOY" -o json 2>/dev/null; }

_replicas_ok() { [ "$(kx -n "$S07_NS" get deploy "$S07_DEPLOY" -o jsonpath='{.spec.replicas}' 2>/dev/null)" = "$S07_REPLICAS" ]; }

_containers_ok() {
  local names images
  names="$(kx -n "$S07_NS" get deploy "$S07_DEPLOY" -o jsonpath='{.spec.template.spec.containers[*].name}' 2>/dev/null)"
  images="$(kx -n "$S07_NS" get deploy "$S07_DEPLOY" -o jsonpath='{.spec.template.spec.containers[*].image}' 2>/dev/null)"
  [ "$names" = "$S07_C1 $S07_C2" ] && [ "$images" = "$S07_IMAGE1 $S07_IMAGE2" ]
}

_spread_configured() {
  _deploy_json | jq -e '
    (.spec.template.spec.affinity.podAntiAffinity // empty) as $aa
    | select($aa != null)' >/dev/null 2>&1 \
  || _deploy_json | jq -e '
    .spec.template.spec.topologySpreadConstraints[]?
    | select(.topologyKey=="kubernetes.io/hostname")' >/dev/null 2>&1
}

_owned_pods() {   # name phase node, one per line, only Pods of this Deployment
  kx -n "$S07_NS" get pods -o jsonpath="$JP_PODS" 2>/dev/null | grep "^$S07_DEPLOY-" || true
}

_running_count()  { _owned_pods | awk '$2=="Running"' | wc -l | tr -d ' '; }
_pending_count()  { _owned_pods | awk '$2=="Pending"' | wc -l | tr -d ' '; }

_two_running()    { [ "$(_running_count)" = "2" ]; }
_one_pending()    { [ "$(_pending_count)" = "1" ]; }
_distinct_nodes() {
  local n
  n="$(_owned_pods | awk '$2=="Running"{print $3}' | sort -u | wc -l | tr -d ' ')"
  [ "$n" = "$(_running_count)" ] && [ "$n" -ge 2 ]
}

expect 1 "Deployment $S07_DEPLOY exists in $S07_NS" \
  "kubectl -n $S07_NS get deploy $S07_DEPLOY failed" \
  kx -n "$S07_NS" get deploy "$S07_DEPLOY"
expect 1 "spec.replicas is $S07_REPLICAS" \
  "the Deployment does not request $S07_REPLICAS replicas" \
  _replicas_ok
expect 3 "containers are exactly $S07_C1/$S07_IMAGE1 and $S07_C2/$S07_IMAGE2" \
  "container names or images differ, or they are in the wrong order (expected names '$S07_C1 $S07_C2' and images '$S07_IMAGE1 $S07_IMAGE2')" \
  _containers_ok
expect 2 "podAntiAffinity or topologySpreadConstraints on kubernetes.io/hostname" \
  "neither spec.template.spec.affinity.podAntiAffinity nor a topologySpreadConstraint with topologyKey kubernetes.io/hostname is set" \
  _spread_configured
expect 2 "exactly 2 Pods are Running" \
  "the number of Running Pods of $S07_DEPLOY is not 2 (got $(_running_count))" \
  _two_running
expect 2 "exactly 1 Pod stays Pending" \
  "the number of Pending Pods is not 1 (got $(_pending_count)) -- with a hard anti-affinity the third replica cannot be placed" \
  _one_pending
expect 1 "the Running Pods sit on different nodes" \
  "two Running Pods share a node -- the constraint is soft (preferredDuringScheduling / whenUnsatisfiable: ScheduleAnyway)" \
  _distinct_nodes

score_summary 07
