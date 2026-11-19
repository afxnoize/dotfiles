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
// Resolve the main repository name, not the linked worktree directory name.
const repoName = (() => {
  try {
    const res = Bun.spawnSync(
      ["git", "rev-parse", "--path-format=absolute", "--git-common-dir"],
      { cwd, stdout: "pipe", stderr: "ignore" },
    );
    if (res.exitCode !== 0) return "";
    const commonDir = res.stdout.toString().trim();
    return basename(commonDir) === ".git"
      ? basename(dirname(commonDir))
      : basename(commonDir).replace(/\.git$/, "");
  } catch {
    return "";
  }
})();
const gitBranch = (() => {
  try {
    const res = Bun.spawnSync(["git", "rev-parse", "--abbrev-ref", "HEAD"], {
      cwd,
      stdout: "pipe",
      stderr: "ignore",
    });
    return res.exitCode === 0 ? res.stdout.toString().trim() : "";
  } catch {
    return "";
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

const line1Parts = [`${C(188)}󰉋 ${R}${fishPath(cwd)}`];
if (repoName)
  line1Parts.push(
    `${repoEmoji ? `${repoEmoji} ` : ""}${C(30)}${repoName}${R}`,
  );
if (gitBranch) line1Parts.push(`${C(96)}⎇ ${gitBranch}${R}`);
const line1 = line1Parts.join(` ${C(7)}|${R} `);

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
const line2Parts = [`${C(188)}󰧑 ${R}${BOLD}${model}${R}`];

const ctxPct = data.context_window?.used_percentage;
const ctxSize = data.context_window?.context_window_size;
const ctxUsage = data.context_window?.current_usage;
if (ctxPct != null && ctxUsage && ctxSize) {
  const used =
    (ctxUsage.input_tokens ?? 0) +
    (ctxUsage.cache_creation_input_tokens ?? 0) +
    (ctxUsage.cache_read_input_tokens ?? 0);
  line2Parts.push(
    `${DIM}ctx${R} ${gradient(ctxPct)}${ring(ctxPct)} ${kFmt(used)}/${kFmt(ctxSize)}${R}`,
  );
} else if (ctxPct != null) {
  line2Parts.push(fmt("ctx", ctxPct));
}

const five = data.rate_limits?.five_hour?.used_percentage;
if (five != null) line2Parts.push(fmt("5h", five));

const week = data.rate_limits?.seven_day?.used_percentage;
if (week != null) line2Parts.push(fmt("7d", week));

const line2 = line2Parts.join("  ");

process.stdout.write(`${line1}\n${line2}`);
