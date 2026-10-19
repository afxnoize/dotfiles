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
const MAX_ARGVS = 2000;

// Commands that run their arguments as another command. Every suffix of such a
// command is also treated as a command start, so option values that belong to
// the wrapper (`sudo -u bob git push`) do not need per-wrapper parsing.
const WRAPPERS = new Set([
  "sudo", "doas", "env", "command", "builtin", "exec", "time", "nohup", "nice",
  "ionice", "timeout", "stdbuf", "setsid", "xargs", "watch", "chrt", "taskset",
  "flock", "unbuffer", "rtk", "cage", "direnv", "mise",
]);
const SHELLS = new Set(["sh", "bash", "zsh", "dash", "ksh", "fish"]);
const KEYWORDS = new Set([
  "!", "{", "}", "if", "then", "else", "elif", "fi", "do", "done", "while", "until",
  "coproc", "function",
]);
const ENV_ASSIGN = /^[A-Za-z_][A-Za-z0-9_]*(\[[^\]]*\])?\+?=/;

export function basename(path: string): string {
  const i = path.lastIndexOf("/");
  return i < 0 ? path : path.slice(i + 1);
}

/**
 * True when a token still holds something the shell would expand into other
 * text: `$...`, a backtick, or a brace list/range (`{a,b}`, `{1..3}`).
 */
export function isDynamic(token: string): boolean {
  return /[$`]|\{[^}]*(,|\.\.)[^}]*\}/.test(token);
}

// Decodes the escapes of a $'...' string so `$'\x6dain'` is seen as `main`.
function decodeAnsiC(body: string): string {
  const simple: Record<string, string> = {
    n: "\n", t: "\t", r: "\r", a: "\x07", b: "\b", e: "\x1b", E: "\x1b",
    f: "\f", v: "\v", "\\": "\\", "'": "'", '"': '"', "?": "?",
  };
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
      if (n !== "\n") append('$`"\\'.includes(n) ? n : "\\" + n);
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
      if ((h.strip ? line.replace(/^\t+/, "") : line) === h.delim) break;
      body += line + "\n";
    }
    if (h.expand) lexExpansions(body, out);
  }
  pending.length = 0;
  return i;
}

// Lexes src from `start`, pushing each simple command's words to `out`.
// Returns the index after the closing `)` when closeOnParen, else src.length.
function lexScript(src: string, start: number, out: Argv[], closeOnParen: boolean): number {
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
        word += n;
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
      word += src.slice(i + 1, end);
      inWord = true;
      i = end + 1;
      continue;
    }
    if (c === "$" && n === "'") {
      let j = i + 2;
      while (j < src.length && src[j] !== "'") j += src[j] === "\\" ? 2 : 1;
      word += decodeAnsiC(src.slice(i + 2, j));
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
      // A bare number before the operator is a file descriptor, not an argument.
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
  while (k < argv.length && (KEYWORDS.has(argv[k]) || ENV_ASSIGN.test(argv[k]))) k++;
  return argv.slice(k);
}

function shellScript(argv: Argv): string | null {
  for (let i = 1; i < argv.length; i++) {
    const t = argv[i];
    if (/^-[A-Za-z]*c[A-Za-z]*$/.test(t)) return argv[i + 1] ?? null;
    if (t === "-o" || t === "-O" || t === "+o" || t === "+O") {
      i++;
      continue;
    }
    if (!t.startsWith("-") && !t.startsWith("+")) return null;
  }
  return null;
}

function expand(argv: Argv, depth: number, out: Argv[], seen: Set<string>): void {
  if (depth > MAX_DEPTH || out.length >= MAX_ARGVS) return;
  const a = stripPrefix(argv);
  if (a.length === 0) return;
  const key = a.join("\0");
  if (seen.has(key)) return;
  seen.add(key);
  out.push(a);
  const name = basename(a[0]);
  if (WRAPPERS.has(name)) {
    for (let i = 1; i < a.length; i++) expand(a.slice(i), depth + 1, out, seen);
  } else if (SHELLS.has(name)) {
    const script = shellScript(a);
    if (script !== null) collect(script, depth + 1, out, seen);
  } else if (name === "eval") {
    collect(a.slice(1).join(" "), depth + 1, out, seen);
  }
}

function collect(src: string, depth: number, out: Argv[], seen: Set<string>): void {
  if (depth > MAX_DEPTH) return;
  const cmds: Argv[] = [];
  lexScript(src, 0, cmds, false);
  for (const c of cmds) expand(c, depth, out, seen);
}

/**
 * Every command invocation (argv) in a shell command string: all simple
 * commands, those inside `$(...)`, backticks, subshells and `sh -c` / `eval`
 * strings, and the command behind env assignments and wrappers like sudo.
 * Never throws; unparseable input degrades to fewer results.
 */
export function invocations(src: string): Argv[] {
  const out: Argv[] = [];
  collect(src, 0, out, new Set());
  return out;
}
