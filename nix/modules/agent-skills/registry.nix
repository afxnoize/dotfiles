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
  just-pro = {
    source = "rbergman/dark-matter-marketplace";
    path = "plugins/language-pro/skills/just-pro";
  };
  justfile-style = {
    source = "julianobarbosa/claude-code-skills";
    path = "skills/justfile-style";
  };
  justfile-expert = {
    source = "laurigates/claude-plugins";
    path = "tools-plugin/skills/justfile-expert";
  };
}
