#!/usr/bin/env bash
# CKA practice lab -- entrypoint. See README.md.
set -euo pipefail

# shellcheck source=cluster/lib.sh disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/cluster/lib.sh"

usage() {
  cat <<USAGE
${C_BLD}CKA practice lab${C_OFF}

  ./lab.sh up                 create the kind cluster and install Calico,
                              metrics-server and the jetstack Helm repo
  ./lab.sh down               delete the kind cluster
  ./lab.sh status             show cluster and scenario state
  ./lab.sh list               list scenarios with their maximum points

  ./lab.sh start NN           set up scenario NN, print the task, start a timer
  ./lab.sh check NN           score scenario NN and print the elapsed time
  ./lab.sh task NN            re-print the task text for scenario NN
  ./lab.sh solution NN        show the reference solution (asks first)
  ./lab.sh reset NN           undo everything scenario NN created

  ./lab.sh exam               start all scenarios, random order, one timer
  ./lab.sh exam score         score every scenario and print the total
  ./lab.sh exam reset         reset every scenario

Answers go in ./answers/NN/ (the lab's stand-in for /course/NN on the exam).
USAGE
}

run_phase() {   # run_phase NN setup|check|reset
  local nn=$1 phase=$2 d
  d="$(scenario_dir "$nn")"
  [ -x "$d/$phase.sh" ] || die "$d/$phase.sh is missing or not executable"
  "$d/$phase.sh"
}

cmd_up()   { require_tools docker kind kubectl helm jq; "$LAB_ROOT/cluster/bootstrap.sh"; }

cmd_down() {
  require_tools docker kind
  cluster_exists || { info "cluster '$KIND_CLUSTER' does not exist"; return 0; }
  info "deleting kind cluster '$KIND_CLUSTER'"
  kind delete cluster --name "$KIND_CLUSTER"
  rm -rf "$LAB_STATE"
  info "scenario state cleared. ./answers/ was left alone."
}

cmd_status() {
  if cluster_exists && kx version >/dev/null 2>&1; then
    printf '%scluster%s   %s (context %s)\n' "$C_BLD" "$C_OFF" "up" "$KCTX"
    kx get nodes --no-headers | awk '{printf "           %-22s %s\n", $1, $2}'
  else
    printf '%scluster%s   %sdown%s -- run ./lab.sh up\n' "$C_BLD" "$C_OFF" "$C_YEL" "$C_OFF"
    return 0
  fi
  printf '\n%sscenarios%s\n' "$C_BLD" "$C_OFF"
  local nn
  for nn in $(scenario_ids); do
    if [ -f "$(state_dir "$nn")/started_at" ]; then
      printf '  %-3s %-26s started, %s elapsed\n' "$nn" "$(scenario_name "$nn")" "$(timer_elapsed "$nn")"
    else
      printf '  %-3s %-26s not started\n' "$nn" "$(scenario_name "$nn")"
    fi
  done
  if [ -f "$LAB_STATE/exam/started_at" ]; then
    printf '\n%sexam%s      running, %s elapsed\n' "$C_BLD" "$C_OFF" "$(timer_elapsed exam)"
  fi
}

cmd_list() {
  printf '%s%-4s %-28s %-8s %s%s\n' "$C_BLD" "NN" "SCENARIO" "POINTS" "TOPIC" "$C_OFF"
  local nn d pts topic
  for nn in $(scenario_ids); do
    d="$(scenario_dir "$nn")"
    pts="$(scenario_points "$nn")"
    topic="$(grep -m1 '^# *topic:' "$d/check.sh" 2>/dev/null | sed 's/.*: *//')"
    printf '%-4s %-28s %-8s %s\n' "$nn" "$(scenario_name "$nn")" "${pts:-?}" "$topic"
  done
  printf '\ntotal: %s points\n' "$(for nn in $(scenario_ids); do scenario_points "$nn"; done | awk '{s+=$1} END{print s+0}')"
}

cmd_start() {
  local nn=$1
  require_cluster
  run_phase "$nn" setup
  timer_start "$nn"
  cmd_task "$nn"
  printf '%sTimer started.%s Score with: ./lab.sh check %s\n' "$C_BLD" "$C_OFF" "$nn"
}

cmd_task() {
  local nn=$1 f
  f="$(state_dir "$nn")/task.md"
  [ -f "$f" ] || die "scenario $nn has not been set up yet. Run: ./lab.sh start $nn"
  printf '\n'
  cat "$f"
  printf '\n'
}

cmd_check() {
  local nn=$1
  require_cluster
  [ -f "$(state_dir "$nn")/vars.env" ] || die "scenario $nn has not been set up. Run: ./lab.sh start $nn"
  run_phase "$nn" check
  if [ -f "$(state_dir "$nn")/started_at" ]; then
    printf '%selapsed: %s%s\n' "$C_BLD" "$(timer_elapsed "$nn")" "$C_OFF"
  fi
}

cmd_solution() {
  local nn=$1 d ans
  d="$(scenario_dir "$nn")"
  printf 'Show the reference solution for scenario %s? This spoils the task. [y/N] ' "$nn"
  read -r ans
  case "$ans" in
    y|Y|yes|YES) printf '\n'; cat "$d/solution.md"; printf '\n' ;;
    *) info "not shown" ;;
  esac
}

