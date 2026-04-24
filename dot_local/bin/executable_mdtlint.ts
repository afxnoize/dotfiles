#!/usr/bin/env bun
// mdtlint: lint GFM markdown tables against ast-grep-flavored YAML rules.

import { readFileSync, readdirSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

const SEVERITIES = ['error', 'warning', 'info'] as const;
type Severity = (typeof SEVERITIES)[number];

const KINDS = ['table'] as const;
type Kind = (typeof KINDS)[number];

interface Comparator {
  lt?: number;
  le?: number;
  gt?: number;
  ge?: number;
  eq?: number;
  ne?: number;
}

interface RuleSpec {
  kind: Kind;
  cols?: Comparator;
  rows?: Comparator;
}

interface Rule {
  id: string;
  severity: Severity;
  message: string;
  rule: RuleSpec;
  source: string;
}

interface TableNode {
  kind: Kind;
  line: number;
  cols: number;
  rows: number;
}

const SEP = /^\s*\|?\s*:?-+:?(\s*\|\s*:?-+:?)*\s*\|?\s*$/;
const FENCE = /^\s*([`~]{3,})/;

const DEFAULT_RULES_DIR = (() => {
  const xdg = process.env.XDG_CONFIG_HOME;
  const base = xdg && xdg.length > 0 ? xdg : join(homedir(), '.config');
  return join(base, 'mdtlint', 'rules');
})();

function cellCount(line: string): number {
  return line.trim().replace(/^\|/, '').replace(/\|$/, '').split('|').length;
}

function findTables(path: string): TableNode[] {
  const content = readFileSync(path, 'utf-8');
  const lines = content.split('\n');
  const tables: TableNode[] = [];
  let fence: { char: string; len: number } | null = null;
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const fm = line.match(FENCE);
    if (fm) {
      const marker = fm[1];
      if (fence === null) {
        fence = { char: marker[0], len: marker.length };
      } else if (marker[0] === fence.char && marker.length >= fence.len) {
        fence = null;
      }
      continue;
    }
    if (fence !== null) continue;
    if (
      line.includes('|') &&
      SEP.test(line) &&
      i > 0 &&
      lines[i - 1].includes('|')
    ) {
      const cols = cellCount(line);
      let rows = 0;
      let j = i + 1;
      while (j < lines.length) {
        const row = lines[j];
        if (row.trim() === '' || !row.includes('|') || cellCount(row) !== cols) {
          break;
        }
        rows++;
        j++;
      }
      tables.push({ kind: 'table', line: i, cols, rows });
      i = j - 1;
    }
  }
  return tables;
}

function compareNum(val: number, cmp: Comparator): boolean {
  if (cmp.lt !== undefined && !(val < cmp.lt)) return false;
  if (cmp.le !== undefined && !(val <= cmp.le)) return false;
  if (cmp.gt !== undefined && !(val > cmp.gt)) return false;
  if (cmp.ge !== undefined && !(val >= cmp.ge)) return false;
  if (cmp.eq !== undefined && !(val === cmp.eq)) return false;
  if (cmp.ne !== undefined && !(val !== cmp.ne)) return false;
  return true;
}

function matchRule(node: TableNode, rule: Rule): boolean {
  const spec = rule.rule;
  if (node.kind !== spec.kind) return false;
  if (spec.cols && !compareNum(node.cols, spec.cols)) return false;
  if (spec.rows && !compareNum(node.rows, spec.rows)) return false;
  return true;
}

function formatMessage(tpl: string, ctx: Record<string, unknown>): string {
  return tpl.replace(/\{(\w+)\}/g, (_, k) => String(ctx[k] ?? `{${k}}`));
}

function isSeverity(v: unknown): v is Severity {
  return typeof v === 'string' && (SEVERITIES as readonly string[]).includes(v);
}

function isKind(v: unknown): v is Kind {
  return typeof v === 'string' && (KINDS as readonly string[]).includes(v);
}

function loadRules(dir: string): Rule[] {
  let entries: string[];
  try {
    entries = readdirSync(dir);
  } catch {
    return [];
  }
  const rules: Rule[] = [];
  const seenIds = new Set<string>();
  for (const name of entries.sort()) {
    if (!name.endsWith('.yaml') && !name.endsWith('.yml')) continue;
    const path = join(dir, name);
    let parsed: unknown;
    try {
      parsed = Bun.YAML.parse(readFileSync(path, 'utf-8'));
    } catch (err) {
      console.error(`warning: ${path}: YAML parse error: ${(err as Error).message}`);
      continue;
    }
    const p = parsed as {
      id?: unknown;
      severity?: unknown;
      message?: unknown;
      rule?: { kind?: unknown; cols?: Comparator; rows?: Comparator };
    };
    if (typeof p?.id !== 'string' || p.id.length === 0) {
      console.error(`warning: ${path}: missing or invalid 'id', skipped`);
      continue;
    }
    if (!isKind(p.rule?.kind)) {
      console.error(
        `warning: ${path}: unknown rule.kind '${String(p.rule?.kind)}' (supported: ${KINDS.join(', ')}), skipped`,
      );
      continue;
    }
    let severity: Severity = 'warning';
    if (p.severity !== undefined) {
      if (!isSeverity(p.severity)) {
        console.error(
          `warning: ${path}: invalid severity '${String(p.severity)}' (expected: ${SEVERITIES.join(', ')}), skipped`,
        );
        continue;
      }
      severity = p.severity;
    }
    if (seenIds.has(p.id)) {
      console.error(`warning: ${path}: duplicate rule id '${p.id}', skipped`);
      continue;
    }
    seenIds.add(p.id);
    rules.push({
      id: p.id,
      severity,
      message: typeof p.message === 'string' ? p.message : p.id,
      rule: { kind: p.rule.kind, cols: p.rule.cols, rows: p.rule.rows },
      source: path,
    });
  }
  return rules;
}

function usage(): void {
  console.log(`Usage: mdtlint [--rules <dir>] <file>...

Loads YAML rules from <dir> (default: ${DEFAULT_RULES_DIR}).

Rule schema:
  id: no-small-table
  severity: warning            # error | warning | info
  message: "table has {cols} column(s); use a list"
  rule:
    kind: table                # supported: ${KINDS.join(', ')}
    cols: { lt: 3 }

Supported comparators: lt, le, gt, ge, eq, ne.
Supported fields: cols, rows.
Template variables: {cols}, {rows}.

Exit codes: 0=clean, 1=findings, 2=error.`);
}

function main(): number {
  const args = process.argv.slice(2);
  let rulesDir = DEFAULT_RULES_DIR;
  const paths: string[] = [];
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === '--rules') {
      rulesDir = args[++i];
    } else if (a.startsWith('--rules=')) {
      rulesDir = a.slice('--rules='.length);
    } else if (a === '-h' || a === '--help') {
      usage();
      return 0;
    } else {
      paths.push(a);
    }
  }
  if (paths.length === 0) {
    usage();
    return 2;
  }
  const rules = loadRules(rulesDir);
  if (rules.length === 0) {
    console.error(`error: no rules loaded from ${rulesDir}`);
    return 2;
  }
  let total = 0;
  for (const p of paths) {
    let nodes: TableNode[];
    try {
      nodes = findTables(p);
    } catch (err) {
      console.error(`error: ${p}: ${(err as Error).message}`);
      return 2;
    }
    for (const node of nodes) {
      for (const r of rules) {
        if (matchRule(node, r)) {
          const msg = formatMessage(r.message, {
            cols: node.cols,
            rows: node.rows,
          });
          console.log(`${p}:${node.line}: [${r.severity}] ${r.id}: ${msg}`);
          total++;
        }
      }
    }
  }
  return total > 0 ? 1 : 0;
}

export {
  cellCount,
  findTables,
  compareNum,
  matchRule,
  formatMessage,
  loadRules,
  isSeverity,
  isKind,
  main,
  DEFAULT_RULES_DIR,
  SEVERITIES,
  KINDS,
};
export type { Comparator, RuleSpec, Rule, TableNode, Severity, Kind };

if (import.meta.main) {
  process.exit(main());
}
