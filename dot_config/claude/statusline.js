#!/usr/bin/env bun
import { basename } from "node:path";

const data = JSON.parse(await Bun.stdin.text());

const R = "\x1b[0m";
const DIM = "\x1b[2m";
const BOLD = "\x1b[1m";
const C = (n) => `\x1b[38;5;${n}m`;

// --- Line 1: cwd | git-root | git-branch ---

const fishPath = (p) => {
  const home = Bun.env.HOME ?? "";
  const rel = p.startsWith(home) ? "~" + p.slice(home.length) : p;
  const segs = rel.split("/");
  if (segs.length <= 1) return rel;
  return [...segs.slice(0, -1).map((s) => s[0] ?? ""), segs.at(-1)].join("/");
};

const cwd = data.workspace?.current_dir ?? Bun.env.PWD ?? "";
const gitRoot = (() => {
  try {
    const res = Bun.spawnSync(["git", "rev-parse", "--show-toplevel"], {
      cwd,
      stdout: "pipe",
      stderr: "ignore",
    });
    return res.exitCode === 0 ? res.stdout.toString().trim() : "";
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

const line1Parts = [`${C(188)}󰉋 ${R} ${fishPath(cwd)}`];
if (gitRoot) line1Parts.push(`${C(30)}${basename(gitRoot)}${R}`);
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

const model = data.model?.display_name ?? "Claude";
const line2Parts = [`${C(188)}󰧑 ${R} ${BOLD}${model}${R}`];

const ctx = data.context_window?.used_percentage;
if (ctx != null) line2Parts.push(fmt("ctx", ctx));

const five = data.rate_limits?.five_hour?.used_percentage;
if (five != null) line2Parts.push(fmt("5h", five));

const week = data.rate_limits?.seven_day?.used_percentage;
if (week != null) line2Parts.push(fmt("7d", week));

const line2 = line2Parts.join("  ");

process.stdout.write(`${line1}\n${line2}`);
