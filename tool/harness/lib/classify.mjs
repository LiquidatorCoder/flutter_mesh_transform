// flutter_mesh_transform's own file classifier: changed files -> required verification tier.
//
// Repo-specific by design. The shared harness runtime (~/.claude/harness/runtime/lib)
// deliberately ships no classifier, because "what does this change risk" is a question
// only a specific repo can answer. This one answers it for a single-widget Flutter
// package published to pub.dev whose visible behaviour comes from a GLSL fragment
// shader that nothing in the test suite exercises.
//
// The judgement below comes from reading this repo, not from importing another's
// categories. Two facts drive almost all of it:
//
//   1. `shaders/distortion.frag` and `lib/flutter_mesh_transform.dart` form an
//      index-coupled pair (see lib/shadercontract.mjs). Either side alone is a full-tier
//      change.
//   2. `_loadShader()` swallows every failure in a `catch (_)` and renders the child
//      undistorted. A broken shader is therefore INVISIBLE at runtime — no crash, no
//      log, just a missing effect. Nothing degrades quietly here except silently.
//
// LOCKSTEP: `.claude/docs/routing.yaml` is the human-readable statement of this same
// policy, and `RULES` below is its executable form. Node has no built-in YAML parser and
// this repo has no YAML dependency (it is a Dart package), so the policy is not parsed
// from the YAML at runtime. Change both files together. Both are listed in POLICY_FILES,
// so editing either one changes the verification policy fingerprint and invalidates
// every existing verify.json — which is what makes drift loud instead of silent.

export const TIERS = ["fast", "normal", "full"];
export const TIER_RANK = { fast: 0, normal: 1, full: 2 };

// Files whose content defines what verification means here. Hashed into every
// verify.json's verification_policy_fingerprint.
export const POLICY_FILES = [
  "tool/harness/verify",
  "tool/harness/lib/classify.mjs",
  "tool/harness/lib/reviewpolicy.mjs",
  "tool/harness/lib/shadercontract.mjs",
  ".claude/docs/routing.yaml",
  "analysis_options.yaml",
];

// Never part of a workspace fingerprint.
//
// `pubspec.lock` and `example/pubspec.lock` are the unusual entries, and they are here
// for a measured reason: BOTH ARE TRACKED IN GIT, and every Flutter command the verifier
// runs (`flutter analyze`, `flutter test`, `flutter build bundle`, `flutter pub publish
// --dry-run`) implicitly runs `pub get` and rewrites them whenever a transitive
// dependency has a newer allowed version. Verifying therefore dirties the tree by
// itself. Fingerprinting those two files would mean every verify.json went stale the
// instant it was produced. Excluding them is not a licence to ignore a deliberate
// dependency bump — pubspec.yaml is a full-tier path and is fingerprinted normally.
export const FINGERPRINT_EXCLUDE_PREFIXES = [
  ".claude/tasks/",
  ".claude/worktrees/",
  ".dart_tool/",
  "build/",
  "example/.dart_tool/",
  "example/build/",
  "coverage/",
  "pubspec.lock",
  "example/pubspec.lock",
];

// Shared resources a worker may serialize on.
//   dependency-resolution — `flutter pub get`, which rewrites both tracked lockfiles.
//   repo-format           — `dart format .`, which rewrites files across the tree.
//   example-build         — `flutter build bundle` in example/, the ONLY check that
//                           compiles the shader; two concurrent runs share example/build/.
//   release               — `flutter pub publish`.
// There is no `codegen` resource: this repo has no build_runner and no generated files.
// There is no device/simulator pool: nothing here runs on a device.
export const LOCK_RESOURCES = ["dependency-resolution", "repo-format", "example-build", "release"];

