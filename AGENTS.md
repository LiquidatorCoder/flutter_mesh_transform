# AGENTS.md — flutter_mesh_transform

Rules for agents working in this repository. Everything here was established by reading
and running this repo, not inherited from another project. Where a convention does not
exist yet, this file says so rather than inventing one.

## What this repo is

`flutter_mesh_transform` — a Flutter package published to pub.dev (version `0.1.1`,
`homepage`/`repository`: `github.com/LiquidatorCoder/flutter_mesh_transform`).

It provides **one widget**: `MeshTransform`, which warps any child with a mesh
distortion driven by a `SpringSimulation` and rendered by a GLSL fragment shader.

```
lib/flutter_mesh_transform.dart   the ENTIRE public API — one file, ~160 lines
shaders/distortion.frag           the fragment shader; the effect itself
test/mesh_transform_test.dart     the whole test suite — one file, two widget tests
example/                          demo app with sliders (publish_to: none)
demo/*.gif                        README media, linked by absolute GitHub raw URL
analysis_options.yaml             flutter_lints ^6.0.0, no custom rules
```

There is no `lib/src/`, no export barrel separate from the implementation, and no
architectural layering — the package is small enough not to have grown one. **Do not
invent a layer structure**; if the package grows to need one, that is a deliberate
decision to make with the user, not a convention to assume.

### Toolchain

| | |
|---|---|
| Dart SDK | `^3.11.1` (pubspec `environment:`) — local Dart 3.12.2 |
| Flutter | `>=3.24.0` — local Flutter 3.44.3 stable |
| Lints | `flutter_lints ^6.0.0` |
| Deps | `flutter_shaders ^0.1.3` (only non-SDK dependency) |

### What this repo does NOT have

Recorded so nobody wires work to something that does not exist:

- **No CI** — there is no `.github/`, no workflow files, nothing running on push.
- **No Makefile and no script runner.** Every command below is invoked directly.
- **No code generation** — no `build_runner`, no generated files, no codegen step.
- **No native code of its own.** The `ios/`, `android/` and `macos/` directories belong
  to `example/`. `example/ios/RunnerTests/RunnerTests.swift` and its macOS twin are
  untouched `flutter create` boilerplate and are wired into nothing.
- **No network, credential, persistence or signing surface.** This package reads no
  files, opens no sockets and stores nothing.

## Commands

These are the repo's real commands — there is no script indirection to hide behind.

```bash
dart format --output=none --set-exit-if-changed .   # format check
flutter analyze                                      # covers lib/, test/ AND example/
flutter test                                         # the two widget tests
cd example && flutter build bundle                   # the ONLY shader compile
flutter pub publish --dry-run                        # release gate
```

Prefer running them through the verifier, which records what it did:

```bash
tool/harness/verify fast     # format, analyze, shader_contract
tool/harness/verify normal   # + test, shader_compile
tool/harness/verify full     # + publish_dry_run
```

See `docs/agents/verification.md` for what each tier proves and what it does not.

## The hazard that defines work in this repo

`shaders/distortion.frag` declares uniforms **positionally**. Flutter's
`ui.FragmentShader` exposes no uniform names — only integer slots — so
`lib/flutter_mesh_transform.dart` writes them by index:

```dart
shader..setFloat(0, size.width)    // uSize.x
      ..setFloat(1, size.height)   // uSize.y
      ..setFloat(2, t)             // uProgress
      ..setFloat(3, widget.xSpread)
      ..setFloat(4, widget.yFalloff)
      ..setFloat(5, widget.yTravel)
      ..setImageSampler(0, image); // uTexture
```

The two files are coupled by **order and count only**. Add, remove, reorder or widen a
uniform on one side without the other and:

- `flutter analyze` stays green (it is a `.frag`; the Dart is still well-typed),
- `flutter test` stays green (`FragmentProgram.fromAsset` does not load under
  `flutter_test` — every test runs the no-shader fallback),
- `flutter build bundle` stays green (a reordered uniform block is still valid GLSL),
- and at runtime **nothing is raised**: `_loadShader()` swallows every failure in
  `catch (_)` and renders the child undistorted, by design.

