# skill-name = { source = "owner/repo"; path = "optional/sub/path"; }
# path を省略した場合はリポジトリルートから検索
{
  find-skills = {
    source = "vercel-labs/skills";
  };
  claude-md-improver = {
    source = "anthropics/claude-plugins-official";
    path = "plugins/claude-md-management";
  };
}
