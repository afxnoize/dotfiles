import { describe, expect, test } from "bun:test";
import {
  hasServiceCommand,
  matchCommand,
  parsePatterns,
} from "./validate-cloud";

const MOCK_AWS_PATTERNS = `
# AWS CLI test patterns
# Format: <regex> | <decision> | <reason>

aws\\s+s3\\s+rm\\s+.*--recursive   | deny | Recursive S3 deletion is blocked.
aws\\s+s3\\s+rb\\s+                | deny | S3 bucket removal is blocked.
aws\\s+s3api\\s+put-bucket-policy  | ask  | Modifying bucket policy. Proceed?
aws\\s+iam\\s+delete-              | deny | Deleting IAM resources is blocked.
aws\\s+iam\\s+create-access-key   | deny | Creating access keys is blocked.
aws\\s+ec2\\s+terminate-instances  | deny | Terminating EC2 instances is blocked.
`;

const MOCK_B2_PATTERNS = `
# B2 CLI test patterns
b2\\s+rm\\s+.*--recursive          | deny | Recursive B2 file deletion is blocked.
b2\\s+rm\\s+.*--versions           | deny | Deleting all file versions is blocked.
b2\\s+rm\\s+                       | ask  | Removing B2 files. Proceed?
b2\\s+bucket\\s+delete             | deny | B2 bucket deletion is blocked.
b2\\s+bucket\\s+update             | ask  | Updating B2 bucket settings. Proceed?
b2\\s+key\\s+delete                | deny | Deleting B2 application key is blocked.
b2\\s+sync\\s+.*--delete           | ask  | B2 sync with --delete flag. Proceed?
`;

describe("parsePatterns", () => {
  describe("有効なパターン定義を受け取ったとき", () => {
    test("regex, decision, reason の3つ組に分解される", () => {
      const patterns = parsePatterns(MOCK_AWS_PATTERNS);
      expect(patterns[0]).toMatchObject({
        decision: "deny",
        reason: "Recursive S3 deletion is blocked.",
      });
      expect(patterns[0].regex).toBeInstanceOf(RegExp);
    });

    test("定義された数だけパターンが生成される", () => {
      expect(parsePatterns(MOCK_AWS_PATTERNS)).toHaveLength(6);
      expect(parsePatterns(MOCK_B2_PATTERNS)).toHaveLength(7);
    });
  });

  describe("無視すべき行が含まれるとき", () => {
    test("コメント行はスキップされる", () => {
      const patterns = parsePatterns("# this is a comment");
      expect(patterns).toHaveLength(0);
    });

    test("空行はスキップされる", () => {
      const patterns = parsePatterns("\n\n\n");
      expect(patterns).toHaveLength(0);
    });

    test("パイプ区切りが不足する行はスキップされる", () => {
      const patterns = parsePatterns("no pipe here\nonly|two");
      expect(patterns).toHaveLength(0);
    });
  });

  describe("空文字列を受け取ったとき", () => {
    test("空配列を返す", () => {
      expect(parsePatterns("")).toEqual([]);
    });
  });
});

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
});

