import { describe, expect, test } from "bun:test";
import { basename, invocations, isDynamic, UNVERIFIABLE } from "./shell-parse";

// argv lists of the commands whose name is `name`
const argvs = (cmd: string, name: string) =>
  invocations(cmd).filter((a) => basename(a[0]) === name);

describe("invocations: 区切りと引用", () => {
  test("; && || | & 改行で単純コマンドに分ける", () => {
    const cmds = invocations("a 1; b 2 && c 3 || d 4 | e 5 & f 6\ng 7").map((a) => a[0]);
    expect(cmds).toEqual(["a", "b", "c", "d", "e", "f", "g"]);
  });

  test("引用符とエスケープを外した語にする", () => {
    expect(argvs(`git "push" 'origin' ma\\in`, "git")).toEqual([["git", "push", "origin", "main"]]);
  });

  test("引用符内の区切り文字では分けない", () => {
    expect(invocations(`echo "a; git push" 'b && git push'`)).toEqual([
      ["echo", "a; git push", "b && git push"],
    ]);
  });

  test("行継続は語を分けない", () => {
    expect(argvs("git push \\\n origin main", "git")).toEqual([["git", "push", "origin", "main"]]);
  });

  test("コメントは無視する", () => {
    expect(invocations("git status # git push origin main")).toEqual([["git", "status"]]);
  });

  test("語の途中の # はコメントではない", () => {
    expect(invocations("echo a#b")).toEqual([["echo", "a#b"]]);
  });

  test("$'...' のエスケープを復号する", () => {
    expect(invocations("echo $'\\x6dain' $'a\\tb' $'\\160ush'")).toEqual([
      ["echo", "main", "a\tb", "push"],
    ]);
  });

  test("閉じていない引用符でも例外を投げない", () => {
    expect(() => invocations(`git commit -m "unterminated`)).not.toThrow();
    expect(() => invocations("echo 'unterminated")).not.toThrow();
    expect(() => invocations("echo $(unterminated")).not.toThrow();
  });
});

describe("invocations: リダイレクト", () => {
  test("fd 指定と宛先は引数に含めない", () => {
    expect(invocations("git push 2>&1")).toEqual([["git", "push"]]);
    expect(invocations("git push >out.txt 2>>err.txt")).toEqual([["git", "push"]]);
    expect(invocations("git push &>/dev/null")).toEqual([["git", "push"]]);
    expect(invocations("cat < in.txt")).toEqual([["cat"]]);
  });

  test("ヒアストリングは引数ではない", () => {
    expect(invocations("cat <<< 'git push origin main'")).toEqual([["cat"]]);
  });
});

describe("invocations: ヒアドキュメント", () => {
  test("引用付き区切りの本文はコマンドとして扱わない", () => {
    const cmd = "cat <<'EOF'\ngit push origin main\n$(git push origin main)\nEOF\ngit status";
    expect(invocations(cmd)).toEqual([["cat"], ["git", "status"]]);
  });

  test("引用なし区切りの本文でもコマンド置換は実行される", () => {
    const cmd = "cat <<EOF\n$(aws s3 rb x)\nEOF";
    expect(argvs(cmd, "aws")).toEqual([["aws", "s3", "rb", "x"]]);
  });

  test("<<- はタブ付きの終端行を認める", () => {
    const cmd = "cat <<-EOF\n\tbody\n\tEOF\ngit status";
    expect(invocations(cmd)).toEqual([["cat"], ["git", "status"]]);
  });

  test("コミットメッセージ用の $(cat <<EOF) 内の括弧に惑わされない", () => {
    const cmd = `git commit -m "$(cat <<'EOF'\nfix (wip\n\ngit push origin main\nEOF\n)" && git push origin feat/x`;
    expect(argvs(cmd, "git").map((a) => a[1])).toEqual(["commit", "push"]);
    expect(argvs(cmd, "git")[1]).toEqual(["git", "push", "origin", "feat/x"]);
  });
});

