#!/usr/bin/env bash
# points: 15
# topic: Kustomize overlays, patches, HPA
set -euo pipefail
# shellcheck source=cluster/lib.sh disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../cluster" && pwd)/lib.sh"
require_cluster
load_vars 02
A="$(answers_dir 02)"
score_reset

_build()        { kx kustomize "$A/$1"; }
_build_ok()     { _build "$1" >/dev/null; }
_no_cm_build()  { ! _build "$1" 2>/dev/null | grep -q '^kind: ConfigMap'; }
_no_cm_files()  { ! grep -rqE 'configMapRef|configMapKeyRef|kind: ConfigMap' "$A"; }
_has_hpa_build() { _build "$1" 2>/dev/null | grep -q '^kind: HorizontalPodAutoscaler'; }

_hpa_name() { kx -n "$1" get hpa -o jsonpath='{.items[0].metadata.name}' 2>/dev/null; }
_hpa_field() { kx -n "$1" get hpa -o "jsonpath={.items[0].$2}" 2>/dev/null; }

_hpa_ok() {   # _hpa_ok NS MAX
  local ns=$1 max=$2
  [ -n "$(_hpa_name "$ns")" ] || return 1
  [ "$(_hpa_field "$ns" 'spec.scaleTargetRef.name')" = "$S02_APP" ] || return 1
  [ "$(_hpa_field "$ns" 'spec.minReplicas')" = "$S02_MIN" ] || return 1
  [ "$(_hpa_field "$ns" 'spec.maxReplicas')" = "$max" ] || return 1
  [ "$(_hpa_field "$ns" 'spec.metrics[0].resource.target.averageUtilization')" = "$S02_CPU" ] || return 1
}

_no_cm_live() { ! kx -n "$1" get configmap "$S02_APP-config" >/dev/null 2>&1; }

expect 1 "staging overlay builds" \
  "kubectl kustomize answers/02/staging exits non-zero" \
  _build_ok staging
expect 1 "prod overlay builds" \
  "kubectl kustomize answers/02/prod exits non-zero" \
  _build_ok prod
expect 1 "staging build renders no ConfigMap" \
  "the staging build still contains a ConfigMap" \
  _no_cm_build staging
expect 1 "prod build renders no ConfigMap" \
  "the prod build still contains a ConfigMap" \
  _no_cm_build prod
expect 1 "no ConfigMap left in any file under answers/02" \
  "a file under answers/02 still mentions 'kind: ConfigMap' or a configMapRef/configMapKeyRef" \
  _no_cm_files
expect 1 "staging build contains a HorizontalPodAutoscaler" \
  "no HorizontalPodAutoscaler in the staging build -- was it added to base/?" \
  _has_hpa_build staging
expect 1 "prod build contains a HorizontalPodAutoscaler" \
  "no HorizontalPodAutoscaler in the prod build" \
  _has_hpa_build prod
expect 3 "live HPA in $S02_STAGING_NS: min=$S02_MIN max=$S02_MAX cpu=$S02_CPU%" \
  "HPA in $S02_STAGING_NS missing or has wrong scaleTargetRef/min/max/target (expected target Deployment $S02_APP, min $S02_MIN, max $S02_MAX, averageUtilization $S02_CPU)" \
  _hpa_ok "$S02_STAGING_NS" "$S02_MAX"
expect 3 "live HPA in $S02_PROD_NS: min=$S02_MIN max=$S02_PROD_MAX cpu=$S02_CPU%" \
  "HPA in $S02_PROD_NS missing or has wrong values (expected max $S02_PROD_MAX from the prod patch)" \
  _hpa_ok "$S02_PROD_NS" "$S02_PROD_MAX"
expect 1 "ConfigMap $S02_APP-config gone from $S02_STAGING_NS" \
  "the ConfigMap is still live in $S02_STAGING_NS -- removing it from the files does not delete it" \
  _no_cm_live "$S02_STAGING_NS"
expect 1 "ConfigMap $S02_APP-config gone from $S02_PROD_NS" \
  "the ConfigMap is still live in $S02_PROD_NS" \
  _no_cm_live "$S02_PROD_NS"

score_summary 02
