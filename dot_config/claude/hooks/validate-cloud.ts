#!/usr/bin/env bun
// Validate cloud CLI commands via PreToolUse hook
// Usage: validate-cloud.ts <service>
// Reads patterns from patterns/<service>.ts

import { basename, invocations, isDynamic } from "./shell-parse";

export interface Pattern {
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

/** Argv of every `service` invocation in cmd, including nested and wrapped ones. */
export function serviceInvocations(cmd: string, service: string): string[][] {
  return invocations(cmd).filter((argv) => basename(argv[0]) === service);
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
    const result = matchTokens(canonicalize(argv, service), service, patterns);
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

  process.exit(0);
}
