#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=cluster/lib.sh disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../cluster" && pwd)/lib.sh"
require_cluster
load_vars 07 || true
ns_delete "${S07_NS:-cka-07}"
bundle_clear apps
info "07 reset: namespace removed"
