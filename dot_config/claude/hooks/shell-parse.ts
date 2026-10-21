// Minimal shell tokenizer shared by the PreToolUse command guards.
//
// The hooks used to regex the raw command string, which misses anything that is
// not literally "<tool> <subcommand>" at the start of a line (`git -C . push`,
// `sudo aws ...`, `(git push ...)`, a command on the second line, ...).
// invocations() instead returns the argv of every simple command that would
// run, so rules can inspect arguments.
//
// It is a guard-rail for an agent that may be prompt-injected, not a shell
// emulator. Out of scope: aliases, functions, variable indirection (`$CLI ...`),
// and interpreter strings other than `sh -c` / `eval` (python -c, node -e, ...).

export type Argv = string[];

const MAX_DEPTH = 8;
const MAX_LEX_DEPTH = 40;
const MAX_ARGVS = 2000;

/**
 * argv[0] of the synthetic entry invocations() emits for code it cannot read
 * (a script built at runtime, one fed through stdin, nesting that is too deep).
 * argv[1] says why. Guards should ask the user instead of passing it.
 */
export const UNVERIFIABLE = "<unverifiable>";

// Commands that run their arguments as another command. Every suffix of such a
// command is also treated as a command start, so option values that belong to
// the wrapper (`sudo -u bob git push`) do not need per-wrapper parsing.
// noglob / nocorrect / repeat are zsh precommand modifiers; the Bash tool runs zsh.
const WRAPPERS = new Set([
  "sudo", "doas", "env", "command", "builtin", "exec", "time", "nohup", "nice",
  "ionice", "timeout", "stdbuf", "setsid", "xargs", "watch", "chrt", "taskset",
  "flock", "unbuffer", "rtk", "cage", "direnv", "mise", "noglob", "nocorrect",
  "repeat",
]);
const SHELLS = new Set(["sh", "bash", "zsh", "dash", "ksh", "fish"]);
const KEYWORDS = new Set([
  "!", "{", "}", "if", "then", "else", "elif", "fi", "do", "done", "while", "until",
  "coproc",
]);
// A leading `NAME=value` word: NAME, optionally indexed (`a[1]=`) or appending
// (`PATH+=`). Only the part up to `=` is matched; the value is not looked at.
const ENV_ASSIGN = /^[A-Za-z_][A-Za-z0-9_]*(\[[^\]]*\])?\+?=/;

export function basename(path: string): string {
  const i = path.lastIndexOf("/");
  return i < 0 ? path : path.slice(i + 1);
}

/**
 * True when a token still holds something the shell would expand into other
 * text: `$...`, a backtick, or a brace list/range (`{a,b}`, `{1..3}`).
 *
 * Pattern: any `$` or backtick, or a `{...}` that contains `,` or `..`. A plain `{}`
 * (as in `find -exec ... {}`) or `{a}` is not expanded by the shell, so it stays static.
 */
