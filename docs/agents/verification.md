# Verification — flutter_mesh_transform

What `tool/harness/verify` actually runs in this repo, what each tier proves, and —
just as important — what none of it proves.

Everything here was established by running the commands against this repo during the
harness bootstrap, not assumed from what a Flutter package usually has.

## Usage

```
tool/harness/verify <fast|normal|full> [--base <ref>] [--files a b ...]
                                       [--json-out <path>] [--quiet]
```

Exit `0` only when `result == "passed"`. Exit `1` for `failed` or `incomplete`, `2` for
a usage/runtime error.

The artifact it writes (`--json-out`) carries `result`,
`completion_tier_satisfied`, `unsatisfied_required`, `required_tier`, the workspace and
policy fingerprints, the verification scope, and a per-check record. `tool/harness/gate`
reads it; nothing else should write it.

## The rule that matters

A check is reported `passed` **only if its command actually ran and actually exited
zero**. A check that could not run — tool missing, spawn failure, timeout — is `skipped`
and is listed in `unsatisfied_required`, which makes the whole run `incomplete`. There is
no code path from "could not check" to "passed", and none may be added.

## Tiers

| Tier | Checks | Roughly |
|---|---|---|
| `fast` | format, analyze, shader_contract | seconds |
| `normal` | + test, shader_compile | + the widget suite and a real shader compile |
| `full` | + publish_dry_run | + the pub.dev release gate |

Which tier a change *requires* is decided by `tool/harness/lib/classify.mjs`, not by
whoever runs the command. `verify` reports the classifier's answer in `required_tier`,
and the gate refuses a completion verified below it.

## The checks

### `format` — `dart format --output=none --set-exit-if-changed .`

**This currently FAILS on the repo's pre-existing code.** All three Dart files
(`lib/flutter_mesh_transform.dart`, `test/mesh_transform_test.dart`,
`example/lib/main.dart`) are unformatted as committed. That is a recorded baseline
failure, not something the harness introduced and not something it silently fixed. Until
someone runs `dart format .` deliberately, every tier reports `failed` on this check.

### `analyze` — `flutter analyze`

Passes cleanly today. It covers `lib/`, `test/` **and** `example/`: this was confirmed by
planting a type error in `example/lib` and watching the root analyze run report it. A
separate example-scoped analyze check would be redundant, so this repo deliberately does
not have one.

### `shader_contract` — in-process, `tool/harness/lib/shadercontract.mjs`

The repo-specific one, and the reason it exists:

`shaders/distortion.frag` declares its uniforms positionally, and Flutter's
`ui.FragmentShader` exposes no uniform *names* — only integer slots. So
`lib/flutter_mesh_transform.dart` writes them by index (`setFloat(0..5)`,
`setImageSampler(0)`). The two files are coupled by **order and count only**, enforced by
nothing in the toolchain:

- `flutter analyze` sees nothing — it is a `.frag` file, and the Dart is still well-typed.
- `flutter test` sees nothing — `FragmentProgram.fromAsset` does not load under
  `flutter_test`, so every test runs the widget's no-shader fallback.
- `flutter build bundle` sees nothing — a reordered uniform block is still *valid GLSL*.
- At runtime nothing is raised: `_loadShader()` swallows failures in `catch (_)` and
  renders the child undistorted, by design.

So this check is the only thing in the repo that can catch it. It compares the shader's
declared float-slot width (`float`=1, `vec2`=2, … `mat4`=16) and sampler count against
the indices the Dart actually writes, and fails if any declared slot is unwritten or any
written slot is undeclared.

It proves **counts and coverage only**. It does *not* prove that the right value reaches
the right slot — swapping `xSpread` and `yFalloff` between two `setFloat` calls passes
this check and renders wrong. Do not read a green `shader_contract` as "the warp is
correct".

It fails closed: an unreadable file, an unparseable uniform declaration, or a GLSL type
whose width it does not know is reported as a problem, never as agreement.

### `test` — `flutter test`

**Real, and honestly small.** One file, `test/mesh_transform_test.dart`, two widget
tests: that `MeshTransform` renders its child, and that toggling `active` does not throw.
Both currently pass.

What they do **not** cover: the shader path (never loaded under `flutter_test`), the
spring simulation, `maxBlur`, `padding`, and every other constructor tunable. This repo
has a test suite; it does not have test coverage of its actual effect. A green `test` here
is a much weaker statement than a green `test` in a repo with real coverage, and any
change to the warp itself needs to be confirmed by running `example/` by hand and saying
so in the task's plan.

There are also `RunnerTests.swift` files under `example/ios/` and `example/macos/`; both
are untouched `flutter create` boilerplate, wired into no verifier tier, and prove
nothing.

### `shader_compile` — `flutter build bundle`, run in `example/`

The only command in this repo that runs `distortion.frag` through the shader compiler.
Confirmed during bootstrap: appending invalid GLSL to the `.frag` made this exit `1`
while `analyze` and `test` stayed green. Takes a few seconds once dependencies are
resolved.

It writes into `example/build/`, which is shared — hence the `example-build` lock
resource in `.claude/docs/routing.yaml`.

### `publish_dry_run` — `flutter pub publish --dry-run`

The pub.dev release gate. Passes today with 0 warnings.

## A property worth knowing: verifying dirties the tree

`pubspec.lock` and `example/pubspec.lock` are both **tracked**, and every Flutter command
above implicitly runs `pub get`, which rewrites them whenever a transitive dependency has
a newer allowed version. Running the verifier therefore modifies tracked files by itself.

Both lockfiles are excluded from workspace fingerprints for exactly this reason —
otherwise every `verify.json` would go stale the moment it was produced. This is *not* a
licence to ignore a deliberate dependency bump: `pubspec.yaml` is a full-tier path and is
fingerprinted normally.

## Independent review

Optional here, and required only on the shader-contract and release paths (`shaders/**`,
`lib/flutter_mesh_transform.dart`, `pubspec.yaml`, `LICENSE`) — see `review:` in
`.claude/docs/routing.yaml`. Independent review is performed by the reviewer configured in the active global harness policy
(`~/.claude/harness/current/policies/global.md`); this repo only sets risk floors.

`tool/harness/review run` never writes a passing review it did not obtain: if the reviewer
is unavailable or fails mid-run, it writes an
`incomplete` review.json carrying the reason, which blocks completion.

## What the harness will not do

It will not fix the formatting failure for you, reformat files as a side effect, or lower
a tier to get to green. Baseline failures stay visible until someone decides to address
them.
