#!/usr/bin/env bun
// Validate cloud CLI commands via PreToolUse hook
// Usage: validate-cloud.ts <service>
// Reads patterns from patterns/<service>.txt

export interface Pattern {
  regex: RegExp;
  decision: string;
  reason: string;
}

export interface MatchResult {
  decision: string;
  reason: string;
}

const PRE = String.raw`(^|[;&|]\s*)`;

export function parsePatterns(text: string): Pattern[] {
  const patterns: Pattern[] = [];

  for (const raw of text.split("\n")) {
    const line = raw.replace(/#.*/, "").trim();
    if (!line) continue;

    const parts = line.split("|");
    if (parts.length < 3) continue;

    const [pat, dec, reason] = parts.map((s) => s.trim());
    patterns.push({
      regex: new RegExp(`${PRE}${pat}`),
      decision: dec,
      reason: reason,
    });
  }

  return patterns;
}

export function matchCommand(
  cmd: string,
  patterns: Pattern[]
): MatchResult | null {
  for (const { regex, decision, reason } of patterns) {
    if (regex.test(cmd)) {
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

  const patternsPath = new URL(`patterns/${service}.txt`, import.meta.url)
    .pathname;
  if (!(await Bun.file(patternsPath).exists())) process.exit(0);

  const text = Bun.file(patternsPath).textSync();
  const patterns = parsePatterns(text);
  const result = matchCommand(cmd, patterns);
  if (result) {
    respond(result.decision, result.reason);
  }

  process.exit(0);
}
