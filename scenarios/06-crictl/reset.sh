#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=cluster/lib.sh disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../cluster" && pwd)/lib.sh"
require_cluster
load_vars 06 || true
ns_delete "${S06_NS:-cka-06}"
rm -rf "$LAB_ANSWERS/06"
bundle_clear cluster
info "06 reset: namespace and answers/06 removed"
