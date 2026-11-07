# Adding or changing a scenario

Read [architecture.md](architecture.md) first if you have not -- this assumes
you know what a bundle and `vars.env` are.

A scenario is a directory `scenarios/NN-short-name/` with exactly five files.

| file | contract |
| --- | --- |
| `task.md` | what the candidate reads. Every randomised value appears as `{{VAR}}`. |
| `setup.sh` | sources `lib.sh`, `require_cluster`, `ensure_bundle <bundle>`, `render_task NN`. Five lines; the real work lives in the bundle. |
| `check.sh` | `# points:` and `# topic:` headers, then `load_vars`, `score_reset`, one `expect` per subtask, `score_summary`. |
| `solution.md` | the commands that score full marks, plus *why* -- name the traps the task sets. |
| `reset.sh` | removes what the scenario created, restores anything cluster-wide, `bundle_clear <bundle>`. |

## Steps

1. **Pick the bundle.** If the new scenario's objects live in their own
   namespace and it changes nothing cluster-wide, add it to an existing
   bundle. A scenario that mutates the cluster goes in `cluster.sh` and takes
   a pristine backup into `.state/NN/` before its first edit.

2. **Declare the variables** in that bundle with `gen_vars NN <<VARS ... VARS`.
   Randomise anything a repeat run could otherwise be solved from memory:
   names, replica counts, ports, label values, which node. Compute derived
   values *before* the heredoc and write both into it -- a variable computed
   outside `vars.env` is invisible to `check.sh`.

3. **Build the starting state** in the bundle, with `kx` and `ns_ensure`.
   Re-running it must be a no-op: `apply`, not `create`. Pod specs are
   immutable, so a Pod that exists in a wrong state needs deleting and
   recreating, not patching.

4. **Write `task.md`** using `{{VAR}}` for every generated value. An
   unexpanded placeholder renders as `<unset:VAR>` -- that is the symptom of a
   variable that never reached `vars.env`.

5. **Write `check.sh`.** Each `expect` asserts live behaviour: `kubectl get`
   against the running object, `auth can-i --as`, `exec` + `curl` through a
   probe Pod, `crictl` on the node. A check that only reads a YAML file in
   `answers/` passes for an answer that was never applied. Wrap anything that
   needs the cluster to converge in `retry`, but guard it so a wrong answer
   fails immediately instead of burning the whole budget:

   ```bash
   _wait_ready() { _scaled || return 1; retry 120 _ready; }
   ```

   Design each subtask so it cannot pass by accident. A check that a NodePort
   fell in a custom range passes one time in thirty on the default range --
   probe four Services instead.

6. **Write `reset.sh`.** It runs under `set -euo pipefail` against a cluster
   where the objects may already be gone, so every delete tolerates absence
   (`|| true`, or an `if` around it). Restore a cluster-wide change by
   patching the live object, never `kubectl replace` from a backup -- the
   stored `resourceVersion` is stale and the API server rejects it. End with
   `bundle_clear <bundle>` so the next `start` rebuilds.

7. **Sync the points** in three places: the `# points:` header, the sum of the
   `expect` calls, and the scenario table in `README.md`.

## Test it end to end

A scenario is not done until this loop has run against the live cluster.

```bash
./lab.sh start NN      # expect mostly FAIL, with a readable reason on each
# apply solution.md
./lab.sh check NN      # expect the full score
./lab.sh reset NN
./lab.sh start NN      # the randomised values must have changed
./lab.sh reset NN
```

Then the whole-lab paths, which exercise the interactions that a single
scenario cannot: `./lab.sh exam start` → solve → `exam score` → `exam reset`,
after which `kubectl get ns | grep cka-` is empty, `answers/` and `.state/`
are empty, and the kube-apiserver manifest is back to its original flags.

Finally:

```bash
shellcheck -S style -x lab.sh cluster/*.sh bundles/*.sh scenarios/*/*.sh
```

## Traps worth knowing

These each cost a debugging round during the original build.

* `busybox:1.28` has no `sleep infinity`. Use
  `["sh","-c","while true; do sleep 3600; done"]`.
* Deleting a namespace without waiting races the next setup into a terminating
  namespace. `ns_delete` waits; use it.
* A `ServiceCIDR` finalizer blocks on allocated IPs -- delete the namespace
  using the range first, then the ServiceCIDR.
* `kubectl top` is unavailable for a minute after the API server restarts, so
  a metrics check in one scenario can fail because of another. Those checks
  retry.
* `shuf` is not on macOS, and `lib.sh` targets bash 3.2: no associative
  arrays, no `mapfile`.