cmd_reset() {
  local nn=$1
  require_cluster
  run_phase "$nn" reset
  rm -rf "$(state_dir "$nn")"
  info "scenario $nn reset"
}

cmd_exam() {
  local sub=${1:-start}
  require_cluster
  case "$sub" in
    start)
      local ids order nn
      ids="$(scenario_ids)"
      # shuffle without GNU shuf
      order="$(printf '%s\n' "$ids" | awk 'BEGIN{srand()}{printf "%.8f %s\n", rand(), $0}' | sort -n | cut -d' ' -f2)"
      mkdir -p "$LAB_STATE/exam"
      printf '%s\n' "$order" > "$LAB_STATE/exam/order"
      for nn in $order; do
        info "setting up scenario $nn"
        run_phase "$nn" setup
        timer_start "$nn"
      done
      timer_start exam
      {
        printf '# CKA practice exam\n\nWork through the questions in any order.\n'
        printf 'Answers go in ./answers/NN/. Score with: ./lab.sh exam score\n\n'
        for nn in $order; do
          printf -- '\n---\n\n'
          cat "$(state_dir "$nn")/task.md"
        done
      } > "$LAB_STATE/exam/tasks.md"
      printf '\n'
      cat "$LAB_STATE/exam/tasks.md"
      printf '\n%sExam timer started (%s questions).%s\n' "$C_BLD" "$(printf '%s\n' "$order" | wc -l | tr -d ' ')" "$C_OFF"
      ;;
    score)
      local nn total max line
      LAB_SCORE_FILE="$LAB_STATE/exam/scores"; export LAB_SCORE_FILE
      : > "$LAB_SCORE_FILE"
      for nn in $(scenario_ids); do
        printf '\n%s===== scenario %s: %s =====%s\n' "$C_BLD" "$nn" "$(scenario_name "$nn")" "$C_OFF"
        run_phase "$nn" check || true
      done
      total=0; max=0
      printf '\n%s%-4s %-10s %s%s\n' "$C_BLD" "NN" "SCORE" "SCENARIO" "$C_OFF"
      while read -r line; do
        # shellcheck disable=SC2086  # the line is three plain fields
        set -- $line
        total=$(( total + $2 )); max=$(( max + $3 ))
        printf '%-4s %-10s %s\n' "$1" "$2/$3" "$(scenario_name "$1")"
      done < "$LAB_SCORE_FILE"
      printf '\n%sTOTAL: %s/%s points (%s%%)  --  elapsed %s%s\n' \
        "$C_BLD" "$total" "$max" "$(( max == 0 ? 0 : total * 100 / max ))" "$(timer_elapsed exam)" "$C_OFF"
      printf 'The real CKA pass mark is 66%%.\n'
      ;;
    reset)
      local nn
      for nn in $(scenario_ids); do
        info "resetting scenario $nn"
        # keep the state (and the backups in it) when a reset did not finish,
        # otherwise the next attempt has nothing to restore from
        if run_phase "$nn" reset; then
          rm -rf "$(state_dir "$nn")"
        else
          warn "reset of $nn reported an error -- its state was kept; run ./lab.sh reset $nn again"
        fi
      done
      rm -rf "$LAB_STATE/exam" "$LAB_STATE/bundles"
      ;;
    *) die "unknown exam subcommand '$sub' (start|score|reset)" ;;
  esac
}

need_nn() { [ $# -ge 1 ] || die "this command needs a scenario number, e.g. ./lab.sh $CMD 03"; }

CMD=${1:-help}
shift || true
case "$CMD" in
  up)       cmd_up ;;
  down)     cmd_down ;;
  status)   cmd_status ;;
  list)     cmd_list ;;
  start)    need_nn "$@"; cmd_start "$1" ;;
  task)     need_nn "$@"; cmd_task "$1" ;;
  check)    need_nn "$@"; cmd_check "$1" ;;
  solution) need_nn "$@"; cmd_solution "$1" ;;
  reset)    need_nn "$@"; cmd_reset "$1" ;;
  exam)     cmd_exam "${1:-start}" ;;
  help|-h|--help) usage ;;
  *)        usage; die "unknown command '$CMD'" ;;
esac
