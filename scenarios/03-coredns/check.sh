#!/usr/bin/env bash
# points: 10
# topic: CoreDNS, Corefile, cluster DNS
set -euo pipefail
# shellcheck source=cluster/lib.sh disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../cluster" && pwd)/lib.sh"
require_cluster
load_vars 03
A="$(answers_dir 03)"
B="$A/coredns_backup.yaml"
ORIG="$(state_dir 03)/coredns-original.yaml"
score_reset

_backup_valid() {
  [ -f "$B" ] || return 1
  [ "$(kx apply --dry-run=client -f "$B" -o jsonpath='{.kind}' 2>/dev/null)" = "ConfigMap" ] || return 1
  [ "$(kx apply --dry-run=client -f "$B" -o jsonpath='{.metadata.name}' 2>/dev/null)" = "coredns" ]
}

_backup_is_original() {
  local a b
  a="$(kx apply --dry-run=client -f "$B" -o jsonpath='{.data.Corefile}' 2>/dev/null)" || return 1
  b="$(kx apply --dry-run=client -f "$ORIG" -o jsonpath='{.data.Corefile}' 2>/dev/null)" || return 1
  [ -n "$a" ] && [ "$a" = "$b" ]
}

_svc_ip() { kx -n "$S03_NS" get svc "$S03_SVC" -o jsonpath='{.spec.clusterIP}'; }

_resolves() {   # _resolves FQDN -- resolves AND returns the Service IP
  local fqdn=$1 ip
  ip="$(_svc_ip)" || return 1
  kx -n "$S03_NS" exec dns-test -- nslookup "$fqdn" 2>/dev/null | grep -q "$ip"
}

_resolves_any() {   # name that is not the Service, just has to answer
  kx -n "$S03_NS" exec dns-test -- nslookup "$1" 2>/dev/null | grep -q 'Address'
}

expect 2 "answers/03/coredns_backup.yaml is a valid coredns ConfigMap" \
  "the file is missing, is not valid YAML, or is not the ConfigMap named 'coredns'" \
  _backup_valid
expect 2 "the backup holds the *original* Corefile" \
  "the Corefile in the backup differs from the pristine one -- back up before you edit" \
  _backup_is_original
expect 1 "kubernetes.default.svc.cluster.local still resolves" \
  "the default cluster domain broke; check the Corefile syntax and 'kubectl -n kube-system logs -l k8s-app=kube-dns'" \
  retry 30 _resolves_any kubernetes.default.svc.cluster.local
expect 2 "$S03_SVC.$S03_NS.svc.cluster.local resolves to the Service IP" \
  "the Service does not resolve under cluster.local any more" \
  retry 30 _resolves "$S03_SVC.$S03_NS.svc.cluster.local"
expect 3 "$S03_SVC.$S03_NS.svc.$S03_DOMAIN resolves to the Service IP" \
  "the custom domain $S03_DOMAIN does not resolve -- add it to the 'kubernetes' plugin zones in the Corefile" \
  retry 90 _resolves "$S03_SVC.$S03_NS.svc.$S03_DOMAIN"

score_summary 03
