# How the lab works

Reference for the machinery behind `lab.sh`. For *using* the lab, see
[../README.md](../README.md); for adding a scenario, see
[adding-a-scenario.md](adding-a-scenario.md).

## The one-cluster model

Everything runs against a single long-lived kind cluster named `cka`, reached
only through the `kind-cka` context. `cluster/bootstrap.sh` builds it:
3 nodes, no default CNI, Calico, metrics-server with `--kubelet-insecure-tls`,
and the jetstack Helm repo added but **not** installed (scenario 01 is the
install).

Scenarios are not isolated by cluster, they are isolated by namespace
(`cka-NN...`). Two scenarios do touch the cluster itself -- 03 rewrites the
CoreDNS ConfigMap, 10 edits the kube-apiserver static Pod manifest and adds a
ServiceCIDR. Those take a pristine backup into `.state/` *before* the first
edit and restore from it on reset.

## What a command does

`./lab.sh start NN`:

1. `run_phase NN setup` executes `scenarios/NN-*/setup.sh`.
2. That script calls `ensure_bundle <name>`, which sources `bundles/<name>.sh`
   once per cluster (marker file in `.state/bundles/`).
3. The bundle calls `gen_vars NN` for **every** scenario it serves, rolling the
   randomised names/ports/counts into `.state/NN/vars.env` -- but only if that
   file does not exist yet, so a re-run never changes a value the task text
   already quoted.
4. The bundle creates the live starting state (namespaces, workloads, provided
   files under `answers/NN/`).
5. `render_task NN` expands `{{VAR}}` placeholders in `scenarios/NN-*/task.md`
   into `.state/NN/task.md`.
6. `timer_start NN` writes `.state/NN/started_at`, then the rendered task
   prints.

`./lab.sh check NN` runs `check.sh`, which sources `lib.sh`, calls
`load_vars NN`, then one `expect` per subtask and `score_summary NN`.

`./lab.sh exam start` shuffles the scenario ids (awk + `sort -n` on a random
key -- `shuf` is not on macOS), runs every setup, starts one overall timer and
concatenates the rendered tasks into `.state/exam/tasks.md`. `exam score` sets
`LAB_SCORE_FILE`, runs every check, and prints the per-scenario table from it.

## State layout

Everything generated is under `.state/` and is disposable; deleting it loses
your backups for 03 and 10, so prefer `./lab.sh exam reset`.

```
.state/
  bundles/<name>.done     bundle ran for this cluster
  exam/started_at         overall exam timer
  exam/tasks.md           all rendered tasks, exam order
  exam/scores             NN SCORE MAX, one line per scenario
  NN/vars.env             the randomised values for this run
  NN/task.md              task.md with {{VAR}} expanded
  NN/started_at           per-scenario timer
  03/coredns-original.yaml
  10/kube-apiserver-original.yaml
```

`answers/NN/` holds your work plus any files a scenario provides. It survives
`./lab.sh down`; `reset NN` deletes it for the scenarios that own files there.

## lib.sh

`cluster/lib.sh` is sourced by every script in the project, always through the
same idiom, so a script works from any working directory:

```bash
# shellcheck source=cluster/lib.sh disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../cluster" && pwd)/lib.sh"
```

It targets **bash 3.2**, the macOS default: no associative arrays, no
`mapfile`, no `${var^^}`.

| helper | purpose |
| --- | --- |
| `kx ARGS...` | `kubectl --context kind-cka` -- the only way scripts talk to the cluster |
| `nodex NODE CMD...` | `docker exec` into a kind node (`crictl`, static Pod manifests) |
| `require_tools` / `require_cluster` | preflight; print an install hint or tell the user to run `./lab.sh up` |
| `rand_tag` / `rand_int LO HI` / `rand_pick A B C` | randomisation sources |
| `gen_vars NN <<VARS ... VARS` | write `.state/NN/vars.env` once, then source it |
| `load_vars NN` | source an existing `vars.env` |
| `render_task NN` | expand `{{VAR}}` into `.state/NN/task.md` |
| `ensure_bundle NAME` / `bundle_clear NAME` | run a bundle once per cluster / drop its marker |
| `answers_dir NN` | `answers/NN/`, created on demand |
| `ns_ensure NS` / `ns_delete NS` | create; delete and wait until it is really gone |
| `score_reset` / `expect PTS DESC REASON CMD...` / `score_summary NN` | scoring |
| `retry SECONDS CMD...` | run until it succeeds or the budget expires |
| `wait_rollout` / `wait_pod_ready` | the two common waits |
| `timer_start NN` / `timer_elapsed NN` | per-scenario and exam timers |
| `info` / `warn` / `die` | output |

### expect

```bash
expect 3 "egress to db1 on the vault port is blocked" \
        "probe reached db1:$S08_VAULT_PORT -- the policy allows too much" \
        _blocked_db1_vault
```

Points, a short description, the one-line reason printed on FAIL, then a
command. Output is suppressed; the exit code is the verdict. The reason is not
optional -- a FAIL with no explanation teaches nothing.

## Bundles

| bundle | serves | why they can share |
| --- | --- | --- |
| `apps.sh` | 01, 02, 07, 08, 09 | namespaced workloads only, no overlap between them |
| `auth.sh` | 04, 05 | RBAC objects in their own namespaces |
| `cluster.sh` | 03, 06, 10 | the three that read or change cluster-level state, plus their backups |

A bundle is sourced, not executed, so `lib.sh` is already loaded and the
variables it generates stay in scope. Bundles are idempotent on their own; the
marker only saves the wait.
