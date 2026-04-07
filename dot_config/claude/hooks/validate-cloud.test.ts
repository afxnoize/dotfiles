import { describe, expect, test } from "bun:test";
import {
  hasServiceCommand,
  matchCommand,
  type Pattern,
} from "./validate-cloud";

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
    test("aws s3 rm --recursive は deny される", () => {
      expect(
        matchCommand("aws s3 rm s3://bucket --recursive", MOCK_AWS_PATTERNS)
      ).toMatchObject({ decision: "deny" });
    });

    test("aws s3 rb は deny される", () => {
      expect(
        matchCommand("aws s3 rb s3://my-bucket", MOCK_AWS_PATTERNS)
      ).toMatchObject({ decision: "deny" });
    });

    test("aws iam delete-* は deny される", () => {
      expect(
        matchCommand("aws iam delete-role --role-name test", MOCK_AWS_PATTERNS)
      ).toMatchObject({ decision: "deny" });
    });

    test("aws ec2 terminate-instances は deny される", () => {
      expect(
        matchCommand(
          "aws ec2 terminate-instances --instance-ids i-1234",
          MOCK_AWS_PATTERNS
        )
      ).toMatchObject({ decision: "deny" });
    });

    test("b2 rm --recursive は deny される", () => {
      expect(
        matchCommand("b2 rm --recursive b2://my-bucket", MOCK_B2_PATTERNS)
      ).toMatchObject({ decision: "deny" });
    });

    test("b2 rm --versions は deny される", () => {
      expect(
        matchCommand("b2 rm --versions b2://my-bucket", MOCK_B2_PATTERNS)
      ).toMatchObject({ decision: "deny" });
    });

    test("b2 bucket delete は deny される", () => {
      expect(
        matchCommand("b2 bucket delete my-bucket", MOCK_B2_PATTERNS)
      ).toMatchObject({ decision: "deny" });
    });

    test("b2 key delete は deny される", () => {
      expect(
        matchCommand("b2 key delete 0012345", MOCK_B2_PATTERNS)
      ).toMatchObject({ decision: "deny" });
    });
  });

  describe("確認が必要な操作に対して", () => {
    test("aws s3api put-bucket-policy は ask される", () => {
      expect(
        matchCommand(
          "aws s3api put-bucket-policy --bucket my-bucket --policy file://p.json",
          MOCK_AWS_PATTERNS
        )
      ).toMatchObject({ decision: "ask" });
    });

    test("b2 rm (単体) は ask される", () => {
      expect(
        matchCommand("b2 rm b2://my-bucket/file.txt", MOCK_B2_PATTERNS)
      ).toMatchObject({ decision: "ask" });
    });

    test("b2 bucket update は ask される", () => {
      expect(
        matchCommand("b2 bucket update --all-private my-bucket", MOCK_B2_PATTERNS)
      ).toMatchObject({ decision: "ask" });
    });

    test("b2 sync --delete は ask される", () => {
      expect(
        matchCommand("b2 sync --delete /local b2://my-bucket", MOCK_B2_PATTERNS)
      ).toMatchObject({ decision: "ask" });
    });
  });

  describe("安全な操作に対して", () => {
    test("aws s3 ls は通過する", () => {
      expect(matchCommand("aws s3 ls", MOCK_AWS_PATTERNS)).toBeNull();
    });

    test("aws ec2 describe-instances は通過する", () => {
      expect(
        matchCommand("aws ec2 describe-instances", MOCK_AWS_PATTERNS)
      ).toBeNull();
    });

    test("b2 ls は通過する", () => {
      expect(matchCommand("b2 ls", MOCK_B2_PATTERNS)).toBeNull();
    });

    test("b2 file upload は通過する", () => {
      expect(
        matchCommand("b2 file upload my-bucket /tmp/file.txt", MOCK_B2_PATTERNS)
      ).toBeNull();
    });
  });

  describe("複合コマンドの中に危険な操作が含まれるとき", () => {
    test("&& の後ろの aws s3 rm --recursive を検出する", () => {
      expect(
        matchCommand(
          "cd /project && aws s3 rm s3://bucket --recursive",
          MOCK_AWS_PATTERNS
        )
      ).toMatchObject({ decision: "deny" });
    });

    test("; の後ろの aws ec2 terminate-instances を検出する", () => {
      expect(
        matchCommand(
          "echo start; aws ec2 terminate-instances --instance-ids i-1234",
          MOCK_AWS_PATTERNS
        )
      ).toMatchObject({ decision: "deny" });
    });

    test("&& の後ろの b2 rm --recursive を検出する", () => {
      expect(
        matchCommand(
          "echo start && b2 rm --recursive b2://my-bucket",
          MOCK_B2_PATTERNS
        )
      ).toMatchObject({ decision: "deny" });
    });
  });

  describe("パターンの優先順位について", () => {
    test("b2 rm --recursive --versions は先に定義された recursive でマッチする", () => {
      const result = matchCommand(
        "b2 rm --recursive --versions b2://my-bucket",
        MOCK_B2_PATTERNS
      );
      expect(result).toMatchObject({
        decision: "deny",
        reason: "Recursive B2 file deletion is blocked.",
      });
    });
  });
});
