#!/usr/bin/env bun
import { readFileSync } from "node:fs";
import { basename, dirname, join } from "node:path";

const data = JSON.parse(await Bun.stdin.text());

const R = "\x1b[0m";
const DIM = "\x1b[2m";
const BOLD = "\x1b[1m";
const C = (n) => `\x1b[38;5;${n}m`;

// --- Line 1: cwd | repo-emoji repo | git-branch ---

const fishPath = (p) => {
  const home = Bun.env.HOME ?? "";
  const rel = p.startsWith(home) ? "~" + p.slice(home.length) : p;
  const segs = rel.split("/");
  if (segs.length <= 1) return rel;
  return [...segs.slice(0, -1).map((s) => s[0] ?? ""), segs.at(-1)].join("/");
};

const cwd = data.workspace?.current_dir ?? Bun.env.PWD ?? "";
const { repoName, gitBranch } = (() => {
  try {
    const res = Bun.spawnSync(
      [
        "git",
        "rev-parse",
        "--path-format=absolute",
        "--git-common-dir",
        "--abbrev-ref",
        "HEAD",
      ],
      { cwd, stdout: "pipe", stderr: "ignore" },
    );
    const [commonDir = "", branch = ""] = res.stdout
      .toString()
      .trim()
      .split("\n");
    if (!commonDir) return { repoName: "", gitBranch: "" };
    return {
      repoName:
        basename(commonDir) === ".git"
          ? basename(dirname(commonDir))
          : basename(commonDir).replace(/\.git$/, ""),
      // HEAD cannot be resolved in a repo with no commits; drop the branch then.
      gitBranch: res.exitCode === 0 ? branch : "",
    };
  } catch {
    return { repoName: "", gitBranch: "" };
  }
})();

const repoEmojis = (() => {
  try {
    const path = join(import.meta.dir, "statusline.toml");
    return Bun.TOML.parse(readFileSync(path, "utf8")).repos ?? {};
  } catch {
    return {};
  }
})();
const repoEmoji = (() => {
  try {
    const res = Bun.spawnSync(["git", "remote", "get-url", "origin"], {
      cwd,
      stdout: "pipe",
      stderr: "ignore",
    });
    if (res.exitCode !== 0) return "";
    // Last two path segments of https/ssh/scp-style URLs: ".../owner/repo(.git)"
    const m = res.stdout
      .toString()
      .trim()
      .match(/[:/]([^/:]+)\/([^/]+?)(?:\.git)?\/?$/);
    if (!m) return "";
    const [, owner, repo] = m;
    return repoEmojis[`${owner}/${repo}`] ?? repoEmojis[`${owner}/*`] ?? "";
  } catch {
    return "";
  }
})();

const repoPart = repoName ? `${repoEmoji}${C(30)}${repoName}${R}` : "";
const branchPart = gitBranch ? `${C(96)}⎇ ${gitBranch}${R}` : "";
const cwdPart = `${C(188)}󰉋 ${R}${fishPath(cwd)}`;
const line1 = [repoPart, branchPart, cwdPart]
  .filter(Boolean)
  .join(` ${C(7)}|${R} `);

// --- Line 2: model + ring meters ---

const RINGS = ["○", "◔", "◑", "◕", "●"];

const gradient = (pct) => {
  if (pct < 50) {
    const r = Math.round(pct * 5.1);
    return `\x1b[38;2;${r};200;80m`;
  }
  const g = Math.max(Math.round(200 - (pct - 50) * 4), 0);
  return `\x1b[38;2;255;${g};60m`;
};

const ring = (pct) => RINGS[Math.min(Math.floor(pct / 25), 4)];

const fmt = (label, pct) => {
  const p = Math.round(pct);
  return `${DIM}${label}${R} ${gradient(pct)}${ring(pct)} ${p}%${R}`;
};

const kFmt = (n) => {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(0)}k`;
  return `${n}`;
};

const model = data.model?.display_name ?? "Claude";

const modelPart = `${C(188)}󰧑 ${R}${BOLD}${model}${R}`;
const ctxPart = (() => {
  const pct = data.context_window?.used_percentage;
  if (pct == null) return "";
  const size = data.context_window?.context_window_size;
  const usage = data.context_window?.current_usage;
  if (!usage || !size) return fmt("ctx", pct);
  const used =
    (usage.input_tokens ?? 0) +
    (usage.cache_creation_input_tokens ?? 0) +
    (usage.cache_read_input_tokens ?? 0);
  return `${DIM}ctx${R} ${gradient(pct)}${ring(pct)} ${kFmt(used)}/${kFmt(size)}${R}`;
})();

const rate = (label, pct) => (pct == null ? "" : fmt(label, pct));
const fivePart = rate("5h", data.rate_limits?.five_hour?.used_percentage);
const weekPart = rate("7d", data.rate_limits?.seven_day?.used_percentage);

const line2 = [modelPart, ctxPart, fivePart, weekPart]
  .filter(Boolean)
  .join("  ");

process.stdout.write(`${line1}\n${line2}`);
