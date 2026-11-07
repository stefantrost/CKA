#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=cluster/lib.sh disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../cluster" && pwd)/lib.sh"
require_cluster
load_vars 08 || true
ns_delete "${S08_NS:-cka-08}"
bundle_clear apps
info "08 reset: namespace removed"
