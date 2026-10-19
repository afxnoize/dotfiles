import { describe, expect, test } from "bun:test";
import {
  canonicalize,
  hasServiceCommand,
  matchCommand,
  type Pattern,
} from "./validate-cloud";
import awsPatterns from "./patterns/aws";
import b2Patterns from "./patterns/b2";

const MOCK_AWS_PATTERNS: Pattern[] = [
  { pattern: /aws\s+s3\s+rm\s+.*--recursive/,  decision: "deny", reason: "Recursive S3 deletion is blocked." },
  { pattern: /aws\s+s3\s+rb\s+/,               decision: "deny", reason: "S3 bucket removal is blocked." },
  { pattern: /aws\s+s3api\s+put-bucket-policy/, decision: "ask",  reason: "Modifying bucket policy. Proceed?" },
  { pattern: /aws\s+iam\s+delete-/,             decision: "deny", reason: "Deleting IAM resources is blocked." },
  { pattern: /aws\s+iam\s+create-access-key/,   decision: "deny", reason: "Creating access keys is blocked." },
  { pattern: /aws\s+ec2\s+terminate-instances/,  decision: "deny", reason: "Terminating EC2 instances is blocked." },
];

const MOCK_B2_PATTERNS: Pattern[] = [
  { pattern: /b2\s+rm\s+.*--recursive/,  decision: "deny", reason: "Recursive B2 file deletion is blocked." },
  { pattern: /b2\s+rm\s+.*--versions/,   decision: "deny", reason: "Deleting all file versions is blocked." },
  { pattern: /b2\s+rm\s+/,              decision: "ask",  reason: "Removing B2 files. Proceed?" },
  { pattern: /b2\s+bucket\s+delete/,     decision: "deny", reason: "B2 bucket deletion is blocked." },
  { pattern: /b2\s+bucket\s+update/,     decision: "ask",  reason: "Updating B2 bucket settings. Proceed?" },
  { pattern: /b2\s+key\s+delete/,        decision: "deny", reason: "Deleting B2 application key is blocked." },
  { pattern: /b2\s+sync\s+.*--delete/,   decision: "ask",  reason: "B2 sync with --delete flag. Proceed?" },
];

const mockAws = (cmd: string) => matchCommand(cmd, MOCK_AWS_PATTERNS, "aws");
const mockB2 = (cmd: string) => matchCommand(cmd, MOCK_B2_PATTERNS, "b2");
const aws = (cmd: string) => matchCommand(cmd, awsPatterns, "aws");
const b2 = (cmd: string) => matchCommand(cmd, b2Patterns, "b2");

describe("hasServiceCommand", () => {
  describe("コマンドがサービス名で始まるとき", () => {
    test("マッチする", () => {
      expect(hasServiceCommand("aws s3 ls", "aws")).toBe(true);
      expect(hasServiceCommand("b2 ls", "b2")).toBe(true);
    });
  });

  describe("コマンドが複合コマンドの一部に含まれるとき", () => {
    test("&& の後ろでもマッチする", () => {
      expect(hasServiceCommand("cd /tmp && aws s3 ls", "aws")).toBe(true);
    });

    test("; の後ろでもマッチする", () => {
      expect(hasServiceCommand("echo ok; b2 ls", "b2")).toBe(true);
    });

    test("| の後ろでもマッチする", () => {
      expect(
        hasServiceCommand("cat file | aws s3 cp - s3://bucket", "aws")
      ).toBe(true);
    });

    test("2 行目でもマッチする", () => {
      expect(hasServiceCommand("cd /tmp\naws s3 ls", "aws")).toBe(true);
    });
  });

  describe("ラッパーやサブシェルの内側にあるとき", () => {
    test.each([
      "sudo aws s3 ls",
      "env AWS_PROFILE=prod aws s3 ls",
      "AWS_PROFILE=prod aws s3 ls",
      "/usr/local/bin/aws s3 ls",
      "time aws s3 ls",
      "(aws s3 ls)",
      "echo $(aws s3 ls)",
      "echo `aws s3 ls`",
      'echo "$(aws s3 ls)"',
      "bash -c 'aws s3 ls'",
      'eval "aws s3 ls"',
      "xargs -n1 aws s3 ls",
      "rtk proxy aws s3 ls",
    ])("%s でもマッチする", (cmd) => {
      expect(hasServiceCommand(cmd, "aws")).toBe(true);
    });
  });

  describe("サービス名を含まないコマンドのとき", () => {
    test("マッチしない", () => {
      expect(hasServiceCommand("ls -la", "aws")).toBe(false);
      expect(hasServiceCommand("git status", "b2")).toBe(false);
    });
  });

  describe("サービス名が別の単語の一部であるとき", () => {
    test("部分一致ではマッチしない", () => {
      expect(hasServiceCommand("awsome command", "aws")).toBe(false);
      expect(hasServiceCommand("b2b sales report", "b2")).toBe(false);
    });
  });

  describe("サービス名が引数や文字列の中にあるだけのとき", () => {
    test("コマンドとはみなさない", () => {
      expect(hasServiceCommand("echo aws s3 rb s3://b", "aws")).toBe(false);
      expect(hasServiceCommand('git commit -m "aws s3 rb"', "aws")).toBe(false);
      expect(hasServiceCommand("ls # aws s3 rb", "aws")).toBe(false);
    });
  });
});

