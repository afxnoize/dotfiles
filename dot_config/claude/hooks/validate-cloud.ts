#!/usr/bin/env bun
// Validate cloud CLI commands via PreToolUse hook
// Usage: validate-cloud.ts <service>
// Reads patterns from patterns/<service>.ts

import { basename, invocations, isDynamic, UNVERIFIABLE } from "./shell-parse";

export interface Pattern {
  /**
   * Tested against the canonical line `<cli> <service> <operation> <args...>` for aws
   * (`aws iam delete-user ...`) or `<cli> <command> <args...>` for b2 (`b2 rm ...`),
   * with global options removed and tokens joined by single spaces. matchTokens() pins it to the
   * start of the line, so write it without `^`. Conventions in the tables:
   *   \s+      spacing between words
   *   delete-  a trailing `-` matches every operation with that prefix (delete-user, ...)
   *   .*       anything in between: `attach-.*-policy` covers attach-user-policy and
   *            attach-role-policy, `rm\s+.*--recursive` the flag anywhere after rm
   *   (a|b)    alternatives
   */
  pattern: RegExp;
  decision: string;
  reason: string;
}

export interface MatchResult {
  decision: string;
  reason: string;
}

// aws accepts its global options anywhere on the line (`aws s3 --region x rb`),
// so they are removed before matching to keep the service and operation adjacent.
const AWS_GLOBAL_VALUE_OPTS = new Set([
  "--endpoint-url", "--output", "--query", "--profile", "--region", "--ca-bundle",
  "--cli-read-timeout", "--cli-connect-timeout", "--cli-binary-format", "--color",
]);
const AWS_GLOBAL_FLAGS = new Set([
  "--debug", "--no-verify-ssl", "--no-paginate", "--no-sign-request",
  "--no-cli-pager", "--cli-auto-prompt", "--no-cli-auto-prompt",
]);
const B2_GLOBAL_VALUE_OPTS = new Set(["--log-config"]);

/**
 * Argv of every `service` invocation in cmd, including nested and wrapped ones.
 * Code that cannot be read statically counts too when the command mentions the
 * service at all (it may be building that command at runtime).
 */
export function serviceInvocations(cmd: string, service: string): string[][] {
  const all = invocations(cmd);
  const mine = all.filter((argv) => basename(argv[0]) === service);
  if (cmd.includes(service)) mine.push(...all.filter((argv) => argv[0] === UNVERIFIABLE));
  return mine;
}

/** [service, ...rest] with global options removed, so patterns see `aws <svc> <op> ...`. */
export function canonicalize(argv: string[], service: string): string[] {
  const out = [service];
  const rest = argv.slice(1);
  if (service === "aws") {
    for (let i = 0; i < rest.length; i++) {
      const t = rest[i];
      const name = t.includes("=") ? t.slice(0, t.indexOf("=")) : t;
      if (AWS_GLOBAL_FLAGS.has(name)) continue;
      if (AWS_GLOBAL_VALUE_OPTS.has(name)) {
        if (!t.includes("=")) i++;
        continue;
      }
      out.push(t);
    }
  } else {
    let i = 0;
    while (i < rest.length && rest[i].startsWith("-")) {
      const t = rest[i];
      i += B2_GLOBAL_VALUE_OPTS.has(t) ? 2 : 1;
    }
    out.push(...rest.slice(i));
  }
  return out;
}

function matchTokens(
  tokens: string[],
  service: string,
  patterns: Pattern[]
): MatchResult | null {
  const line = tokens.map((t) => t.replace(/[\r\n]+/g, " ")).join(" ");
  for (const { pattern, decision, reason } of patterns) {
    if (new RegExp(`^${pattern.source}`).test(line)) return { decision, reason };
  }
  // The service or operation comes from a variable or substitution, so no
  // pattern can have looked at it. Let the user decide instead of passing it.
  if (tokens.slice(1, 3).some(isDynamic)) {
    return {
      decision: "ask",
      reason: `Cannot verify a dynamic ${service} command. Proceed?`,
    };
  }
  return null;
}

/** First matching rule per invocation; deny wins over ask across invocations. */
export function matchCommand(
  cmd: string,
  patterns: Pattern[],
  service: string
): MatchResult | null {
  let ask: MatchResult | null = null;
  for (const argv of serviceInvocations(cmd, service)) {
    const result: MatchResult | null =
      argv[0] === UNVERIFIABLE
        ? {
            decision: "ask",
            reason: `${argv[1]}, so it cannot be checked for ${service} commands. Proceed?`,
          }
        : matchTokens(canonicalize(argv, service), service, patterns);
    if (!result) continue;
    if (result.decision === "deny") return result;
    ask ??= result;
  }
  return ask;
}

export function hasServiceCommand(cmd: string, service: string): boolean {
  return serviceInvocations(cmd, service).length > 0;
}

function respond(decision: string, reason: string): void {
  console.log(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: decision,
        permissionDecisionReason: reason,
      },
    })
  );
}

// Main: skip when imported as module (for testing)
if (import.meta.main) {
  const service = process.argv[2];
  if (!service) process.exit(0);

  // This hook runs on every Bash call with onFailure=block, so a crash here
  // would block unrelated commands. Ask instead of failing.
  try {
    const input = await Bun.stdin.json();
    const cmd = input.tool_input?.command ?? "";
    if (!cmd) process.exit(0);

    if (!hasServiceCommand(cmd, service)) process.exit(0);

    const patternsPath = new URL(`patterns/${service}.ts`, import.meta.url)
      .pathname;
    if (!(await Bun.file(patternsPath).exists())) process.exit(0);

    const { default: patterns } = await import(patternsPath);
    const result = matchCommand(cmd, patterns, service);
    if (result) {
      respond(result.decision, result.reason);
    }
  } catch (err) {
    respond("ask", `validate-cloud failed to check this command (${String(err)}). Proceed?`);
  }

  process.exit(0);
}
