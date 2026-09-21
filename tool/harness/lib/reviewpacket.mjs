// Builds the text packet handed to the independent reviewer, and the two fingerprints
// the completion gate compares it against.
//
// Repo-local on purpose: the shared runtime deliberately does not ship a packet builder
// (see ~/.claude/harness/runtime/README.md's "Left out"). This one knows two things
// about flutter_mesh_transform that a generic builder could not: that the .frag source
// must be included in full alongside the diff (a reviewer cannot judge an index-coupled
// uniform change from a diff hunk alone), and that this repo has no generated files.
//
// Determinism is the whole contract here: `buildPacket` must produce byte-identical
// output for an unchanged workspace, or every review goes stale on the next gate check.
// Nothing time-, path-, or environment-dependent may enter the packet text.

import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { join } from "node:path";

// Dart codegen output. This repo has no build_runner and no generated files today, so
// this matches nothing right now — it is here so that adding codegen later does not
// silently start feeding machine-written files to a reviewer.
const GENERATED_RE = /\.(g|freezed|config|gr|mocks)\.dart$/;

const MAX_DIFF_BYTES = 400 * 1024;

// The shader is short (tens of lines) and is the one file whose full text a reviewer
// genuinely needs in order to check an index-coupled uniform change.
const SHADER_PATH = "shaders/distortion.frag";
const MAX_SHADER_BYTES = 32 * 1024;

export function sha256Hex(s) {
  return createHash("sha256").update(s).digest("hex");
}

export function fingerprintOf(text) {
  return `sha256:${sha256Hex(text)}`;
}

function readOr(path, fallback) {
  try {
    return readFileSync(path, "utf8");
  } catch {
    return fallback;
  }
}

/**
 * The brief/plan content the review was produced against. Kept separate from the packet
 * fingerprint so the gate can tell "the code changed" from "the task's own definition of
 * done changed" — both invalidate a review, for different reasons.
 */
export function reviewInputContentFingerprint({ cwd, taskId }) {
  const dir = join(cwd, ".claude", "tasks", taskId);
  const brief = readOr(join(dir, "brief.md"), "<absent>");
  const plan = readOr(join(dir, "plan.md"), "<absent>");
  return fingerprintOf(`v1\nbrief\n${brief}\nplan\n${plan}\n`);
}

/**
 * The reviewer's input. Returns the packet text; `fingerprintOf(text)` is what lands in
 * review.json's `review_input_fingerprint`.
 */
export function buildPacket({ cwd, taskId, base, changedEntries, mode, tier }) {
  const dir = join(cwd, ".claude", "tasks", taskId);
  const reviewable = changedEntries.filter((e) => !GENERATED_RE.test(e.path));
  const excluded = changedEntries.filter((e) => GENERATED_RE.test(e.path));

  let diff = "";
  try {
    diff = execFileSync("git", ["diff", "-M", base, "--", ...reviewable.map((e) => e.path)], {
      cwd,
      encoding: "utf8",
      maxBuffer: 64 * 1024 * 1024,
      stdio: ["ignore", "pipe", "pipe"],
    });
  } catch (e) {
    diff = `<diff unavailable: ${String(e.message ?? e).split("\n")[0]}>`;
  }
  if (diff.length > MAX_DIFF_BYTES) {
    diff = `${diff.slice(0, MAX_DIFF_BYTES)}\n...[diff truncated at ${MAX_DIFF_BYTES} bytes]`;
  }

  const lines = [
    "# Independent review packet — flutter_mesh_transform",
    "",
    "flutter_mesh_transform is a published Flutter package (pub.dev): one widget,",
    "MeshTransform, that warps any child via a GLSL fragment shader driven by a spring",
    "simulation. The whole public API is the single file lib/flutter_mesh_transform.dart.",
    "",
    "Review the diff below for correctness and for anything that would break a downstream",
    "consumer. The specific hazard in this repo, which nothing in its toolchain catches:",
    "",
    "  * shaders/distortion.frag's uniforms are addressed BY INDEX from Dart",
    "    (setFloat(0..n), setImageSampler(0)). Adding, removing, reordering or widening a",
    "    uniform without the matching Dart change still compiles, still analyses clean and",
    "    still passes the widget tests — and renders wrong.",
    "  * _loadShader() swallows every failure in `catch (_)` and renders the child",
    "    undistorted, so a broken shader produces no crash and no log.",
    "  * flutter_test never loads the shader, so no existing test covers any of the above.",
    "",
    "Also check: changed constructor defaults (each is a visual contract with consumers),",
    "the hardcoded default shaderAsset path 'packages/flutter_mesh_transform/shaders/",
    "distortion.frag' against pubspec.yaml's package name, the `flutter: shaders:`",
    "declaration, and version/CHANGELOG consistency. The `example/` app is a demo, not a",
    "product.",
    "",
    `task_id: ${taskId}`,
    `mode: ${mode}`,
    `tier: ${tier}`,
    `base: ${base}`,
    "",
    "## Brief",
    "",
    readOr(join(dir, "brief.md"), "<no brief.md>").trimEnd(),
    "",
    "## Plan",
    "",
    readOr(join(dir, "plan.md"), "<no plan.md>").trimEnd(),
    "",
    "## Changed files",
    "",
    ...reviewable.map((e) => `- ${e.status} ${e.path}${e.oldPath ? ` (from ${e.oldPath})` : ""}`),
  ];
  if (excluded.length > 0) {
    lines.push("", "## Excluded (generated)", "", ...excluded.map((e) => `- ${e.path}`));
  }

  // Full shader source, always — a uniform block cannot be judged from a diff hunk.
  const shaderSrc = readOr(join(cwd, SHADER_PATH), "<absent>");
  lines.push(
    "",
    `## Current ${SHADER_PATH} (full source, for the uniform contract)`,
    "",
    "```glsl",
    (shaderSrc.length > MAX_SHADER_BYTES ? `${shaderSrc.slice(0, MAX_SHADER_BYTES)}\n...[truncated]` : shaderSrc).trimEnd(),
    "```",
  );

  lines.push("", "## Diff", "", "```diff", diff.trimEnd(), "```", "");
  return lines.join("\n");
}
