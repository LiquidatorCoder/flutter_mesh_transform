// flutter_mesh_transform's shader uniform-contract checker.
//
// WHY THIS EXISTS (it is not generic harness machinery — it is this repo's one real
// silent-failure mode):
//
// `shaders/distortion.frag` declares its uniforms positionally. Flutter's
// `ui.FragmentShader` does not expose uniform *names* — only integer slots — so
// lib/flutter_mesh_transform.dart addresses them by index:
//
//     shader..setFloat(0, size.width)     // uSize.x
//           ..setFloat(1, size.height)    // uSize.y
//           ..setFloat(2, t)              // uProgress
//           ...
//           ..setImageSampler(0, image)   // uTexture
//
// The coupling between the two files is therefore by ORDER AND COUNT ONLY, enforced by
// nothing. Insert a uniform in the middle of the .frag, or add one and forget the
// matching setFloat, and:
//   - `flutter analyze` sees nothing (it is a .frag file; Dart is still well-typed),
//   - `flutter test` sees nothing (FragmentProgram.fromAsset does not load under
//     flutter_test, so the widget silently takes its no-shader path),
//   - `flutter build bundle` sees nothing (the shader still COMPILES fine — it is
//     valid GLSL, just wired to the wrong values),
//   - and at runtime the widget renders a wrong-but-plausible warp, or nothing at all,
//     because _loadShader()'s `catch (_)` swallows the failure by design.
//
// So this check is the only thing in the repo that can catch it. It is deliberately
// structural (counts and index coverage), not semantic: it proves the two files agree
// on HOW MANY float slots and samplers exist and that every slot is written, and it
// proves nothing at all about whether the right VALUE goes in the right slot. Read that
// limitation as written — do not let a passing check here be mistaken for "the warp is
// correct".
//
// FAILS CLOSED: an unreadable file, an unparseable uniform declaration, or a shader
// asset this parser does not understand is reported as a problem, never as agreement.

import { readFileSync } from "node:fs";
import { join } from "node:path";

// Float slots consumed by each GLSL uniform type Flutter's FragmentShader flattens into
// the float uniform array. Anything not listed here is deliberately unknown — see
// UNKNOWN_TYPE below.
const FLOAT_SLOTS = {
  float: 1,
  vec2: 2,
  vec3: 3,
  vec4: 4,
  mat2: 4,
  mat3: 9,
  mat4: 16,
};

const SAMPLER_TYPES = new Set(["sampler2D"]);

// `uniform <type> <name>;` — the only form this repo's shader uses. A declaration in any
// other form (arrays, layout qualifiers, multiple names per statement) is reported as
// unparseable rather than guessed at.
const UNIFORM_RE = /^\s*uniform\s+([A-Za-z_][A-Za-z0-9_]*)\s+([A-Za-z_][A-Za-z0-9_]*)\s*;/;
const UNIFORM_KEYWORD_RE = /(^|[^A-Za-z0-9_])uniform([^A-Za-z0-9_]|$)/;

