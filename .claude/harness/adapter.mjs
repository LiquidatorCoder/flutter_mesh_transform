// flutter_mesh_transform's v2 adapter.
//
// Everything about this repo's verification is declarative config (see
// .claude/harness/config.json's risk.rules / review.rules / verification.checks) EXCEPT
// the shader/Dart uniform-index contract, which requires actually parsing two files —
// see ./adapter/shadercontract.mjs, moved verbatim from v1's
// tool/harness/lib/shadercontract.mjs (nothing in its logic changed; only its
// invocation site did — v1's tool/harness/verify called it in-process from its own
// CHECKS table, this adapter calls it the same way from buildVerificationPlan).
//
// That one check has no `cmd` (it is in-process, like v1's), so it cannot be expressed
// via config.verification.checks/tiers alone. This file therefore builds the plan
// itself: the ordinary cmd-based checks come straight from config (same shape as the
// core's own config-driven default, adapterapi.mjs's defaultBuildVerificationPlan — an
// adapter may not import core internals, so the small amount of that logic this repo
// needs is reproduced here rather than imported), and shader_contract is spliced in by
// hand at the same position v1's TIER_CHECKS always put it: right after `analyze`, in
// every tier that runs it (which, per config.json, is every tier).
import { existsSync, readdirSync, statSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { join } from "node:path";

import { checkShaderContract } from "./adapter/shadercontract.mjs";

export const adapterApi = 1;

const SHADER_PATH = "shaders/distortion.frag";
const PUBLIC_API_PATH = "lib/flutter_mesh_transform.dart";

function toolOnPath(bin) {
  return spawnSync("/bin/sh", ["-c", `command -v "$0" >/dev/null 2>&1`, bin]).status === 0;
}

function hasFileMatching(root, rel, re) {
  const stack = [join(root, rel)];
  while (stack.length) {
    const dir = stack.pop();
    let entries;
    try {
      entries = readdirSync(dir);
    } catch {
      continue;
    }
    for (const name of entries) {
      const abs = join(dir, name);
      let st;
      try {
        st = statSync(abs);
      } catch {
        continue;
      }
      if (st.isDirectory()) {
        if (name !== "node_modules" && !name.startsWith(".")) stack.push(abs);
      } else if (re.test(name)) {
        return true;
      }
    }
  }
  return false;
}

/** Same shape as the core's config-driven default. Builds only the `cmd`-based checks
 * named in config.verification.tiers[ctx.tier]; shader_contract is added separately
 * because it has no `cmd`. */
function cmdChecks(ctx, names) {
  const v = ctx.config.verification ?? {};
  return names.map((name) => {
    const c = v.checks?.[name];
    if (!c) throw new Error(`config.verification names unknown check "${name}"`);
    const [bin, ...args] = c.cmd;
    return {
      name,
      description: c.description ?? c.cmd.join(" "),
      required: c.required !== false,
      cmd: [bin, args],
      subdir: c.subdir,
      env: c.env,
      timeoutMs: c.timeout_ms,
      available: (actx) => {
        for (const tool of [].concat(c.requires_tool ?? bin)) {
          if (!toolOnPath(tool)) return `the \`${tool}\` CLI is not on PATH`;
        }
        for (const f of [].concat(c.requires_file ?? [])) {
          if (!existsSync(join(actx.root, f))) return `${f} is absent`;
        }
        if (c.requires_test_glob && !hasFileMatching(actx.root, c.requires_test_glob.dir ?? ".", new RegExp(c.requires_test_glob.pattern))) {
          return `no test files matching ${c.requires_test_glob.pattern} under ${c.requires_test_glob.dir ?? "."}`;
        }
        return null;
      },
    };
  });
}

const shaderContractCheck = {
  name: "shader_contract",
  description: `uniform index contract: ${SHADER_PATH} <-> ${PUBLIC_API_PATH}`,
  required: true,
  available: (actx) => {
    if (!existsSync(join(actx.root, SHADER_PATH))) return `${SHADER_PATH} is absent`;
    if (!existsSync(join(actx.root, PUBLIC_API_PATH))) return `${PUBLIC_API_PATH} is absent`;
    return null;
  },
  run: async (actx) => {
    const r = checkShaderContract({ cwd: actx.root, shaderPath: SHADER_PATH, dartPath: PUBLIC_API_PATH });
    return { status: r.ok ? "passed" : "failed", exit_code: r.ok ? 0 : 1, detail: r.ok ? r.detail : r.reason };
  },
};

export function buildVerificationPlan(ctx) {
  const names = ctx.config.verification?.tiers?.[ctx.tier] ?? [];
  const plan = cmdChecks(ctx, names);
  // v1's TIER_CHECKS always placed shader_contract third: right after format, analyze.
  const analyzeIdx = plan.findIndex((c) => c.name === "analyze");
  const at = analyzeIdx === -1 ? plan.length : analyzeIdx + 1;
  plan.splice(at, 0, shaderContractCheck);
  return plan;
}
