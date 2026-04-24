import { afterEach, beforeEach, describe, expect, test } from 'bun:test';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import {
  cellCount,
  compareNum,
  findTables,
  formatMessage,
  isKind,
  isSeverity,
  loadRules,
  matchRule,
  type Rule,
  type TableNode,
} from '../dot_local/bin/executable_mdtlint.ts';

const BIN = join(
  import.meta.dir,
  '..',
  'dot_local',
  'bin',
  'executable_mdtlint.ts',
);

describe('cellCount', () => {
  test.each([
    { label: 'pipes on both sides', line: '|---|---|', expected: 2 },
    { label: 'no outer pipes', line: '---|---', expected: 2 },
    { label: 'three cells with whitespace', line: '| a | b | c |', expected: 3 },
    { label: 'single cell', line: '| --- |', expected: 1 },
  ])('counts $expected cells when $label', ({ line, expected }) => {
    expect(cellCount(line)).toBe(expected);
  });
});

describe('compareNum', () => {
  describe('lt (strictly less than)', () => {
    test('is true when value is below threshold', () => {
      expect(compareNum(1, { lt: 2 })).toBe(true);
    });
    test('is false when value equals threshold', () => {
      expect(compareNum(2, { lt: 2 })).toBe(false);
    });
    test('is false when value exceeds threshold', () => {
      expect(compareNum(3, { lt: 2 })).toBe(false);
    });
  });

  describe('le (less than or equal)', () => {
    test('is true when value equals threshold', () => {
      expect(compareNum(2, { le: 2 })).toBe(true);
    });
    test('is false when value exceeds threshold', () => {
      expect(compareNum(3, { le: 2 })).toBe(false);
    });
  });

  describe('gt (strictly greater than)', () => {
    test('is true when value is above threshold', () => {
      expect(compareNum(3, { gt: 2 })).toBe(true);
    });
    test('is false when value equals threshold', () => {
      expect(compareNum(2, { gt: 2 })).toBe(false);
    });
  });

  describe('ge (greater than or equal)', () => {
    test('is true when value equals threshold', () => {
      expect(compareNum(2, { ge: 2 })).toBe(true);
    });
    test('is false when value is below threshold', () => {
      expect(compareNum(1, { ge: 2 })).toBe(false);
    });
  });

  describe('eq (equal)', () => {
    test('is true when values match', () => {
      expect(compareNum(2, { eq: 2 })).toBe(true);
    });
    test('is false when values differ', () => {
      expect(compareNum(3, { eq: 2 })).toBe(false);
    });
  });

  describe('ne (not equal)', () => {
    test('is true when values differ', () => {
      expect(compareNum(3, { ne: 2 })).toBe(true);
    });
    test('is false when values match', () => {
      expect(compareNum(2, { ne: 2 })).toBe(false);
    });
  });

  describe('combined operators', () => {
    test('evaluates range (ge ∧ lt) as AND', () => {
      expect(compareNum(3, { ge: 2, lt: 5 })).toBe(true);
    });
    test('is false when any single operator fails', () => {
      expect(compareNum(5, { ge: 2, lt: 5 })).toBe(false);
    });
  });

  test('empty comparator vacuously matches any value', () => {
    expect(compareNum(42, {})).toBe(true);
  });
});