// First match wins, in order. Mirrors routing.yaml's `classification:` block.
export const RULES = [
  { match: "shaders/**", tier: "full", why: "the fragment shader IS the product; its uniforms are index-coupled to lib/flutter_mesh_transform.dart, it is compiled only by a real bundle build, and a load failure is swallowed by _loadShader()'s catch — so a break here is silent at every other layer" },
  { match: "lib/flutter_mesh_transform.dart", tier: "full", why: "the entire public API in one file: every constructor default is a visual contract with consumers, it holds the setFloat/setImageSampler side of the shader uniform contract, and its default shaderAsset hardcodes the literal package name 'flutter_mesh_transform'" },
  { match: "pubspec.yaml", tier: "full", why: "the published version, the SDK/Flutter constraints, and the `flutter: shaders:` declaration without which the shader is not bundled at all — and the package name that the default shaderAsset path hardcodes" },
  { match: "CHANGELOG.md", tier: "full", why: "part of the pub.dev release artifact, changed together with the version" },
  { match: "LICENSE", tier: "full", why: "distribution terms of the published archive; pub validates its presence" },
  { match: "lib/**", tier: "normal", why: "package implementation consumed by real apps (today lib/ holds only the single public file above; this is the floor for anything added beside it)" },
  { match: "test/**", tier: "normal", why: "a change to a test changes what passing means — the suite must actually run" },
  { match: "analysis_options.yaml", tier: "normal", why: "the flutter_lints rule set; a change here re-scopes every analyze run in the repo, example/ included" },
  { match: "README.md", tier: "normal", why: "shipped in the pub.dev archive and rendered on the package page; 0.1.1 was released for nothing but broken demo-GIF URLs in it" },
  { match: "tool/harness/**", tier: "normal", why: "verifier, gate and shader-contract logic" },
  { match: ".claude/docs/routing.yaml", tier: "normal", why: "verification policy" },
  { match: "AGENTS.md", tier: "normal", why: "the rules agents work from" },
  { match: "example/**", tier: "fast", why: "the demo app (publish_to: none); not depended on by lib/, and already covered by the root `flutter analyze`, which analyses example/ too" },
  { match: "demo/**", tier: "fast", why: "README media, referenced by absolute GitHub raw URL rather than by a path pub validates" },
  { match: "docs/**", tier: "fast", why: "agent-facing documentation; not shipped in the archive" },
  { match: ".claude/tasks/**", tier: "fast", why: "task bookkeeping" },
  { match: "*", tier: "fast", why: "default floor — nothing here is verification-exempt" },
];

const DOUBLESTAR = "__HARNESS_DOUBLESTAR__";

/**
 * Minimal glob matcher for the forms RULES actually uses: an exact path, a `dir/**`
 * prefix, a single `*` segment wildcard, and the bare `*` catch-all. Deliberately not a
 * general glob implementation — a rule form not listed above is a policy authoring
 * mistake, and a silently-mismatching clever matcher would be worse than an obvious one.
 */
export function matchesPattern(path, pattern) {
  if (pattern === "*") return true;
  if (!pattern.includes("*")) return path === pattern;
  if (pattern.endsWith("/**")) {
    const prefix = pattern.slice(0, -2); // keep the trailing slash
    return path.startsWith(prefix);
  }
  const escaped = pattern.replace(/[.+^${}()|[\]\\]/g, "\\$&");
  const body = escaped.split("**").join(DOUBLESTAR).split("*").join("[^/]*").split(DOUBLESTAR).join(".*");
  return new RegExp(`^${body}$`).test(path);
}

/** The tier one path demands, plus the rule that decided it. */
export function classifyFile(path) {
  for (const rule of RULES) {
    if (matchesPattern(path, rule.match)) return { tier: rule.tier, rule: rule.match, why: rule.why };
  }
  // Unreachable while the `*` catch-all is present. Fail closed rather than return
  // undefined if someone ever removes it.
  return { tier: "full", rule: "(no rule matched)", why: "fail closed: no classification rule matched" };
}

/**
 * The highest tier any changed file demands. An EMPTY change set returns "fast" — the
 * floor, not "full": a verify run with nothing changed has nothing to escalate for.
 * Returns { requiredTier, reasons: [{path, tier, rule, why}] } with reasons listing only
 * the files that drove the maximum.
 */
export function classifyChanges(changedFiles) {
  let requiredTier = "fast";
  const all = [];
  for (const path of changedFiles) {
    const c = classifyFile(path);
    all.push({ path, ...c });
    if (TIER_RANK[c.tier] > TIER_RANK[requiredTier]) requiredTier = c.tier;
  }
  return { requiredTier, reasons: all.filter((r) => r.tier === requiredTier) };
}
