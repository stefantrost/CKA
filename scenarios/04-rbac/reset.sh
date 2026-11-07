#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=cluster/lib.sh disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../cluster" && pwd)/lib.sh"
require_cluster
load_vars 04 || true
ns_delete "${S04_NS:-cka-04}"
ns_delete "${S04_OTHER_NS:-cka-04-other}"
bundle_clear auth
info "04 reset: namespaces removed"
