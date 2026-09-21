# Task lifecycle

Harness task state for this repo. One directory per task, driven entirely through
`tool/harness/task` — nothing here is hand-edited, and `state.json` is never
hand-written.

## Layout

```
.claude/tasks/
  README.md          # this file (tracked)
  _template/         # blank brief/plan skeletons (tracked)
    brief.md
    plan.md
  .active            # the active task id, if any (ignored)
  <task-id>/         # one per task (ignored)
    brief.md         # what and why — copied from _template on `task start`
    plan.md          # how — the work packages
    decisions.md     # D1, D2, ... adjudication decisions reference these by id
    state.json       # lifecycle state, written ONLY by tool/harness/task
    verify.json      # written ONLY by tool/harness/verify
    review.json      # written ONLY by tool/harness/review
    adjudication.json# written ONLY by tool/harness/review adjudicate
```

Task directories and `.active` are gitignored: they are per-checkout working state, not
repository content.

## States

`planning` → `working` → `verifying` → (`reviewing`) → `ready_to_complete` → `complete`

`awaiting_user` is available at any point for a genuine block on a human answer.

```
tool/harness/task start <task-id> [--tier fast|normal|full] [--review none|standard|adversarial]
tool/harness/task state working
tool/harness/task ready
tool/harness/task complete
tool/harness/task show [--json]
tool/harness/task list
tool/harness/task abandon
```

## Completion is gated, not asserted

`task complete` refuses unless `tool/harness/gate` allows. The gate wants a `verify.json`
that:

- actually passed,
- covers this change (its scope and workspace fingerprint still match),
- ran every required check — a check that could not run is `incomplete`, never success,
- was produced at the tier the classifier demands for the files that changed, and
- is still fresh (the verification policy has not changed under it).

Where review is required (`shaders/**`, `lib/flutter_mesh_transform.dart`,
`pubspec.yaml`, `LICENSE` — see `.claude/docs/routing.yaml`), a matching `review.json`
is needed too, and any blocker/major finding needs an `adjudication.json` entry pointing
at a real decision in `decisions.md`.

There is no `--force`. If the gate blocks, the answer is to fix the thing it names.

## What is never gated

Ordinary questions, explanations, planning, and pauses. The gate only has an opinion
when a task is active and someone tries to call it done.

## Artifacts are generated, never authored

`verify.json`, `review.json` and `adjudication.json` are written by their tools and only
by their tools. Hand-writing one — or copying one between tasks — defeats the entire
mechanism, and the fingerprints in them are specifically designed to catch it.
