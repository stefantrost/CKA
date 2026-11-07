#!/usr/bin/env bash
# Shared helpers for the CKA practice lab.
# Sourced by lab.sh, cluster/bootstrap.sh, bundles/*.sh and scenarios/*/*.sh.
# Written for bash 3.2 (macOS default): no associative arrays, no mapfile.

# ---------------------------------------------------------------- paths ----

LAB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export LAB_ROOT
export LAB_STATE="$LAB_ROOT/.state"
export LAB_ANSWERS="$LAB_ROOT/answers"
export LAB_SCENARIOS="$LAB_ROOT/scenarios"
export LAB_BUNDLES="$LAB_ROOT/bundles"

export KIND_CLUSTER="cka"
export KCTX="kind-cka"
export NODE_IMAGE="kindest/node:v1.35.8"
export CALICO_VERSION="v3.33.0"
export METRICS_SERVER_VERSION="v0.9.1"

# ---------------------------------------------------------------- colors ---

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'
  C_BLU=$'\033[34m'; C_BLD=$'\033[1m';  C_OFF=$'\033[0m'
else
  C_RED=''; C_GRN=''; C_YEL=''; C_BLU=''; C_BLD=''; C_OFF=''
fi
export C_RED C_GRN C_YEL C_BLU C_BLD C_OFF

info()  { printf '%s==>%s %s\n' "$C_BLU" "$C_OFF" "$*"; }
warn()  { printf '%s[!]%s %s\n' "$C_YEL" "$C_OFF" "$*" >&2; }
die()   { printf '%s[x]%s %s\n' "$C_RED" "$C_OFF" "$*" >&2; exit 1; }

# ------------------------------------------------------------ kubectl ------

# All cluster access goes through the lab context, never the user's default.
kx() { kubectl --context "$KCTX" "$@"; }

# Run a command on a kind node ("ssh to a node" in task texts).
nodex() { local node=$1; shift; docker exec "$node" "$@"; }

# ------------------------------------------------------------ tooling ------

tool_hint() {
  case "$1" in
    docker)  printf '%s' "Install Docker Desktop: https://docs.docker.com/desktop/" ;;
    kind)    printf '%s' "brew install kind   (or https://kind.sigs.k8s.io/docs/user/quick-start/#installation)" ;;
    kubectl) printf '%s' "brew install kubernetes-cli   (or https://kubernetes.io/docs/tasks/tools/)" ;;
    helm)    printf '%s' "brew install helm   (or https://helm.sh/docs/intro/install/)" ;;
    jq)      printf '%s' "brew install jq" ;;
    openssl) printf '%s' "brew install openssl" ;;
    *)       printf '%s' "see the tool's documentation" ;;
  esac
}

require_tools() {
  local missing=0 t
  for t in "$@"; do
    if ! command -v "$t" >/dev/null 2>&1; then
      printf '%s[x]%s %s not found. Install it with:\n      %s\n' \
        "$C_RED" "$C_OFF" "$t" "$(tool_hint "$t")" >&2
      missing=1
    fi
  done
  [ "$missing" -eq 0 ] || die "missing required tools (see above)"
  if printf '%s\n' "$@" | grep -qx docker && ! docker info >/dev/null 2>&1; then
    die "docker is installed but the daemon is not reachable. Start Docker Desktop."
  fi
}

cluster_exists() { kind get clusters 2>/dev/null | grep -qx "$KIND_CLUSTER"; }

require_cluster() {
  cluster_exists || die "cluster '$KIND_CLUSTER' does not exist. Run: ./lab.sh up"
  kx version >/dev/null 2>&1 || die "cannot reach the cluster. Try: ./lab.sh down && ./lab.sh up"
}

# ------------------------------------------------------------- state -------

# Per-scenario state lives in .state/NN/ : randomised vars, rendered task,
# timers and backups of anything the scenario changed outside its namespaces.
state_dir() { printf '%s/%s' "$LAB_STATE" "$1"; }

ensure_state_dir() { mkdir -p "$(state_dir "$1")"; }

vars_file() { printf '%s/vars.env' "$(state_dir "$1")"; }

load_vars() {
  local f; f="$(vars_file "$1")"
  # shellcheck disable=SC1090
  [ -f "$f" ] && . "$f"
}

# rand_int LO HI -> random integer in [LO,HI]
rand_int() {
  local lo=$1 span=$(( $2 - $1 + 1 ))
  printf '%s' $(( lo + RANDOM % span ))
}

# rand_pick a b c -> one of the arguments
rand_pick() {
  local n=$# i
  i=$(( RANDOM % n + 1 ))
  eval "printf '%s' \"\${$i}\""
}

# rand_tag -> short lowercase hex suffix
rand_tag() {
  local s
  s="$(LC_ALL=C head -c 8 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  printf '%s' "${s:0:4}"
}

# gen_vars NN  <<EOF ... EOF
# Writes the randomised variables for a scenario, but only the first time:
# re-running a setup must not change values the task text already quoted.
# The variables are sourced into the current shell either way.
gen_vars() {
  local nn=$1 f
  ensure_state_dir "$nn"
  f="$(vars_file "$nn")"
  if [ -f "$f" ]; then
    cat >/dev/null
  else
    cat > "$f"
  fi
  load_vars "$nn"
}

# ------------------------------------------------------------- tasks -------