describe("invocations: 入れ子とラッパー", () => {
  test("$()、バッククォート、サブシェル、プロセス置換の中を見る", () => {
    for (const cmd of [
      "echo $(aws s3 rb x)",
      'echo "$(aws s3 rb x)"',
      "echo `aws s3 rb x`",
      'echo "`aws s3 rb x`"',
      "(aws s3 rb x)",
      "diff <(aws s3 rb x) /dev/null",
      "x=$(aws s3 rb x)",
    ]) {
      expect(argvs(cmd, "aws"), cmd).toEqual([["aws", "s3", "rb", "x"]]);
    }
  });

  test("環境変数代入と制御構文のキーワードを読み飛ばす", () => {
    expect(argvs("A=1 B=2 git push", "git")).toEqual([["git", "push"]]);
    expect(argvs("if true; then git push origin x; fi", "git")).toEqual([["git", "push", "origin", "x"]]);
    expect(argvs("{ git push origin x; }", "git")).toEqual([["git", "push", "origin", "x"]]);
    expect(argvs("! git push origin x", "git")).toEqual([["git", "push", "origin", "x"]]);
  });

  test("ラッパーの後ろのコマンドも返す", () => {
    for (const cmd of [
      "sudo -u bob git push",
      "env FOO=1 git push",
      "command git push",
      "time git push",
      "timeout 10 git push",
      "nohup git push",
      "xargs git push",
      "rtk proxy git push",
      "cage git push",
    ]) {
      expect(argvs(cmd, "git"), cmd).toContainEqual(["git", "push"]);
    }
  });

  test("sh -c と eval の文字列を再帰的に見る", () => {
    for (const cmd of [
      "bash -c 'git push'",
      "sh -lc 'git push'",
      "sudo bash -c 'git push'",
      "bash -o pipefail -c 'git push'",
      "eval git push",
      `eval "git push"`,
      `bash -c "bash -c 'git push'"`,
    ]) {
      expect(argvs(cmd, "git"), cmd).toContainEqual(["git", "push"]);
    }
  });

  test("引数の中にあるだけのコマンド名はコマンドとはみなさない", () => {
    expect(argvs("echo git push", "git")).toEqual([]);
    expect(argvs("grep -r 'git push' .", "git")).toEqual([]);
  });

  test("深い入れ子や長いラッパー列でも有限時間で終わる", () => {
    const wrappers = Array(40).fill("sudo").join(" ");
    expect(argvs(`${wrappers} git push`, "git").length).toBeGreaterThan(0);
    const nested = "bash -c '".repeat(12) + "git push" + "'".repeat(12);
    expect(() => invocations(nested)).not.toThrow();
  });
});