describe('matchRule', () => {
  const mkNode = (cols: number, rows: number): TableNode => ({
    kind: 'table',
    line: 1,
    cols,
    rows,
  });
  const mkRule = (spec: Rule['rule']): Rule => ({
    id: 't',
    severity: 'warning',
    message: '',
    rule: spec,
    source: '',
  });

  test('matches when cols satisfies the comparator', () => {
    const rule = mkRule({ kind: 'table', cols: { lt: 3 } });
    expect(matchRule(mkNode(2, 1), rule)).toBe(true);
  });

  test('does not match when cols violates the comparator', () => {
    const rule = mkRule({ kind: 'table', cols: { lt: 3 } });
    expect(matchRule(mkNode(3, 1), rule)).toBe(false);
  });

  test('matches when rows satisfies the comparator', () => {
    const rule = mkRule({ kind: 'table', rows: { eq: 5 } });
    expect(matchRule(mkNode(3, 5), rule)).toBe(true);
  });

  describe('with both cols and rows comparators', () => {
    const rule = mkRule({
      kind: 'table',
      cols: { lt: 3 },
      rows: { gt: 1 },
    });

    test('matches only when both are satisfied', () => {
      expect(matchRule(mkNode(2, 2), rule)).toBe(true);
    });

    test('rejects when rows comparator fails alone', () => {
      expect(matchRule(mkNode(2, 1), rule)).toBe(false);
    });

    test('rejects when cols comparator fails alone', () => {
      expect(matchRule(mkNode(3, 2), rule)).toBe(false);
    });
  });
});

describe('formatMessage', () => {
  test('substitutes a known placeholder with its context value', () => {
    expect(formatMessage('cols={cols}', { cols: 2 })).toBe('cols=2');
  });

  test('substitutes multiple placeholders', () => {
    expect(formatMessage('cols={cols} rows={rows}', { cols: 2, rows: 3 })).toBe(
      'cols=2 rows=3',
    );
  });

  test('leaves unknown placeholders unchanged', () => {
    expect(formatMessage('val={missing}', {})).toBe('val={missing}');
  });
});

describe('isSeverity', () => {
  test.each(['error', 'warning', 'info'])(
    'accepts %p as a valid severity',
    (sev) => {
      expect(isSeverity(sev)).toBe(true);
    },
  );

  test.each(['critical', '', 'WARNING', 123, null, undefined])(
    'rejects %p as an invalid severity',
    (sev) => {
      expect(isSeverity(sev)).toBe(false);
    },
  );
});

describe('isKind', () => {
  test('accepts "table" as the only supported kind', () => {
    expect(isKind('table')).toBe(true);
  });

  test.each(['heading', 'list', 'code', ''])(
    'rejects %p as an unsupported kind',
    (kind) => {
      expect(isKind(kind)).toBe(false);
    },
  );
});

describe('findTables', () => {
  let tmp: string;
  beforeEach(() => {
    tmp = mkdtempSync(join(tmpdir(), 'mdtlint-find-'));
  });
  afterEach(() => {
    rmSync(tmp, { recursive: true, force: true });
  });
  const writeMd = (content: string): string => {
    const p = join(tmp, 'sample.md');
    writeFileSync(p, content);
    return p;
  };

  test('detects a GFM table with header and separator', () => {
    const p = writeMd(`# hdr

| a | b |
|---|---|
| 1 | 2 |
`);
    expect(findTables(p)).toHaveLength(1);
  });

  test('reports header line (1-indexed) as the table location', () => {
    const p = writeMd(`line1
| a | b |
|---|---|
| 1 | 2 |
`);
    const [table] = findTables(p);
    expect(table.line).toBe(2);
  });

  test('counts columns from the separator row', () => {
    const p = writeMd(`| a | b | c |
|---|---|---|
| 1 | 2 | 3 |
`);
    const [table] = findTables(p);
    expect(table.cols).toBe(3);
  });

  test('counts body rows', () => {
    const p = writeMd(`| a | b |
|---|---|
| 1 | 2 |
| 3 | 4 |
`);
    const [table] = findTables(p);
    expect(table.rows).toBe(2);
  });

  test('ignores table-like syntax inside a fenced code block', () => {
    const p = writeMd(`\`\`\`
| a | b |
|---|---|
| 1 | 2 |
\`\`\`
`);
    expect(findTables(p)).toHaveLength(0);
  });

  test('does not close a backtick fence with a tilde fence', () => {
    const p = writeMd(`\`\`\`
| a | b |
|---|---|
~~~
| x | y |
|---|---|
\`\`\`
`);
    expect(findTables(p)).toHaveLength(0);
  });

  test('closes a fence when the same marker with greater length appears', () => {
    const p = writeMd(`\`\`\`\`
| a | b |
|---|---|
\`\`\`\`\`
| c | d |
|---|---|
| 1 | 2 |
`);
    expect(findTables(p)).toHaveLength(1);
  });

  test('does not treat a setext heading underline as a table separator', () => {
    const p = writeMd(`Heading
---
body text
`);
    expect(findTables(p)).toHaveLength(0);
  });

  test('stops counting rows at free text following the table', () => {
    const p = writeMd(`| a | b | c |
|---|---|---|
| 1 | 2 | 3 |

foo | bar
`);
    const [table] = findTables(p);
    expect(table.rows).toBe(1);
  });

  test('stops counting rows when cell count diverges from header', () => {
    const p = writeMd(`| a | b | c |
|---|---|---|
| 1 | 2 | 3 |
| 4 | 5 |
`);
    const [table] = findTables(p);
    expect(table.rows).toBe(1);
  });

  test('detects multiple tables in a single file', () => {
    const p = writeMd(`| a | b |
|---|---|
| 1 | 2 |

| x | y | z |
|---|---|---|
| 4 | 5 | 6 |
`);
    const tables = findTables(p);
    expect(tables.map((t) => t.cols)).toEqual([2, 3]);
  });
});

