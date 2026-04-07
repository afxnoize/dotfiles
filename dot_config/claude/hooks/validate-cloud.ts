#!/usr/bin/env bun
// Validate cloud CLI commands via PreToolUse hook
// Usage: validate-cloud.ts <service>
// Reads patterns from patterns/<service>.ts

export interface Pattern {
  pattern: RegExp;
  decision: string;
  reason: string;
}

export interface MatchResult {
  decision: string;
  reason: string;
}

const PRE = String.raw`(^|[;&|]\s*)`;

export function matchCommand(
  cmd: string,
  patterns: Pattern[]
): MatchResult | null {
  for (const { pattern, decision, reason } of patterns) {
    const withPre = new RegExp(`${PRE}${pattern.source}`);
    if (withPre.test(cmd)) {
      return { decision, reason };
    }
  }
  return null;
}

export function hasServiceCommand(cmd: string, service: string): boolean {
  return new RegExp(`${PRE}${service}\\s`).test(cmd);
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
  const result = matchCommand(cmd, patterns);
  if (result) {
    respond(result.decision, result.reason);
  }

  process.exit(0);
}
