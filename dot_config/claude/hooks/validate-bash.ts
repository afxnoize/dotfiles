#!/usr/bin/env bun
// Validate Bash commands via PreToolUse hook (run through validate-bash.sh).
// Blocks dangerous git/gh operations. Rules inspect the argv of each command
// found by shell-parse.ts instead of regexing the raw string, so global options
// (`git -C . push`), wrappers (`sudo git push`), subshells and chained commands
// are all seen.

import { resolve } from "node:path";
import { basename, invocations, isDynamic, UNVERIFIABLE } from "./shell-parse";

export interface Decision {
  decision: "deny" | "ask";
  reason: string;
}

export interface Context {
  cwd: string;
  /** Current branch of the repository at dir, or null when it cannot be told. */
  currentBranch: (dir: string) => string | null;
}

const PROTECTED_EXACT = /^(main|master|development|develop|dev|release(\/.*)?)$/;
const PROTECTED_MSG = "Push to protected branch is blocked. Ask the user to push manually.";
const BARE_PUSH_MSG =
  "Bare git push is blocked. Specify remote and branch explicitly (e.g. git push origin <branch>), or ask the user to push.";

// Options of `git` itself that consume the next word.
const GIT_VALUE_OPTS = new Set([
  "-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path",
  "--super-prefix", "--config-env", "--attr-source",
]);
// Options of `git push` that consume the next word.
const PUSH_VALUE_OPTS = new Set(["--repo", "--receive-pack", "--exec", "-o", "--push-option"]);
const GH_VALUE_OPTS = new Set(["-R", "--repo", "-H", "--hostname"]);

const GH_DENY: Array<[string, string, string]> = [
  ["pr", "merge", "gh pr merge is blocked. Ask the user to merge manually."],
  ["pr", "close", "gh pr close is blocked. Ask the user to close PRs manually."],
  ["issue", "close", "gh issue close is blocked. Ask the user to close issues manually."],
  ["issue", "delete", "gh issue delete is blocked. Ask the user to delete issues manually."],
  ["repo", "delete", "gh repo delete is blocked. Ask the user to delete repos manually."],
  ["repo", "archive", "gh repo archive is blocked. Ask the user to archive repos manually."],
  ["release", "delete", "gh release delete is blocked. Ask the user to delete releases manually."],
];

const deny = (reason: string): Decision => ({ decision: "deny", reason });
const ask = (reason: string): Decision => ({ decision: "ask", reason });

function shortCluster(token: string, letter: string): boolean {
  return new RegExp(`^-[A-Za-z]*${letter}[A-Za-z]*$`).test(token);
}

function isProtectedBranch(name: string): boolean {
  if (PROTECTED_EXACT.test(name)) return true;
  // main/master as a later path segment: hotfix/main, feature/sub/master
  return name.split("/").slice(1).some((seg) => seg === "main" || seg === "master");
}

interface GitCall {
  sub: string | null;
  args: string[];
  dirs: string[]; // -C values, in order
}

function parseGit(argv: string[]): GitCall {
  const dirs: string[] = [];
  const aliases = new Map<string, string[]>();
  let i = 1;
  while (i < argv.length && argv[i].startsWith("-")) {
    const t = argv[i];
    const eq = t.indexOf("=");
    const name = eq < 0 ? t : t.slice(0, eq);
    if (t === "-C") {
      dirs.push(argv[i + 1] ?? "");
      i += 2;
    } else if (t === "-c") {
      // `-c alias.p=push` makes `git p` run push
      const m = /^alias\.([^=]+)=(.*)$/.exec(argv[i + 1] ?? "");
      if (m) aliases.set(m[1], m[2].split(/\s+/).filter(Boolean));
      i += 2;
    } else if (GIT_VALUE_OPTS.has(name) && eq < 0) {
      i += 2;
    } else {
      i++;
    }
  }
  let sub = argv[i] ?? null;
  let args = argv.slice(i + 1);
  const expansion = sub === null ? undefined : aliases.get(sub);
  if (expansion && expansion.length) {
    sub = expansion[0];
    args = [...expansion.slice(1), ...args];
  }
  return { sub, args, dirs };
}