describe('loadRules', () => {
  let tmp: string;
  beforeEach(() => {
    tmp = mkdtempSync(join(tmpdir(), 'mdtlint-rules-'));
  });
  afterEach(() => {
    rmSync(tmp, { recursive: true, force: true });
  });
  const writeRule = (name: string, body: string): void => {
    writeFileSync(join(tmp, name), body);
  };

  test('loads a valid rule', () => {
    writeRule(
      'ok.yaml',
      `id: ok
severity: warning
rule:
  kind: table
  cols: { lt: 3 }
`,
    );
    expect(loadRules(tmp)).toHaveLength(1);
  });

  test('defaults severity to "warning" when omitted', () => {
    writeRule('nosev.yaml', `id: nosev\nrule: { kind: table }\n`);
    const [rule] = loadRules(tmp);
    expect(rule.severity).toBe('warning');
  });

  test('skips a rule with an invalid severity', () => {
    writeRule(
      'bad.yaml',
      `id: bad\nseverity: critical\nrule: { kind: table }\n`,
    );
    expect(loadRules(tmp)).toHaveLength(0);
  });

  test('skips a rule with an unknown kind', () => {
    writeRule('bad.yaml', `id: bad\nrule: { kind: heading }\n`);
    expect(loadRules(tmp)).toHaveLength(0);
  });

  test('skips a rule missing id', () => {
    writeRule('noid.yaml', `rule: { kind: table }\n`);
    expect(loadRules(tmp)).toHaveLength(0);
  });

  describe('when two rules share an id', () => {
    beforeEach(() => {
      writeRule('a.yaml', `id: dup\nrule: { kind: table, cols: { lt: 3 } }\n`);
      writeRule('b.yaml', `id: dup\nrule: { kind: table, cols: { lt: 5 } }\n`);
    });

    test('keeps exactly one rule', () => {
      expect(loadRules(tmp)).toHaveLength(1);
    });

    test('keeps the rule from the alphabetically first filename', () => {
      const [rule] = loadRules(tmp);
      expect(rule.source.endsWith('a.yaml')).toBe(true);
    });
  });

  test('skips a malformed YAML file without aborting the directory scan', () => {
    writeRule('broken.yaml', `id: x\n  rule: invalid: : :\n`);
    writeRule('ok.yaml', `id: ok\nrule: { kind: table }\n`);
    const rules = loadRules(tmp);
    expect(rules.map((r) => r.id)).toEqual(['ok']);
  });

  test('ignores files without a YAML extension', () => {
    writeRule('note.txt', 'id: x\nrule: { kind: table }\n');
    expect(loadRules(tmp)).toHaveLength(0);
  });

  test('returns an empty array when the directory does not exist', () => {
    expect(loadRules(join(tmp, 'does-not-exist'))).toEqual([]);
  });
});

