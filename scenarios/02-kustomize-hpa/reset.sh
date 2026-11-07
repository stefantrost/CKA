#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=cluster/lib.sh disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../cluster" && pwd)/lib.sh"
require_cluster
load_vars 02 || true
ns_delete "${S02_STAGING_NS:-cka-02-staging}"
ns_delete "${S02_PROD_NS:-cka-02-prod}"
rm -rf "$LAB_ANSWERS/02"
bundle_clear apps
info "02 reset: namespaces and answers/02 removed"
