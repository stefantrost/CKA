#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=cluster/lib.sh disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../cluster" && pwd)/lib.sh"
require_cluster
load_vars 05 || true
ns_delete "${S05_NS:-cka-05}"
rm -rf "$LAB_ANSWERS/05"
bundle_clear auth
info "05 reset: namespace and answers/05 removed"