export function isDynamic(token: string): boolean {
  return /[$`]|\{[^}]*(,|\.\.)[^}]*\}/.test(token);
}

// `$`, a backtick or `{` that stays literal in the word being built (inside '...',
// after a backslash, in $'...') is swapped for a private-use placeholder, so that
// isDynamic() only reacts to expansions the shell really performs: the script of
// `sh -c 'echo $HOME'` is fully known. restore() undoes the swap before a script is
// lexed again and before invocations() returns.
const LITERAL: Record<string, string> = { $: "", "`": "", "{": "" };
const UNLITERAL: Record<string, string> = { "": "$", "": "`", "": "{" };

// Swaps each of `$`, backtick and `{` for its placeholder.
function lit(s: string): string {
  return s.replace(/[$`{]/g, (c) => LITERAL[c]);
}

// Swaps the placeholders back. The character class below is the three private-use
// characters U+E000..U+E002 (they are invisible in most editors).
function restore(s: string): string {
  return s.replace(/[-]/g, (c) => UNLITERAL[c]);
}

// Decodes the escapes of a $'...' string so `$'\x6dain'` is seen as `main`.
function decodeAnsiC(body: string): string {
  const simple: Record<string, string> = {
    n: "\n", t: "\t", r: "\r", a: "\x07", b: "\b", e: "\x1b", E: "\x1b",
    f: "\f", v: "\v", "\\": "\\", "'": "'", '"': '"', "?": "?",
  };
  // One match is one escape: `\` followed by one of, in this order (so `\x41` is hex,
  // not the letter x): `\xHH` (1-2 hex digits), `\uHHHH` (1-4), `\UHHHHHHHH` (1-8),
  // `\NNN` octal (1-3 digits), or any other single character (`s` flag, so a newline
  // too), which is looked up in `simple`. The groups arrive as hex, u4, u8, oct, ch;
  // `g` replaces every escape. Unknown escapes and code points above U+10FFFF are
  // left as written.
  return body.replace(
    /\\(?:x([0-9A-Fa-f]{1,2})|u([0-9A-Fa-f]{1,4})|U([0-9A-Fa-f]{1,8})|([0-7]{1,3})|(.))/gs,
    (m, hex, u4, u8, oct, ch) => {
      if (hex !== undefined) return String.fromCharCode(parseInt(hex, 16));
      if (u4 !== undefined) return String.fromCodePoint(parseInt(u4, 16));
      if (u8 !== undefined) {
        const cp = parseInt(u8, 16);
        return cp <= 0x10ffff ? String.fromCodePoint(cp) : m;
      }
      if (oct !== undefined) return String.fromCharCode(parseInt(oct, 8) & 0xff);
      return simple[ch] ?? m;
    }
  );
}

interface Heredoc {
  delim: string;
  strip: boolean;
  expand: boolean;
}

function readBacktick(src: string, start: number): [string, number] {
  let i = start + 1;
  let inner = "";
  while (i < src.length && src[i] !== "`") {
    if (src[i] === "\\" && i + 1 < src.length) {
      const n = src[i + 1];
      inner += "$`\\".includes(n) ? n : "\\" + n;
      i += 2;
      continue;
    }
    inner += src[i];
    i++;
  }
  return [inner, i + 1];
}

// Reads a double-quoted string body starting after the opening quote.
// Command substitutions inside it execute, so they are lexed too.
function lexDouble(
  src: string,
  start: number,
  out: Argv[],
  append: (s: string) => void
): number {
  let i = start;
  while (i < src.length && src[i] !== '"') {
    const c = src[i];
    if (c === "\\" && i + 1 < src.length) {
      const n = src[i + 1];
      if (n !== "\n") append('$`"\\'.includes(n) ? lit(n) : "\\" + n);
      i += 2;
      continue;
    }
    if (c === "$" && src[i + 1] === "(") {
      const end = lexScript(src, i + 2, out, true);
      append(src.slice(i, end));
      i = end;
      continue;
    }
    if (c === "`") {
      const [inner, next] = readBacktick(src, i);
      lexScript(inner, 0, out, false);
      append(src.slice(i, next));
      i = next;
      continue;
    }
    append(c);
    i++;
  }
  return i + 1;
}

// Unquoted heredoc bodies still expand `$(...)` and backticks.
function lexExpansions(body: string, out: Argv[]): void {
  let i = 0;
  while (i < body.length) {
    if (body[i] === "\\") {
      i += 2;
    } else if (body[i] === "$" && body[i + 1] === "(") {
      i = lexScript(body, i + 2, out, true);
    } else if (body[i] === "`") {
      const [inner, next] = readBacktick(body, i);
      lexScript(inner, 0, out, false);
      i = next;
    } else {
      i++;
    }
  }
}

function readHeredocs(src: string, start: number, pending: Heredoc[], out: Argv[]): number {
  let i = start;
  for (const h of pending) {
    let body = "";
    while (i < src.length) {
      const nl = src.indexOf("\n", i);
      const end = nl < 0 ? src.length : nl;
      const line = src.slice(i, end);
      i = nl < 0 ? src.length : nl + 1;
      // `<<-` ignores leading tabs (tabs only) when looking for the closing delimiter.
      if ((h.strip ? line.replace(/^\t+/, "") : line) === h.delim) break;
      body += line + "\n";
    }
    if (h.expand) lexExpansions(body, out);
  }
  pending.length = 0;
  return i;
}

let lexDepth = 0;

// Lexes src from `start`, pushing each simple command's words to `out`.
// Returns the index after the closing `)` when closeOnParen, else src.length.
// Nested substitutions recurse, so the depth is capped.
function lexScript(src: string, start: number, out: Argv[], closeOnParen: boolean): number {
  if (lexDepth >= MAX_LEX_DEPTH) {
    out.push([UNVERIFIABLE, "command nesting is too deep to check"]);
    return src.length;
  }
  lexDepth++;
  try {
    return lexScriptBody(src, start, out, closeOnParen);
  } finally {
    lexDepth--;
  }
}

function lexScriptBody(src: string, start: number, out: Argv[], closeOnParen: boolean): number {
  let i = start;
  let argv: string[] = [];
  let word = "";
  let inWord = false;
  let skipWord = false; // the next word is a redirection target
  let parenDepth = 0;
  const heredocs: Heredoc[] = [];

  const endWord = () => {
    if (inWord) {
      if (skipWord) skipWord = false;
      else argv.push(word);
    }
    word = "";
    inWord = false;
  };
  const endCmd = () => {
    endWord();
    if (argv.length) out.push(argv);
    argv = [];
    skipWord = false;
  };

  while (i < src.length) {
    const c = src[i];
    const n = src[i + 1];

    if (c === "\\") {
      if (n === "\n") {
        i += 2;
      } else if (n !== undefined) {
        word += lit(n);
        inWord = true;
        i += 2;
      } else {
        i++;
      }
      continue;
    }
    if (c === "'") {
      const j = src.indexOf("'", i + 1);
      const end = j < 0 ? src.length : j;
      word += lit(src.slice(i + 1, end));
      inWord = true;
      i = end + 1;
      continue;
    }
    if (c === "$" && n === "'") {
      let j = i + 2;
      while (j < src.length && src[j] !== "'") j += src[j] === "\\" ? 2 : 1;
      word += lit(decodeAnsiC(src.slice(i + 2, j)));
      inWord = true;
      i = j + 1;
      continue;
    }
    if (c === '"') {
      i = lexDouble(src, i + 1, out, (s) => (word += s));
      inWord = true;
      continue;
    }
    if (c === "`") {
      const [inner, next] = readBacktick(src, i);
      lexScript(inner, 0, out, false);
      word += src.slice(i, next);
      inWord = true;
      i = next;
      continue;
    }
    if ((c === "$" || c === "<" || c === ">") && n === "(") {
      // $(...) command substitution, <(...) / >(...) process substitution
      const end = lexScript(src, i + 2, out, true);
      word += src.slice(i, end);
      inWord = true;
      i = end;
      continue;
    }
    if (c === "(" && n === "(" && !inWord) {
      // ((...)) arithmetic command: its `<<` is a shift, not a heredoc. Only
      // substitutions inside it can run commands.
      let depth = 0;
      let j = i;
      while (j < src.length) {
        if (src[j] === "(") depth++;
        else if (src[j] === ")" && --depth === 0) {
          j++;
          break;
        }
        j++;
      }
      lexExpansions(src.slice(i, j), out);
      i = j;
      continue;
    }
    if (c === "(") {
      endCmd();
      parenDepth++;
      i++;
      continue;
    }
    if (c === ")") {
      endCmd();
      if (parenDepth > 0) parenDepth--;
      else if (closeOnParen) return i + 1;
      i++;
      continue;
    }
    if (c === "<" || c === ">" || (c === "&" && n === ">")) {
      // A bare number before the operator is a file descriptor, not an argument
      // (`2>/dev/null`: the word `2` is all digits).
      if (inWord && /^\d+$/.test(word)) {
        word = "";
        inWord = false;
      } else {
        endWord();
      }
      let j = i;
      if (src[j] === "&") j++;
      const op = src[j];
      j++;
      if (op === "<" && src[j] === "<" && src[j + 1] === "<") {
        j += 2; // here-string: the next word is data
        skipWord = true;
      } else if (op === "<" && src[j] === "<") {
        j++;
        const strip = src[j] === "-";
        if (strip) j++;
        while (src[j] === " " || src[j] === "\t") j++;
        // The delimiter word runs up to whitespace or a shell operator (`;&|()<>`).
        // A quoted delimiter (`<<'EOF'`, `<<"EOF"`, `<<\EOF`) means the body is not
        // expanded; the quotes and backslashes are dropped to get the closing text.
        let raw = "";
        while (j < src.length && !/[\s;&|()<>]/.test(src[j])) raw += src[j++];
        const expand = !/['"\\]/.test(raw);
        heredocs.push({ delim: raw.replace(/['"\\]/g, ""), strip, expand });
      } else {
        if (src[j] === op) j++; // >> or <<
        if (src[j] === "&" || src[j] === "|") j++; // >& <& >|
        skipWord = true;
      }
      i = j;
      continue;
    }
    if (c === "\n") {
      endCmd();
      i++;
      if (heredocs.length) i = readHeredocs(src, i, heredocs, out);
      continue;
    }
    if (c === ";" || c === "|" || c === "&") {
      endCmd();
      i++;
      continue;
    }
    if (c === " " || c === "\t") {
      endWord();
      i++;
      continue;
    }
    if (c === "#" && !inWord) {
      while (i < src.length && src[i] !== "\n") i++;
      continue;
    }
    word += c;
    inWord = true;
    i++;
  }
  endCmd();
  return src.length;
}

function stripPrefix(argv: Argv): Argv {
  let k = 0;
  while (k < argv.length) {
    if (argv[k] === "function") {
      k += 2; // `function NAME`; the body follows as `{ ...`
    } else if (KEYWORDS.has(argv[k]) || ENV_ASSIGN.test(argv[k])) {
      k++;
    } else {
      break;
    }
  }
  return argv.slice(k);
}

type ShellInvocation =
  | { kind: "script"; script: string } // sh -c SCRIPT
  | { kind: "stdin" } // reads the script from stdin (pipe, heredoc, here-string)
  | { kind: "file" }; // sh FILE

function shellInvocation(argv: Argv): ShellInvocation {
  let i = 1;
  for (; i < argv.length; i++) {
    const t = argv[i];
    // `-c`, alone or clustered with other short flags (`-lc`, `-ec`): the next word is
    // the script. Same shape as shortCluster() in validate-bash.ts; `--long` options
    // never match.
    if (/^-[A-Za-z]*c[A-Za-z]*$/.test(t)) {
      return argv[i + 1] === undefined ? { kind: "stdin" } : { kind: "script", script: argv[i + 1] };
    }
    if (t === "--version" || t === "--help") return { kind: "file" };
    if (t === "-o" || t === "-O" || t === "+o" || t === "+O") {
      i++;
      continue;
    }
    if (t === "--") {
      i++;
      break;
    }
    if (!t.startsWith("-") && !t.startsWith("+")) break;
  }
  return i < argv.length ? { kind: "file" } : { kind: "stdin" };
}

function unverifiable(reason: string, out: Argv[]): void {
  if (out.length < MAX_ARGVS) out.push([UNVERIFIABLE, reason]);
}

// A shell lives in a bin dir; a path like `dot_config/zsh` or `/home/u/.config/zsh`
// is just a directory argument. A bare name (`zsh`) counts, and so does a path that
// ends in `/bin/NAME` or `/sbin/NAME` (`/usr/bin/zsh`); NAME may not contain another `/`.
function looksLikeShellPath(p: string): boolean {
  return !p.includes("/") || /\/s?bin\/[^/]+$/.test(p);
}

const FIND_EXEC = new Set(["-exec", "-execdir", "-ok", "-okdir"]);

/**
 * Adds the invocation `argv` starts, and those it runs in turn (the wrapped
 * command, the script of `sh -c` / `eval`).
 *
 * suffix: argv is the tail of a wrapper's arguments, which may be option values or
 * plain paths rather than a command.
 * nested: argv comes from a script that `sh -c` / `eval` was given. Its text is
 * known, but a command name built at runtime in it (`sh -c '"$@"' _ git push`) is
 * as unreadable as a script built at runtime.
 */
function expand(
  argv: Argv,
  depth: number,
  out: Argv[],
  seen: Set<string>,
  nested: boolean,
  suffix: boolean
): void {
  if (out.length >= MAX_ARGVS) return;
  if (depth > MAX_DEPTH) {
    unverifiable("command nesting is too deep to check", out);
    return;
  }
  let a = stripPrefix(argv);
  if (a.length === 0) return;
  // zsh expands `=git` to the path of git
  if (a[0].length > 1 && a[0].startsWith("=")) a = [a[0].slice(1), ...a.slice(1)];
  const key = (nested ? "n" : "t") + "\0" + a.join("\0");
  if (seen.has(key)) return;
  seen.add(key);
  out.push(a);
  if (nested && isDynamic(a[0])) {
    unverifiable("a nested shell script runs a command built at runtime", out);
  }
  const name = basename(a[0]);
  if (WRAPPERS.has(name)) {
    for (let i = 1; i < a.length; i++) expand(a.slice(i), depth + 1, out, seen, nested, true);
  } else if (name === "find") {
    for (let i = 1; i < a.length; i++) {
      if (!FIND_EXEC.has(a[i])) continue;
      const stop = a.findIndex((t, k) => k > i && (t === ";" || t === "+"));
      expand(a.slice(i + 1, stop < 0 ? undefined : stop), depth + 1, out, seen, nested, true);
    }
  } else if (SHELLS.has(name) && !(suffix && !looksLikeShellPath(a[0]))) {
    const sh = shellInvocation(a);
    if (sh.kind === "script") {
      if (isDynamic(sh.script)) unverifiable(`${name} -c runs a script built at runtime`, out);
      collect(restore(sh.script), depth + 1, out, seen, true);
    } else if (sh.kind === "stdin") {
      unverifiable(`${name} reads its script from stdin`, out);
    }
  } else if (name === "eval") {
    const script = a.slice(1).join(" ");
    if (isDynamic(script)) unverifiable("eval runs a script built at runtime", out);
    collect(restore(script), depth + 1, out, seen, true);
  } else if (name === "source" || name === ".") {
    if (a.slice(1).some((t) => t.startsWith("<(") || isDynamic(t))) {
      unverifiable(`${name} loads a script that is generated at runtime`, out);
    }
  }
}

function collect(
  src: string,
  depth: number,
  out: Argv[],
  seen: Set<string>,
  nested: boolean
): void {
  if (depth > MAX_DEPTH) {
    unverifiable("command nesting is too deep to check", out);
    return;
  }
  const cmds: Argv[] = [];
  lexScript(src, 0, cmds, false);
  for (const c of cmds) expand(c, depth, out, seen, nested, false);
}

/**
 * Every command invocation (argv) in a shell command string: all simple
 * commands, those inside `$(...)`, backticks, subshells and `sh -c` / `eval`
 * strings, and the command behind env assignments and wrappers like sudo.
 * Code that cannot be read statically (a script built at runtime, one piped
 * into a shell, too-deep nesting) shows up as [UNVERIFIABLE, reason].
 * Never throws for ordinary input; unparseable input degrades to fewer results.
 */
export function invocations(src: string): Argv[] {
  const out: Argv[] = [];
  collect(src, 0, out, new Set(), false);
  return out.map((a) => a.map(restore));
}
