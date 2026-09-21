// flutter_mesh_transform's own review policy: changed files -> required independent-review mode.
//
// Repo-specific by design (the shared runtime ships no review policy — see
// ~/.claude/harness/runtime/README.md's "Left out" section).
//
// The judgement encoded here is narrow and was arrived at by reading this repo. This
// package makes no network calls, handles no credentials, persists nothing, has no
// native platform code of its own (the ios/android/macos directories belong to
// example/, which is `publish_to: none`), and has no signing configuration. None of the
// usual trust-boundary categories apply. It has exactly two ways to affect anyone
// outside this checkout:
//
//   1. being published to pub.dev and consumed as a widget API, and
//   2. the shader/Dart uniform contract, which fails silently rather than loudly
//      (lib/flutter_mesh_transform.dart's `catch (_)` renders the child undistorted),
//      and which the widget-test suite does not exercise at all.
//
// Those two are what review gates. Everything else here needs none.
//
// LOCKSTEP with `.claude/docs/routing.yaml`'s `review:` block — see the same note in
// classify.mjs.

import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { join } from "node:path";

import { matchesPattern } from "./classify.mjs";

export const REVIEW_MODES = ["none", "standard", "adversarial"];
export const MODE_RANK = { none: 0, standard: 1, adversarial: 2 };

// Files whose content defines what review means here. Hashed into a review.json's
// review_policy_fingerprint.
export const REVIEW_POLICY_FILES = ["tool/harness/lib/reviewpolicy.mjs", "tool/harness/review", ".claude/docs/routing.yaml"];

// The shader contract and the release path, and nothing else.
export const RELEASE_PATH_PATTERNS = [
  { match: "shaders/**", mode: "standard", why: "the fragment shader's uniform block is addressed by index from Dart; a reorder or an added uniform still compiles, still analyses clean, still passes the tests, and renders wrong" },
  { match: "lib/flutter_mesh_transform.dart", mode: "standard", why: "the whole public API surface — every constructor default is a visual contract with consumers — and the setFloat/setImageSampler half of that same shader contract" },
  { match: "pubspec.yaml", mode: "standard", why: "version, SDK/Flutter constraints, and the `flutter: shaders:` declaration that decides whether the shader ships at all" },
  { match: "LICENSE", mode: "standard", why: "distribution terms of a published artifact" },
];

export const DEFAULT_MODE = "none";

export function maxMode(a, b) {
  return MODE_RANK[a] >= MODE_RANK[b] ? a : b;
}

/** { mode, reasons:[{path, mode, why}] } — reasons lists only files at the max mode. */
export function requiredReviewMode(changedFiles) {
  let mode = DEFAULT_MODE;
  const hits = [];
  for (const path of changedFiles) {
    for (const rule of RELEASE_PATH_PATTERNS) {
      if (matchesPattern(path, rule.match)) {
        hits.push({ path, mode: rule.mode, why: rule.why });
        mode = maxMode(mode, rule.mode);
        break;
      }
    }
  }
  return { mode, reasons: hits.filter((h) => h.mode === mode) };
}

/** sha256 over REVIEW_POLICY_FILES' bytes. A missing file hashes as absent, not zero. */
export function reviewPolicyFingerprint({ cwd, policyFiles = REVIEW_POLICY_FILES }) {
  const h = createHash("sha256");
  const sep = Buffer.from([0]);
  for (const rel of [...policyFiles].sort()) {
    h.update(rel);
    h.update(sep);
    try {
      h.update(readFileSync(join(cwd, rel)));
    } catch {
      h.update("<absent>");
    }
    h.update(sep);
  }
  return `sha256:${h.digest("hex")}`;
}