describe("matchCommand", () => {
  describe("破壊的な操作に対して", () => {
    const awsPatterns = parsePatterns(MOCK_AWS_PATTERNS);
    const b2Patterns = parsePatterns(MOCK_B2_PATTERNS);

    test("aws s3 rm --recursive は deny される", () => {
      expect(
        matchCommand("aws s3 rm s3://bucket --recursive", awsPatterns)
      ).toMatchObject({ decision: "deny" });
    });

    test("aws s3 rb は deny される", () => {
      expect(
        matchCommand("aws s3 rb s3://my-bucket", awsPatterns)
      ).toMatchObject({ decision: "deny" });
    });

    test("aws iam delete-* は deny される", () => {
      expect(
        matchCommand("aws iam delete-role --role-name test", awsPatterns)
      ).toMatchObject({ decision: "deny" });
    });

    test("aws ec2 terminate-instances は deny される", () => {
      expect(
        matchCommand(
          "aws ec2 terminate-instances --instance-ids i-1234",
          awsPatterns
        )
      ).toMatchObject({ decision: "deny" });
    });

    test("b2 rm --recursive は deny される", () => {
      expect(
        matchCommand("b2 rm --recursive b2://my-bucket", b2Patterns)
      ).toMatchObject({ decision: "deny" });
    });

    test("b2 rm --versions は deny される", () => {
      expect(
        matchCommand("b2 rm --versions b2://my-bucket", b2Patterns)
      ).toMatchObject({ decision: "deny" });
    });

    test("b2 bucket delete は deny される", () => {
      expect(
        matchCommand("b2 bucket delete my-bucket", b2Patterns)
      ).toMatchObject({ decision: "deny" });
    });

    test("b2 key delete は deny される", () => {
      expect(
        matchCommand("b2 key delete 0012345", b2Patterns)
      ).toMatchObject({ decision: "deny" });
    });
  });

  describe("確認が必要な操作に対して", () => {
    const awsPatterns = parsePatterns(MOCK_AWS_PATTERNS);
    const b2Patterns = parsePatterns(MOCK_B2_PATTERNS);

    test("aws s3api put-bucket-policy は ask される", () => {
      expect(
        matchCommand(
          "aws s3api put-bucket-policy --bucket my-bucket --policy file://p.json",
          awsPatterns
        )
      ).toMatchObject({ decision: "ask" });
    });

    test("b2 rm (単体) は ask される", () => {
      expect(
        matchCommand("b2 rm b2://my-bucket/file.txt", b2Patterns)
      ).toMatchObject({ decision: "ask" });
    });

    test("b2 bucket update は ask される", () => {
      expect(
        matchCommand("b2 bucket update --all-private my-bucket", b2Patterns)
      ).toMatchObject({ decision: "ask" });
    });

    test("b2 sync --delete は ask される", () => {
      expect(
        matchCommand("b2 sync --delete /local b2://my-bucket", b2Patterns)
      ).toMatchObject({ decision: "ask" });
    });
  });

  describe("安全な操作に対して", () => {
    const awsPatterns = parsePatterns(MOCK_AWS_PATTERNS);
    const b2Patterns = parsePatterns(MOCK_B2_PATTERNS);

    test("aws s3 ls は通過する", () => {
      expect(matchCommand("aws s3 ls", awsPatterns)).toBeNull();
    });

    test("aws ec2 describe-instances は通過する", () => {
      expect(
        matchCommand("aws ec2 describe-instances", awsPatterns)
      ).toBeNull();
    });

    test("b2 ls は通過する", () => {
      expect(matchCommand("b2 ls", b2Patterns)).toBeNull();
    });

    test("b2 file upload は通過する", () => {
      expect(
        matchCommand("b2 file upload my-bucket /tmp/file.txt", b2Patterns)
      ).toBeNull();
    });
  });

  describe("複合コマンドの中に危険な操作が含まれるとき", () => {
    const awsPatterns = parsePatterns(MOCK_AWS_PATTERNS);
    const b2Patterns = parsePatterns(MOCK_B2_PATTERNS);

    test("&& の後ろの aws s3 rm --recursive を検出する", () => {
      expect(
        matchCommand(
          "cd /project && aws s3 rm s3://bucket --recursive",
          awsPatterns
        )
      ).toMatchObject({ decision: "deny" });
    });

    test("; の後ろの aws ec2 terminate-instances を検出する", () => {
      expect(
        matchCommand(
          "echo start; aws ec2 terminate-instances --instance-ids i-1234",
          awsPatterns
        )
      ).toMatchObject({ decision: "deny" });
    });

    test("&& の後ろの b2 rm --recursive を検出する", () => {
      expect(
        matchCommand(
          "echo start && b2 rm --recursive b2://my-bucket",
          b2Patterns
        )
      ).toMatchObject({ decision: "deny" });
    });
  });

  describe("パターンの優先順位について", () => {
    const b2Patterns = parsePatterns(MOCK_B2_PATTERNS);

    test("b2 rm --recursive --versions は先に定義された recursive でマッチする", () => {
      const result = matchCommand(
        "b2 rm --recursive --versions b2://my-bucket",
        b2Patterns
      );
      expect(result).toMatchObject({
        decision: "deny",
        reason: "Recursive B2 file deletion is blocked.",
      });
    });
  });
});