So the failure mode here is *silent wrong rendering*, not a crash or a red test.

`tool/harness/verify` runs a `shader_contract` check
(`tool/harness/lib/shadercontract.mjs`) that catches count/coverage mismatches. It does
**not** catch a swapped value — `setFloat(3, yFalloff); setFloat(4, xSpread)` passes it
and renders wrong.

**Therefore: any change to the shader or to the uniform-writing code must be confirmed
by actually running `example/` and looking at it.** Say so in the task's plan. Do not
report a shader change as verified on the strength of a green suite.

## Other things to know before changing code

- **Every constructor default is a public visual contract.** `xSpread: 2.1`,
  `yFalloff: 3.0`, `yTravel: 1.1`, `response: 0.85`, `dampingRatio: 0.75`,
  `maxBlur: 20.0`, `padding: EdgeInsets.symmetric(vertical: 40, horizontal: 24)` — each
  one changes how the effect looks for every existing consumer who did not override it.
  Changing one is a breaking visual change even though it compiles.
- **The default `shaderAsset` hardcodes the package name**:
  `'packages/flutter_mesh_transform/shaders/distortion.frag'`. Renaming the package in
  `pubspec.yaml` without updating that string breaks every consumer at runtime — and the
  `catch (_)` means they get a silently missing effect, not an error.
- **`pubspec.yaml`'s `flutter: shaders:` block is what bundles the shader at all.**
  Removing or mistyping it ships a package whose effect silently never appears.
- **`_programCache` is a `static` map keyed by asset path**, shared across every
  `MeshTransform` instance in the host app. Anything added to it lives for the process
  lifetime.
- **Both `pubspec.lock` files are tracked**, and every Flutter command runs an implicit
  `pub get` that rewrites them whenever re-resolution picks up a newer allowed version.
  This was observed during the harness bootstrap (`meta` and `test_api` bumped on a bare
  `flutter analyze`), so the verifier can dirty the tree by itself — not on every run,
  but without warning. Do not commit those churn-only lockfile changes unless a
  dependency bump is the point of the task.
- **`README.md` is part of the release artifact.** Version `0.1.1` was published for no
  reason other than fixing demo-GIF URLs so they render on pub.dev — the GIFs are linked
  as absolute `raw.githubusercontent.com` URLs precisely because relative paths do not
  render there. Keep them absolute.

## Baseline state (as of the harness bootstrap)

- `dart format --set-exit-if-changed .` **FAILS** on all three pre-existing Dart files.
  This is a recorded baseline failure. The harness did not introduce it and deliberately
  did not fix it — reformatting is a deliberate change someone should make on purpose,
  not a side effect of installing tooling.
- `flutter analyze` passes. `flutter test` passes (2 tests). `flutter build bundle` in
  `example/` passes. `flutter pub publish --dry-run` passes with 0 warnings.

## Working rules

- **Verification is a script, not a judgement.** `tool/harness/verify` decides
  pass/fail. A required check that could not run is `incomplete`, never success.
- **Done is gated.** Drive task state with `tool/harness/task`; `task ready` then
  `task complete`. Completion needs a `verify.json` that passed, covers the change, ran
  every required check, and is still fresh. There is no `--force`.
- **Never hand-write `verify.json`, `review.json` or `adjudication.json`.** They are
  written by their tools and only by their tools.
- **Do not fix unrelated baseline failures as a side effect** of another task. Raise
  them; let the user decide.
- **Do not commit, push, tag or publish unless asked.** `flutter pub publish` (for real,
  without `--dry-run`) is never an agent's call to make.

## Where things are

| | |
|---|---|
| Verification tiers & policy | `.claude/docs/routing.yaml`, `docs/agents/verification.md` |
| Classifier (path → tier) | `tool/harness/lib/classify.mjs` |
| Review policy (path → mode) | `tool/harness/lib/reviewpolicy.mjs` |
| Shader contract checker | `tool/harness/lib/shadercontract.mjs` |
| Task lifecycle | `.claude/tasks/README.md` |
| Installed harness version | `.claude/harness-version` |