# render_task NN : expand {{VAR}} placeholders in scenarios/NN-*/task.md using
# the variables from .state/NN/vars.env, writing .state/NN/task.md
render_task() {
  local nn=$1 tmpl out line name
  tmpl="$(scenario_dir "$nn")/task.md"
  out="$(state_dir "$nn")/task.md"
  ensure_state_dir "$nn"
  load_vars "$nn"
  : > "$out"
  while IFS= read -r line || [ -n "$line" ]; do
    while [[ "$line" =~ \{\{([A-Z0-9_]+)\}\} ]]; do
      name="${BASH_REMATCH[1]}"
      eval "line=\${line//\{\{$name\}\}/\${$name:-<unset:$name>}}"
    done
    printf '%s\n' "$line"
  done < "$tmpl" >> "$out"
  printf '%s' "$out"
}

scenario_dir() {
  local nn=$1 d
  # shellcheck disable=SC2012  # scenario dirs are NN-name, no odd characters
  d="$(ls -d "$LAB_SCENARIOS/$nn"-* 2>/dev/null | head -1)"
  [ -n "$d" ] || die "no scenario '$nn' under $LAB_SCENARIOS"
  printf '%s' "$d"
}

# shellcheck disable=SC2012
scenario_ids() { ls -d "$LAB_SCENARIOS"/[0-9][0-9]-* 2>/dev/null | sed 's#.*/##; s/-.*//'; }

scenario_name() { scenario_dir "$1" | sed 's#.*/##'; }

scenario_points() {
  local d; d="$(scenario_dir "$1")"
  grep -m1 '^# *points:' "$d/check.sh" 2>/dev/null | sed 's/.*: *//'
}

answers_dir() {
  local d="$LAB_ANSWERS/$1"
  mkdir -p "$d"
  printf '%s' "$d"
}

# ------------------------------------------------------------ bundles ------

# Several scenarios share one starting state. ensure_bundle runs a bundle
# once per cluster; bundle scripts are themselves idempotent, so re-running
# is harmless -- the marker only avoids the wait time.
ensure_bundle() {
  local b=$1 marker
  marker="$LAB_STATE/bundles/$b.done"
  mkdir -p "$LAB_STATE/bundles"
  if [ -f "$marker" ] && [ "${FORCE_BUNDLE:-0}" != "1" ]; then
    info "bundle '$b' already set up (delete $marker to force)"
    return 0
  fi
  info "setting up shared bundle '$b'"
  # shellcheck disable=SC1090
  . "$LAB_BUNDLES/$b.sh"
  touch "$marker"
}

bundle_clear() { rm -f "$LAB_STATE/bundles/$1.done"; }

# ------------------------------------------------------------ scoring ------

SCORE_TOTAL=0
SCORE_MAX=0
SCORE_FAILS=0

score_reset() { SCORE_TOTAL=0; SCORE_MAX=0; SCORE_FAILS=0; }

# expect POINTS "description" "reason shown on failure" command...
# The command runs with stdout/stderr suppressed; its exit code is the verdict.
expect() {
  local pts=$1 desc=$2 reason=$3; shift 3
  SCORE_MAX=$(( SCORE_MAX + pts ))
  if "$@" >/dev/null 2>&1; then
    SCORE_TOTAL=$(( SCORE_TOTAL + pts ))
    printf '%s[PASS]%s %-58s %s/%s\n' "$C_GRN" "$C_OFF" "$desc" "$pts" "$pts"
  else
    SCORE_FAILS=$(( SCORE_FAILS + 1 ))
    printf '%s[FAIL]%s %-58s %s/%s\n' "$C_RED" "$C_OFF" "$desc" "0" "$pts"
    printf '       %s-> %s%s\n' "$C_YEL" "$reason" "$C_OFF"
  fi
}

score_summary() {
  local nn=$1
  printf '\n%s%s  score: %s/%s points%s\n' \
    "$C_BLD" "scenario $nn" "$SCORE_TOTAL" "$SCORE_MAX" "$C_OFF"
  [ -n "${LAB_SCORE_FILE:-}" ] && \
    printf '%s %s %s\n' "$nn" "$SCORE_TOTAL" "$SCORE_MAX" >> "$LAB_SCORE_FILE"
  return 0
}

# ------------------------------------------------------------- waits -------

# retry SECONDS command... : run until it succeeds or the budget runs out
retry() {
  local budget=$1; shift
  local deadline=$(( $(date +%s) + budget ))
  while :; do
    if "$@" >/dev/null 2>&1; then return 0; fi
    [ "$(date +%s)" -ge "$deadline" ] && return 1
    sleep 2
  done
}

wait_rollout() {
  local ns=$1 kind=$2 name=$3 to=${4:-180s}
  kx -n "$ns" rollout status "$kind/$name" --timeout="$to" >/dev/null 2>&1
}

wait_pod_ready() {
  local ns=$1 sel=$2 to=${3:-180s}
  kx -n "$ns" wait --for=condition=Ready pod -l "$sel" --timeout="$to" >/dev/null 2>&1
}

ns_ensure() {
  kx get ns "$1" >/dev/null 2>&1 || kx create ns "$1" >/dev/null
}

# Deleting a namespace has to finish before anything re-creates objects in
# it, otherwise the next setup races the terminating namespace.
ns_delete() {
  kx get ns "$1" >/dev/null 2>&1 || return 0
  kx delete ns "$1" --timeout=180s >/dev/null 2>&1 || true
  retry 60 _ns_gone "$1" || warn "namespace $1 is still terminating"
}

_ns_gone() { ! kx get ns "$1" >/dev/null 2>&1; }

# -------------------------------------------------------------- timer ------

timer_start() {
  ensure_state_dir "$1"
  date +%s > "$(state_dir "$1")/started_at"
}

timer_elapsed() {
  local f; f="$(state_dir "$1")/started_at"
  [ -f "$f" ] || { printf 'n/a'; return 0; }
  local start now d
  start=$(cat "$f"); now=$(date +%s); d=$(( now - start ))
  printf '%dm %02ds' $(( d / 60 )) $(( d % 60 ))
}
