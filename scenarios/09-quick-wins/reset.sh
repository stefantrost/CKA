#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=cluster/lib.sh disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../cluster" && pwd)/lib.sh"
require_cluster
load_vars 09 || true
ns_delete "${S09_NS:-cka-09}"
rm -rf "$LAB_ANSWERS/09"
bundle_clear apps
info "09 reset: namespace and answers/09 removed"