describe("invocations: zsh 構文と検査できない実行", () => {
  test("=cmd と noglob / nocorrect / repeat の後ろのコマンドを返す", () => {
    for (const cmd of ["=git push", "noglob git push", "nocorrect git push", "repeat 2 git push"]) {
      expect(argvs(cmd, "git"), cmd).toContainEqual(["git", "push"]);
    }
  });

  test("function 定義の本体を見る", () => {
    expect(argvs("function f { git push; }; f", "git")).toEqual([["git", "push"]]);
    expect(argvs("f() { git push; }; f", "git")).toEqual([["git", "push"]]);
  });

  test("算術コマンドの << をヒアドキュメントと誤認しない", () => {
    expect(argvs("(( x = 1 << 2 ))\ngit push origin main", "git")).toEqual([
      ["git", "push", "origin", "main"],
    ]);
    expect(argvs("(( x = $(git push) ))", "git")).toEqual([["git", "push"]]);
  });

  test.each([
    ['X=1; eval "$X"', "eval"],
    ['bash -c "$X"', "bash"],
    ["echo x | sh", "sh"],
    ["sh <<'EOF'\ngit push\nEOF", "sh"],
    ["source <(echo x)", "source"],
  ])("%s は検査できない実行として UNVERIFIABLE を返す", (cmd) => {
    expect(invocations(cmd).some((a) => a[0] === UNVERIFIABLE)).toBe(true);
  });

  test("リテラルの eval / bash -c / スクリプトファイルは UNVERIFIABLE にしない", () => {
    for (const cmd of ['eval "git push"', "bash -c 'git push'", "bash ./run.sh", "source ./env.sh"]) {
      expect(invocations(cmd).some((a) => a[0] === UNVERIFIABLE), cmd).toBe(false);
    }
  });

  test("単引用符・バックスラッシュ・$'...' の中の $ はリテラルなので UNVERIFIABLE にしない", () => {
    for (const cmd of [
      "bash -c 'echo $HOME'",
      "sh -c 'for f in a b; do echo \"$f\"; done'",
      "zsh -c 'S=$PWD; echo $S'",
      "eval 'echo $X'",
      "sh -c 'echo {a,b}'",
      "sh -c \"echo \\$HOME\"",
      "sh -c $'echo $HOME'",
      "xargs -I{} sh -c 'echo \"$1\"' _ {}",
    ]) {
      expect(invocations(cmd).some((a) => a[0] === UNVERIFIABLE), cmd).toBe(false);
    }
  });

  test("リテラルの $ は返す argv では元の $ に戻る", () => {
    expect(argvs("echo 'a$b' \\$c $'$d'", "echo")).toEqual([["echo", "a$b", "$c", "$d"]]);
    expect(argvs("sh -c 'echo $HOME'", "echo")).toEqual([["echo", "$HOME"]]);
    expect(argvs("echo '{a,b}'", "echo")).toEqual([["echo", "{a,b}"]]);
  });

  test("二重引用符や引用なしの $ は外側のシェルが展開するので UNVERIFIABLE のまま", () => {
    for (const cmd of ['B=main; bash -c "git push origin $B"', "bash -c git\\ push\\ $B", "eval echo $X"]) {
      expect(invocations(cmd).some((a) => a[0] === UNVERIFIABLE), cmd).toBe(true);
    }
  });

  test("入れ子のスクリプトで実行時に決まるコマンド名は UNVERIFIABLE になる", () => {
    for (const cmd of [
      `sh -c '"$@"' _ git push origin main`,
      "sh -c '$0 push origin main' git",
      `sh -c 'exec "$@"' _ git push origin main`,
      `sh -c 'sudo "$@"' _ git push origin main`,
      `bash -c 'cmd=$1; shift; "$cmd" "$@"' _ git push origin main`,
      "sh -c 'x=git; $x push origin main'",
      "sh -c '$(echo git) push origin main'",
      `bash -c 'eval "$1"' _ 'git push origin main'`,
      `sh -c 'bash -c "$1"' _ 'git push origin main'`,
      "sh -c '{git,x} push'",
      `eval '"$@"'`,
    ]) {
      expect(invocations(cmd).some((a) => a[0] === UNVERIFIABLE), cmd).toBe(true);
    }
  });

  test("トップレベルで同じ argv を先に見ていても、入れ子の側は見逃さない", () => {
    const r = invocations(`"$@"; sh -c '"$@"' _ git push origin main`);
    expect(r.some((a) => a[0] === UNVERIFIABLE)).toBe(true);
  });

  test("find -exec / -execdir の後ろもコマンドとして返す", () => {
    expect(argvs("find . -name x -exec git push origin main \\;", "git")).toEqual([
      ["git", "push", "origin", "main"],
    ]);
    expect(argvs("find . -execdir git push origin main +", "git")).toEqual([
      ["git", "push", "origin", "main"],
    ]);
    expect(argvs("find . -exec sh -c 'git push origin main' _ {} \\;", "git")).toEqual([
      ["git", "push", "origin", "main"],
    ]);
    // -name zsh is an argument of find, not a shell
    expect(invocations("find . -type d -name zsh").some((a) => a[0] === UNVERIFIABLE)).toBe(false);
  });

  test("ラッパーの引数にあるシェル名で終わるパスは、標準入力を読むシェルとは見なさない", () => {
    for (const cmd of [
      "rtk proxy grep -rn foo dot_config/zsh",
      "rtk grep -rn foo ~/.config/zsh",
      "rtk ls /home/u/.config/zsh",
      "env ls ./tools/bash",
    ]) {
      expect(invocations(cmd).some((a) => a[0] === UNVERIFIABLE), cmd).toBe(false);
    }
    for (const cmd of [
      "echo x | sudo sh",
      "echo x | sudo /bin/sh",
      "echo x | sudo -u root /usr/bin/bash",
      "echo x | sudo /nix/store/abc-bash-5.2/bin/bash",
      "echo x | rtk proxy bash",
    ]) {
      expect(invocations(cmd).some((a) => a[0] === UNVERIFIABLE), cmd).toBe(true);
    }
  });

  test("深すぎる入れ子は例外ではなく UNVERIFIABLE になる", () => {
    const deep = "$(".repeat(5000) + "git push" + ")".repeat(5000);
    let result: string[][] = [];
    expect(() => (result = invocations(`echo ${deep}`))).not.toThrow();
    expect(result.some((a) => a[0] === UNVERIFIABLE)).toBe(true);
    const evals = 'eval "'.repeat(12) + "git push" + '"'.repeat(12);
    expect(invocations(evals).some((a) => a[0] === UNVERIFIABLE)).toBe(true);
  });
});

describe("isDynamic / basename", () => {
  test("変数・置換を含む語を判定する", () => {
    expect(isDynamic("$BRANCH")).toBe(true);
    expect(isDynamic("$(git branch)")).toBe(true);
    expect(isDynamic("`x`")).toBe(true);
    expect(isDynamic("{main,dev}")).toBe(true);
    expect(isDynamic("{1..3}")).toBe(true);
    expect(isDynamic("main")).toBe(false);
    expect(isDynamic("{single}")).toBe(false);
  });

  test("basename はパス区切りの最後を返す", () => {
    expect(basename("/usr/bin/git")).toBe("git");
    expect(basename("git")).toBe("git");
  });
});
