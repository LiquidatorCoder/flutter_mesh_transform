# Brief: <task-id>

## Goal

<What outcome is wanted, in one or two sentences. Not how.>

## Context

<Why this is being done now. Links, prior tasks, the user request it came from.>

## Scope

In scope:
-

Out of scope:
-

## Constraints

<Anything that narrows the solution space: API compatibility, a pinned version, a
visual behaviour that must not change, a deadline.>

## Done means

<Observable conditions. What must be true for this to be finished — not "tests pass",
but what the tests would be proving.>

## Risk notes

<Which of this repo's known hazards this change touches, if any:
 - shaders/distortion.frag <-> lib/flutter_mesh_transform.dart uniform index contract
 - the silent `catch (_)` in _loadShader()
 - public constructor defaults (a visual contract with consumers)
 - the hardcoded default shaderAsset package path
 - the pub.dev release path (version/CHANGELOG/LICENSE/README)
Leave "none" if it touches none of them.>
