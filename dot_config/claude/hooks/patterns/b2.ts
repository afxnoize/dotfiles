import type { Pattern } from "../validate-cloud";

const patterns: Pattern[] = [
  // ── rm (delete files) ──
  { pattern: /b2\s+rm\s+.*--recursive/,            decision: "deny", reason: "Recursive B2 file deletion is blocked." },
  { pattern: /b2\s+rm\s+.*--versions/,             decision: "deny", reason: "Deleting all file versions is blocked." },
  { pattern: /b2\s+rm\s+/,                         decision: "ask",  reason: "Removing B2 files. Proceed?" },

  // ── bucket ──
  { pattern: /b2\s+bucket\s+delete/,                decision: "deny", reason: "B2 bucket deletion is blocked." },
  { pattern: /b2\s+bucket\s+update/,                decision: "ask",  reason: "Updating B2 bucket settings. Proceed?" },
  { pattern: /b2\s+bucket\s+create/,                decision: "ask",  reason: "Creating B2 bucket. Proceed?" },

  // ── key (credentials) ──
  { pattern: /b2\s+key\s+delete/,                   decision: "deny", reason: "Deleting B2 application key is blocked." },
  { pattern: /b2\s+key\s+create/,                   decision: "deny", reason: "Creating B2 application key is blocked." },

  // ── account ──
  { pattern: /b2\s+account\s+authorize/,            decision: "ask",  reason: "Changing B2 authorization. Proceed?" },

  // ── sync (destructive flags) ──
  { pattern: /b2\s+sync\s+.*--delete/,              decision: "ask",  reason: "B2 sync with --delete flag. Proceed?" },
  { pattern: /b2\s+sync\s+.*--replace-newer/,       decision: "ask",  reason: "B2 sync replacing newer files. Proceed?" },

  // ── large file management ──
  { pattern: /b2\s+file\s+large\s+unfinished\s+cancel/, decision: "ask", reason: "Cancelling unfinished large files. Proceed?" },

  // ── replication ──
  { pattern: /b2\s+replication\s+delete/,           decision: "ask",  reason: "Deleting replication rule. Proceed?" },

  // ── legacy commands (still functional) ──
  { pattern: /b2\s+delete-bucket/,                  decision: "deny", reason: "B2 bucket deletion is blocked." },
  { pattern: /b2\s+delete-file-version/,            decision: "ask",  reason: "Deleting B2 file version. Proceed?" },
  { pattern: /b2\s+cancel-all-unfinished-large-files/, decision: "ask", reason: "Cancelling all unfinished large files. Proceed?" },
];

export default patterns;