function checkPush(call: GitCall, ctx: Context): Decision | null {
  const positional: string[] = [];
  for (let i = 0; i < call.args.length; i++) {
    const t = call.args[i];
    if (t === "--") {
      positional.push(...call.args.slice(i + 1));
      break;
    }
    if (t === "--all" || t === "--mirror") {
      return deny("git push --all / --mirror updates every branch including protected ones. Push a named branch instead.");
    }
    if (t.startsWith("-")) {
      if (PUSH_VALUE_OPTS.has(t)) i++;
      continue;
    }
    positional.push(t);
  }
  if (positional.length < 2) return deny(BARE_PUSH_MSG);

  const dir = call.dirs.reduce((acc, d) => resolve(acc, d), ctx.cwd);
  for (const spec of positional.slice(1)) {
    // A variable, substitution, brace list or glob can expand to a protected branch.
    if (isDynamic(spec) || /[*?[]/.test(spec)) {
      return ask("The push target is built from a variable, substitution or pattern, so it cannot be checked. Proceed?");
    }
    const ref = spec.replace(/^\+/, "");
    let dst = ref.slice(ref.lastIndexOf(":") + 1).replace(/^refs\/heads\//, "");
    if (dst === "HEAD" || dst === "@") {
      const branch = ctx.currentBranch(dir);
      if (!branch) return ask("Cannot tell which branch HEAD pushes to. Proceed?");
      dst = branch;
    }
    if (isProtectedBranch(dst)) return deny(PROTECTED_MSG);
  }
  return null;
}

function checkGit(argv: string[], ctx: Context): Decision | null {
  const call = parseGit(argv);
  const { sub, args } = call;
  if (sub !== null && isDynamic(sub)) {
    return ask("The git subcommand is built from a variable or substitution, so it cannot be checked. Proceed?");
  }
  switch (sub) {
    case "push":
      return checkPush(call, ctx);
    case "add":
      if (args.some((t) => t === "." || t === "--all" || shortCluster(t, "A"))) {
        return deny("git add -A / git add . is blocked. Specify file names explicitly.");
      }
      return null;
    case "reset":
      return args.includes("--hard")
        ? deny("git reset --hard is blocked. Ask the user before discarding changes.")
        : null;
    case "clean":
      return args.some((t) => t === "--force" || shortCluster(t, "f"))
        ? deny("git clean -f is blocked. Ask the user before removing untracked files.")
        : null;
    case "checkout":
      return args.includes("--")
        ? deny("git checkout -- is blocked. Ask the user before discarding changes.")
        : null;
    case "branch": {
      const force = args.some((t) => t === "--force" || shortCluster(t, "f"));
      const del = args.some((t) => t === "--delete" || shortCluster(t, "d"));
      return args.some((t) => shortCluster(t, "D")) || (force && del)
        ? deny("git branch -D is blocked. Ask the user before force-deleting branches.")
        : null;
    }
    default:
      return null;
  }
}

function checkGh(argv: string[]): Decision | null {
  const words: string[] = [];
  for (let i = 1; i < argv.length; i++) {
    const t = argv[i];
    if (t.startsWith("-")) {
      if (GH_VALUE_OPTS.has(t)) i++;
      continue;
    }
    words.push(t);
  }
  for (const [group, action, reason] of GH_DENY) {
    if (words[0] === group && words[1] === action) return deny(reason);
  }
  return null;
}

/** First deny wins; otherwise the first ask; otherwise null (allow). */
export function evaluate(cmd: string, ctx: Context): Decision | null {
  let pending: Decision | null = null;
  for (const argv of invocations(cmd)) {
    if (argv[0] === UNVERIFIABLE) {
      pending ??= ask(`${argv[1]}, so it cannot be checked. Proceed?`);
      continue;
    }
    const name = basename(argv[0]);
    const result = name === "git" ? checkGit(argv, ctx) : name === "gh" ? checkGh(argv) : null;
    if (!result) continue;
    if (result.decision === "deny") return result;
    pending ??= result;
  }
  return pending;
}

function gitCurrentBranch(dir: string): string | null {
  const proc = Bun.spawnSync(
    ["git", "-c", "core.fsmonitor=false", "-C", dir, "symbolic-ref", "--short", "-q", "HEAD"],
    { stdout: "pipe", stderr: "ignore" }
  );
  if (proc.exitCode !== 0) return null;
  return proc.stdout.toString().trim() || null;
}

function respond(d: Decision): void {
  console.log(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: d.decision,
        permissionDecisionReason: d.reason,
      },
    })
  );
}

// Main: skip when imported as module (for testing)
if (import.meta.main) {
  try {
    const input = await Bun.stdin.json();
    const cmd = input.tool_input?.command ?? "";
    if (input.tool_name === "Bash" && cmd) {
      const cwd = typeof input.cwd === "string" && input.cwd ? input.cwd : process.cwd();
      const result = evaluate(cmd, { cwd, currentBranch: gitCurrentBranch });
      if (result) respond(result);
    }
  } catch (err) {
    // A guard that crashes must not silently allow, nor lock the session out.
    respond(ask(`validate-bash failed to check this command (${String(err)}). Proceed?`));
  }
  process.exit(0);
}