describe("canonicalize", () => {
  test("aws のグローバルオプションを取り除く", () => {
    expect(
      canonicalize(
        ["aws", "--profile", "prod", "--region=us-east-1", "s3", "--debug", "rb", "s3://b"],
        "aws"
      )
    ).toEqual(["aws", "s3", "rb", "s3://b"]);
  });

  test("サブコマンド固有のオプションは残す", () => {
    expect(
      canonicalize(["aws", "s3", "rm", "s3://b", "--recursive"], "aws")
    ).toEqual(["aws", "s3", "rm", "s3://b", "--recursive"]);
  });

  test("b2 は先頭のグローバルオプションだけ取り除く", () => {
    expect(
      canonicalize(["b2", "--log-config", "x.ini", "--verbose", "rm", "--recursive", "b2://b"], "b2")
    ).toEqual(["b2", "rm", "--recursive", "b2://b"]);
  });
});

describe("matchCommand", () => {
  describe("破壊的な操作に対して", () => {
    test("aws s3 rm --recursive は deny される", () => {
      expect(mockAws("aws s3 rm s3://bucket --recursive")).toMatchObject({ decision: "deny" });
    });

    test("aws s3 rb は deny される", () => {
      expect(mockAws("aws s3 rb s3://my-bucket")).toMatchObject({ decision: "deny" });
    });

    test("aws iam delete-* は deny される", () => {
      expect(mockAws("aws iam delete-role --role-name test")).toMatchObject({ decision: "deny" });
    });

    test("aws ec2 terminate-instances は deny される", () => {
      expect(
        mockAws("aws ec2 terminate-instances --instance-ids i-1234")
      ).toMatchObject({ decision: "deny" });
    });

    test("b2 rm --recursive は deny される", () => {
      expect(mockB2("b2 rm --recursive b2://my-bucket")).toMatchObject({ decision: "deny" });
    });

    test("b2 rm --versions は deny される", () => {
      expect(mockB2("b2 rm --versions b2://my-bucket")).toMatchObject({ decision: "deny" });
    });

    test("b2 bucket delete は deny される", () => {
      expect(mockB2("b2 bucket delete my-bucket")).toMatchObject({ decision: "deny" });
    });

    test("b2 key delete は deny される", () => {
      expect(mockB2("b2 key delete 0012345")).toMatchObject({ decision: "deny" });
    });
  });

  describe("確認が必要な操作に対して", () => {
    test("aws s3api put-bucket-policy は ask される", () => {
      expect(
        mockAws("aws s3api put-bucket-policy --bucket my-bucket --policy file://p.json")
      ).toMatchObject({ decision: "ask" });
    });

    test("b2 rm (単体) は ask される", () => {
      expect(mockB2("b2 rm b2://my-bucket/file.txt")).toMatchObject({ decision: "ask" });
    });

    test("b2 bucket update は ask される", () => {
      expect(
        mockB2("b2 bucket update --all-private my-bucket")
      ).toMatchObject({ decision: "ask" });
    });

    test("b2 sync --delete は ask される", () => {
      expect(
        mockB2("b2 sync --delete /local b2://my-bucket")
      ).toMatchObject({ decision: "ask" });
    });
  });

  describe("安全な操作に対して", () => {
    test("aws s3 ls は通過する", () => {
      expect(mockAws("aws s3 ls")).toBeNull();
    });

    test("aws ec2 describe-instances は通過する", () => {
      expect(mockAws("aws ec2 describe-instances")).toBeNull();
    });

    test("b2 ls は通過する", () => {
      expect(mockB2("b2 ls")).toBeNull();
    });

    test("b2 file upload は通過する", () => {
      expect(mockB2("b2 file upload my-bucket /tmp/file.txt")).toBeNull();
    });

    test("グローバルオプション付きの読み取り操作は通過する", () => {
      expect(aws("aws --profile prod s3 ls")).toBeNull();
    });
  });

  describe("複合コマンドの中に危険な操作が含まれるとき", () => {
    test("&& の後ろの aws s3 rm --recursive を検出する", () => {
      expect(
        mockAws("cd /project && aws s3 rm s3://bucket --recursive")
      ).toMatchObject({ decision: "deny" });
    });

    test("; の後ろの aws ec2 terminate-instances を検出する", () => {
      expect(
        mockAws("echo start; aws ec2 terminate-instances --instance-ids i-1234")
      ).toMatchObject({ decision: "deny" });
    });

    test("&& の後ろの b2 rm --recursive を検出する", () => {
      expect(
        mockB2("echo start && b2 rm --recursive b2://my-bucket")
      ).toMatchObject({ decision: "deny" });
    });

    test("ask の後ろに deny があれば deny を返す", () => {
      expect(
        b2("b2 rm b2://my-bucket/a && b2 bucket delete my-bucket")
      ).toMatchObject({ decision: "deny" });
    });
  });

  describe("パターンの優先順位について", () => {
    test("b2 rm --recursive --versions は先に定義された recursive でマッチする", () => {
      const result = mockB2("b2 rm --recursive --versions b2://my-bucket");
      expect(result).toMatchObject({
        decision: "deny",
        reason: "Recursive B2 file deletion is blocked.",
      });
    });
  });

  describe("実際のパターン表に対する回避の試み", () => {
    test.each([
      ["グローバルオプションが先頭にある", "aws --profile prod iam delete-user --user-name x"],
      ["--region が先頭にある", "aws --region ap-northeast-1 s3 rb s3://b"],
      ["--region が service の後ろにある", "aws s3 --region us-east-1 rb s3://b"],
      ["--region=value の形", "aws --region=us-east-1 ec2 terminate-instances --instance-ids i-1"],
      ["行継続で分割されている", "aws s3 rm s3://b/ \\\n --recursive"],
      ["2 行目にある", "cd /tmp\naws iam delete-user --user-name bob"],
      ["sudo 経由", "sudo aws iam delete-user --user-name bob"],
      ["環境変数代入付き", "AWS_PROFILE=prod aws iam delete-user --user-name bob"],
      ["env 経由", "env AWS_PROFILE=prod aws iam delete-user --user-name bob"],
      ["絶対パス", "/usr/local/bin/aws s3 rb s3://b"],
      ["サブシェル", "(aws s3 rb s3://b)"],
      ["コマンド置換", "echo $(aws s3 rb s3://b)"],
      ["bash -c", "bash -c 'aws s3 rb s3://b'"],
      ["eval", 'eval "aws s3 rb s3://b"'],
      ["引用符付きの引数", "aws 's3' \"rb\" s3://b"],
    ])("deny: %s", (_name, cmd) => {
      expect(aws(cmd)).toMatchObject({ decision: "deny" });
    });

    test("ask: グローバルオプションが先頭にある ask ルール", () => {
      expect(
        aws("aws --profile prod iam create-user --user-name x")
      ).toMatchObject({ decision: "ask" });
    });

    test("ask: サービスや操作が変数のときは確認する", () => {
      expect(aws('aws "$SVC" "$OP" --x')).toMatchObject({ decision: "ask" });
      expect(aws("aws s3 $OP s3://b")).toMatchObject({ decision: "ask" });
    });

    test("b2: グローバルオプション付きでも検出する", () => {
      expect(b2("b2 --verbose bucket delete my-bucket")).toMatchObject({ decision: "deny" });
      expect(b2("sudo b2 rm --recursive b2://b")).toMatchObject({ decision: "deny" });
    });

    test("コマンドではない文字列では反応しない", () => {
      expect(aws("echo aws s3 rb s3://b")).toBeNull();
      expect(aws('git commit -m "aws s3 rb s3://b"')).toBeNull();
    });
  });
});
