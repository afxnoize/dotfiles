import type { Pattern } from "../validate-cloud";

// ── IAM ──
// ── STS ──
// ── S3 ──
// ── EC2 ──
// ── RDS ──
// ── Lambda ──
// ── CloudFormation ──
// ── DynamoDB ──
// ── Secrets Manager / SSM ──
// ── Organizations ──
// ── Route53 ──

const patterns: Pattern[] = [
  // ── IAM ──
  { pattern: /aws\s+iam\s+delete-/,                        decision: "deny", reason: "Deleting IAM resources is blocked." },
  { pattern: /aws\s+iam\s+create-(user|role|group)/,       decision: "ask",  reason: "Creating IAM entities. Proceed?" },
  { pattern: /aws\s+iam\s+attach-.*-policy/,               decision: "ask",  reason: "Attaching IAM policy. Proceed?" },
  { pattern: /aws\s+iam\s+detach-.*-policy/,               decision: "ask",  reason: "Detaching IAM policy. Proceed?" },
  { pattern: /aws\s+iam\s+put-(user|role|group)-policy/,   decision: "ask",  reason: "Modifying inline policy. Proceed?" },
  { pattern: /aws\s+iam\s+update-role/,                    decision: "ask",  reason: "Updating IAM role. Proceed?" },
  { pattern: /aws\s+iam\s+update-assume-role-policy/,      decision: "ask",  reason: "Updating trust policy. Proceed?" },
  { pattern: /aws\s+iam\s+create-access-key/,              decision: "deny", reason: "Creating access keys is blocked." },
  { pattern: /aws\s+iam\s+update-login-profile/,           decision: "deny", reason: "Changing login credentials is blocked." },

  // ── STS ──
  { pattern: /aws\s+sts\s+assume-role/,                    decision: "ask",  reason: "Assuming IAM role. Proceed?" },

  // ── S3 ──
  { pattern: /aws\s+s3\s+rm\s+.*--recursive/,              decision: "deny", reason: "Recursive S3 deletion is blocked." },
  { pattern: /aws\s+s3\s+rb\s+/,                           decision: "deny", reason: "S3 bucket removal is blocked." },
  { pattern: /aws\s+s3api\s+delete-bucket/,                decision: "deny", reason: "S3 bucket deletion is blocked." },
  { pattern: /aws\s+s3api\s+put-bucket-policy/,            decision: "ask",  reason: "Modifying bucket policy. Proceed?" },
  { pattern: /aws\s+s3api\s+put-bucket-acl/,               decision: "ask",  reason: "Modifying bucket ACL. Proceed?" },
  { pattern: /aws\s+s3api\s+put-public-access-block/,      decision: "ask",  reason: "Changing public access settings. Proceed?" },
  { pattern: /aws\s+s3api\s+put-bucket-versioning/,        decision: "ask",  reason: "Changing versioning settings. Proceed?" },
  { pattern: /aws\s+s3api\s+put-bucket-encryption/,        decision: "ask",  reason: "Changing encryption settings. Proceed?" },

  // ── EC2 ──
  { pattern: /aws\s+ec2\s+terminate-instances/,            decision: "deny", reason: "Terminating EC2 instances is blocked." },
  { pattern: /aws\s+ec2\s+delete-(security-group|vpc|subnet)/, decision: "deny", reason: "Deleting network resources is blocked." },
  { pattern: /aws\s+ec2\s+modify-instance-attribute/,      decision: "ask",  reason: "Modifying instance attribute. Proceed?" },
  { pattern: /aws\s+ec2\s+modify-vpc-attribute/,           decision: "ask",  reason: "Modifying VPC attribute. Proceed?" },
  { pattern: /aws\s+ec2\s+modify-subnet-attribute/,        decision: "ask",  reason: "Modifying subnet attribute. Proceed?" },
  { pattern: /aws\s+ec2\s+authorize-security-group/,       decision: "ask",  reason: "Adding security group rule. Proceed?" },
  { pattern: /aws\s+ec2\s+revoke-security-group/,          decision: "ask",  reason: "Removing security group rule. Proceed?" },
  { pattern: /aws\s+ec2\s+create-security-group/,          decision: "ask",  reason: "Creating security group. Proceed?" },

  // ── RDS ──
  { pattern: /aws\s+rds\s+delete-/,                        decision: "deny", reason: "Deleting RDS resources is blocked." },
  { pattern: /aws\s+rds\s+modify-db-/,                     decision: "ask",  reason: "Modifying RDS configuration. Proceed?" },

  // ── Lambda ──
  { pattern: /aws\s+lambda\s+delete-function/,             decision: "deny", reason: "Deleting Lambda function is blocked." },
  { pattern: /aws\s+lambda\s+update-function-configuration/, decision: "ask", reason: "Updating Lambda config. Proceed?" },
  { pattern: /aws\s+lambda\s+add-permission/,              decision: "ask",  reason: "Modifying Lambda resource policy. Proceed?" },
  { pattern: /aws\s+lambda\s+put-function-concurrency/,    decision: "ask",  reason: "Changing Lambda concurrency. Proceed?" },

  // ── CloudFormation ──
  { pattern: /aws\s+cloudformation\s+delete-stack/,        decision: "deny", reason: "Deleting CFn stack is blocked." },
  { pattern: /aws\s+cloudformation\s+create-stack/,        decision: "ask",  reason: "Creating CFn stack. Proceed?" },
  { pattern: /aws\s+cloudformation\s+update-stack/,        decision: "ask",  reason: "Updating CFn stack. Proceed?" },

  // ── DynamoDB ──
  { pattern: /aws\s+dynamodb\s+delete-table/,              decision: "deny", reason: "Deleting DynamoDB table is blocked." },
  { pattern: /aws\s+dynamodb\s+update-table/,              decision: "ask",  reason: "Updating DynamoDB table. Proceed?" },

  // ── Secrets Manager / SSM ──
  { pattern: /aws\s+secretsmanager\s+delete-secret/,       decision: "deny", reason: "Deleting secret is blocked." },
  { pattern: /aws\s+secretsmanager\s+(put-secret-value|update-secret)/, decision: "ask", reason: "Modifying secret. Proceed?" },
  { pattern: /aws\s+ssm\s+delete-parameter/,               decision: "deny", reason: "Deleting SSM parameter is blocked." },
  { pattern: /aws\s+ssm\s+put-parameter/,                  decision: "ask",  reason: "Writing SSM parameter. Proceed?" },

  // ── Organizations ──
  { pattern: /aws\s+organizations\s+(leave|delete)-/,      decision: "deny", reason: "Organizations mutation is blocked." },

  // ── Route53 ──
  { pattern: /aws\s+route53\s+delete-hosted-zone/,         decision: "deny", reason: "Deleting hosted zone is blocked." },
  { pattern: /aws\s+route53\s+change-resource-record-sets/, decision: "ask", reason: "Changing DNS records. Proceed?" },
];

export default patterns;
