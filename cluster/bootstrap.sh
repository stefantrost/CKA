#!/usr/bin/env bash
# Create the kind cluster and install everything the scenarios assume:
# Calico (so NetworkPolicy is enforced), metrics-server (so `kubectl top`
# and HPAs work) and the jetstack Helm repo (cert-manager is a task, so it
# is deliberately NOT installed here).
set -euo pipefail

# shellcheck source=cluster/lib.sh disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

require_tools docker kind kubectl helm jq

if cluster_exists; then
  info "kind cluster '$KIND_CLUSTER' already exists"
else
  info "creating kind cluster '$KIND_CLUSTER' ($NODE_IMAGE)"
  kind create cluster --config "$LAB_ROOT/cluster/kind.yaml" --wait 120s
fi

kubectl config use-context "$KCTX" >/dev/null

info "installing Calico $CALICO_VERSION"
kx apply --server-side --force-conflicts \
  -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml" >/dev/null

info "waiting for nodes to become Ready"
kx wait --for=condition=Ready nodes --all --timeout=300s >/dev/null
kx -n kube-system rollout status ds/calico-node --timeout=300s >/dev/null

info "installing metrics-server $METRICS_SERVER_VERSION (--kubelet-insecure-tls)"
kx apply -f "https://github.com/kubernetes-sigs/metrics-server/releases/download/${METRICS_SERVER_VERSION}/components.yaml" >/dev/null
kx -n kube-system patch deployment metrics-server --type=json -p \
  '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]' >/dev/null 2>&1 || true
kx -n kube-system rollout status deploy/metrics-server --timeout=300s >/dev/null

info "waiting for metrics to be available (kubectl top node)"
retry 180 kx top node || warn "metrics-server is up but 'kubectl top node' is not answering yet; it usually needs another minute"

info "adding the jetstack Helm repo (cert-manager itself is scenario 01)"
helm repo add jetstack https://charts.jetstack.io >/dev/null 2>&1 || true
helm repo update jetstack >/dev/null

mkdir -p "$LAB_STATE" "$LAB_ANSWERS"

printf '\n%sCluster ready.%s\n' "$C_GRN" "$C_OFF"
kx get nodes -o wide
printf '\nNext: %s./lab.sh list%s\n' "$C_BLD" "$C_OFF"