describe('CLI', () => {
  let tmp: string;
  beforeEach(() => {
    tmp = mkdtempSync(join(tmpdir(), 'mdtlint-cli-'));
  });
  afterEach(() => {
    rmSync(tmp, { recursive: true, force: true });
  });

  const spawn = async (args: string[]) => {
    const proc = Bun.spawn(['bun', BIN, ...args], {
      stdout: 'pipe',
      stderr: 'pipe',
    });
    const stdout = await new Response(proc.stdout).text();
    const stderr = await new Response(proc.stderr).text();
    const exitCode = await proc.exited;
    return { stdout, stderr, exitCode };
  };

  const writeFixture = async (
    ruleYaml: string,
    md: string,
  ): Promise<{ rulesDir: string; mdPath: string }> => {
    const rulesDir = join(tmp, 'rules');
    await Bun.write(join(rulesDir, 'rule.yaml'), ruleYaml);
    const mdPath = join(tmp, 'sample.md');
    await Bun.write(mdPath, md);
    return { rulesDir, mdPath };
  };

  describe('--help', () => {
    test('exits with code 0', async () => {
      const { exitCode } = await spawn(['--help']);
      expect(exitCode).toBe(0);
    });

    test('prints usage text', async () => {
      const { stdout } = await spawn(['--help']);
      expect(stdout).toContain('Usage:');
    });
  });

  test('exits with code 2 when no file arguments are given', async () => {
    const { exitCode } = await spawn([]);
    expect(exitCode).toBe(2);
  });

  describe('when a file violates a rule', () => {
    test('exits with code 1', async () => {
      const { rulesDir, mdPath } = await writeFixture(
        `id: no-small\nrule: { kind: table, cols: { lt: 3 } }\n`,
        `| a | b |\n|---|---|\n| 1 | 2 |\n`,
      );
      const { exitCode } = await spawn(['--rules', rulesDir, mdPath]);
      expect(exitCode).toBe(1);
    });

    test('prints the rule id in the finding', async () => {
      const { rulesDir, mdPath } = await writeFixture(
        `id: no-small\nrule: { kind: table, cols: { lt: 3 } }\n`,
        `| a | b |\n|---|---|\n| 1 | 2 |\n`,
      );
      const { stdout } = await spawn(['--rules', rulesDir, mdPath]);
      expect(stdout).toContain('no-small');
    });

    test('expands {cols} in the message template', async () => {
      const { rulesDir, mdPath } = await writeFixture(
        `id: r\nmessage: "cols={cols}"\nrule: { kind: table, cols: { lt: 3 } }\n`,
        `| a | b |\n|---|---|\n| 1 | 2 |\n`,
      );
      const { stdout } = await spawn(['--rules', rulesDir, mdPath]);
      expect(stdout).toContain('cols=2');
    });
  });

  test('exits with code 2 when the rules directory has no loadable rules', async () => {
    const rulesDir = join(tmp, 'rules');
    await Bun.write(join(rulesDir, '.keep'), '');
    const mdPath = join(tmp, 'sample.md');
    await Bun.write(mdPath, `| a | b |\n|---|---|\n`);
    const { stderr, exitCode } = await spawn(['--rules', rulesDir, mdPath]);
    expect(exitCode).toBe(2);
    expect(stderr).toContain('no rules loaded');
  });

  test('exits with code 2 when the target file does not exist', async () => {
    const { rulesDir } = await writeFixture(
      `id: r\nrule: { kind: table, cols: { lt: 3 } }\n`,
      ``,
    );
    const { exitCode } = await spawn([
      '--rules',
      rulesDir,
      join(tmp, 'nope.md'),
    ]);
    expect(exitCode).toBe(2);
  });
});
