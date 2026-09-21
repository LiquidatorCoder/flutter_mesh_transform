# Plan: <task-id>

## Approach

<The shape of the change in a few sentences. What is being changed and why this way.>

## Work packages

<One per worker dispatch. Each names the files it owns; two packages must not own the
same file unless they run sequentially.>

### WP1 — <name>

- Files:
- Change:
- Verification: `tool/harness/verify <tier>`

### WP2 — <name>

- Files:
- Change:
- Verification:

## Verification plan

- Tier required by the classifier: <fast|normal|full — run `tool/harness/verify <tier>`
  and let it tell you; do not assert it>
- Review required: <none|standard|adversarial, per .claude/docs/routing.yaml>
- Anything this repo's checks CANNOT prove about this change, stated plainly:
  <e.g. "no test covers the shader path, so the warp itself was confirmed by running
  example/ by hand" — say so rather than implying the suite covered it>

## Rollback

<How to undo this if it turns out wrong.>