const SET_FLOAT_RE = /\bsetFloat\s*\(\s*(\d+)\s*,/g;
const SET_SAMPLER_RE = /\bsetImageSampler\s*\(\s*(\d+)\s*,/g;

function stripComments(src) {
  // Block comments first, then line comments. Good enough for GLSL/Dart sources that do
  // not embed "//" inside string literals — neither of this repo's two files does.
  return src.replace(/\/\*[\s\S]*?\*\//g, " ").replace(/\/\/[^\n]*/g, "");
}

/**
 * Parse the fragment shader's uniform block.
 * -> { ok:true, floatSlots, samplers, uniforms:[{type,name,slots}] }
 *  | { ok:false, reason }
 */
export function parseShaderUniforms(src) {
  const lines = stripComments(src).split("\n");
  const uniforms = [];
  let floatSlots = 0;
  let samplers = 0;

  for (const [i, line] of lines.entries()) {
    if (!UNIFORM_KEYWORD_RE.test(line)) continue;
    const m = UNIFORM_RE.exec(line);
    if (m === null) {
      return { ok: false, reason: `line ${i + 1}: a uniform declaration this checker cannot parse (${line.trim()}). Only "uniform <type> <name>;" is supported — extend tool/harness/lib/shadercontract.mjs deliberately rather than loosening it.` };
    }
    const [, type, name] = m;
    if (SAMPLER_TYPES.has(type)) {
      samplers += 1;
      uniforms.push({ type, name, slots: 0 });
      continue;
    }
    const slots = FLOAT_SLOTS[type];
    if (slots === undefined) {
      return { ok: false, reason: `line ${i + 1}: uniform "${name}" has type "${type}", whose float-slot width this checker does not know. Add it to FLOAT_SLOTS (or SAMPLER_TYPES) in tool/harness/lib/shadercontract.mjs.` };
    }
    floatSlots += slots;
    uniforms.push({ type, name, slots });
  }

  if (uniforms.length === 0) return { ok: false, reason: "no uniform declarations found — either the shader changed shape or this checker is pointed at the wrong file" };
  return { ok: true, floatSlots, samplers, uniforms };
}

/** Every distinct index passed to setFloat(...) / setImageSampler(...) in a Dart source. */
export function parseDartSlotWrites(src) {
  const clean = stripComments(src);
  const floats = new Set();
  const samplers = new Set();
  for (const m of clean.matchAll(SET_FLOAT_RE)) floats.add(Number(m[1]));
  for (const m of clean.matchAll(SET_SAMPLER_RE)) samplers.add(Number(m[1]));
  return { floats, samplers };
}

function describeGap(written, expected, kind) {
  const missing = [];
  for (let i = 0; i < expected; i += 1) if (!written.has(i)) missing.push(i);
  const extra = [...written].filter((i) => i >= expected || i < 0).sort((a, b) => a - b);
  const parts = [];
  if (missing.length > 0) parts.push(`never written: ${kind} slot(s) ${missing.join(", ")}`);
  if (extra.length > 0) parts.push(`written but not declared: ${kind} slot(s) ${extra.join(", ")}`);
  return parts;
}

/**
 * checkShaderContract({ cwd, shaderPath, dartPath }) ->
 *   { ok:true, detail } | { ok:false, reason }
 *
 * `ok:false` means the two files disagree (or could not be read/parsed). There is no
 * third "probably fine" answer.
 */
export function checkShaderContract({ cwd, shaderPath, dartPath }) {
  let shaderSrc;
  let dartSrc;
  try {
    shaderSrc = readFileSync(join(cwd, shaderPath), "utf8");
  } catch (e) {
    return { ok: false, reason: `cannot read ${shaderPath}: ${e.message}` };
  }
  try {
    dartSrc = readFileSync(join(cwd, dartPath), "utf8");
  } catch (e) {
    return { ok: false, reason: `cannot read ${dartPath}: ${e.message}` };
  }

  const parsed = parseShaderUniforms(shaderSrc);
  if (!parsed.ok) return { ok: false, reason: `${shaderPath}: ${parsed.reason}` };

  const { floats, samplers } = parseDartSlotWrites(dartSrc);
  const problems = [
    ...describeGap(floats, parsed.floatSlots, "float"),
    ...describeGap(samplers, parsed.samplers, "sampler"),
  ];

  if (problems.length > 0) {
    const layout = parsed.uniforms.map((u) => `${u.type} ${u.name}`).join(", ");
    return {
      ok: false,
      reason:
        `${shaderPath} and ${dartPath} disagree on the uniform layout.\n` +
        `  shader declares ${parsed.floatSlots} float slot(s) and ${parsed.samplers} sampler(s): ${layout}\n` +
        `  dart writes float slot(s) [${[...floats].sort((a, b) => a - b).join(", ")}] and sampler slot(s) [${[...samplers].sort((a, b) => a - b).join(", ")}]\n` +
        problems.map((p) => `  - ${p}`).join("\n") +
        `\nUniforms are addressed by INDEX, not by name: adding, removing or reordering one in the .frag requires the matching setFloat/setImageSampler change in the Dart. Nothing else in this repo catches this.`,
    };
  }

  return { ok: true, detail: `${parsed.floatSlots} float slot(s) and ${parsed.samplers} sampler(s), all written` };
}
