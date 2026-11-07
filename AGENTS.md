# AGENTS.md

A self-contained CKA practice lab: 10 scored scenarios on a local kind
cluster, modelled on the killer.sh simulator. Bash and YAML only, no build
step, no test framework -- the cluster *is* the test fixture.

## Pointers

* Adding, editing or debugging a scenario → [docs/adding-a-scenario.md](docs/adding-a-scenario.md)
* How `lab.sh`, bundles, `vars.env` and scoring fit together, or what a
  `lib.sh` helper does → [docs/architecture.md](docs/architecture.md)
* What the lab covers and how a candidate uses it → [README.md](README.md)

## Working rules

**Verify against the live cluster.** This project's correctness lives in
cluster behaviour, not in the scripts. Before reporting that a scenario, a
check or a reset works, run it: `./lab.sh start NN`, apply the solution,
`./lab.sh check NN`, `./lab.sh reset NN`. Reading the code is how you form the
hypothesis; running it is how you know. The full loop, including the exam
paths, is in [docs/adding-a-scenario.md](docs/adding-a-scenario.md).

**Use the lab's own entry points.** `./lab.sh` for anything a command covers,
`kx` inside scripts (it pins the `kind-cka` context), `nodex` for work on a
node. A bare `kubectl` in a script will one day hit the wrong cluster.

**Keep scripts rerunnable.** Every `setup.sh`, `reset.sh` and bundle starts
with `set -euo pipefail` and must survive a second run against a cluster where
its objects already exist or have already been deleted. `shellcheck -S style
-x lab.sh cluster/*.sh bundles/*.sh scenarios/*/*.sh` exits 0 today; keep it
there, with a targeted directive where a finding is genuinely wrong.

**Target bash 3.2.** The macOS default shell. Associative arrays, `mapfile`,
`${var^^}` and `shuf` are all unavailable.

**Leave `answers/` to the candidate.** Scenarios may *provide* files there
during setup; reference solutions belong in `solution.md`.

**Ask before installing anything system-wide.** Tool checks print an install
hint and stop -- that is the intended behaviour, not a gap to fill.

## Pinned versions

Kubernetes `v1.35.8` (`kindest/node`), Calico `v3.33.0`, metrics-server
`v0.9.1`, all in `cluster/lib.sh`. The Kubernetes version tracks what the CKA
currently examines; bumping it means re-running every scenario end to end.

## Deliberately absent

`kubeadm upgrade` and `kubeadm join` cannot be practised honestly on kind, so
the lab does not simulate them. README.md explains why and gives a Multipass
recipe instead. Keep it that way: a faked upgrade teaches the wrong muscle
memory.
