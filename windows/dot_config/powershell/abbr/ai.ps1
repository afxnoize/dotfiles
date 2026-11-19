# Ported from dot_config/zabrze/ai.toml. cage and happy have no Windows build.
$hasBunx = { [bool](Get-Command bunx -ErrorAction Ignore) }

@{ Name = 'skills add'; Trigger = 'skills'; Snippet = 'bunx skills add'; If = $hasBunx }

@{ Name = 'ai commit message'; Trigger = 'aicm'
  Snippet = @'
git commit -e -m "$(git diff --staged | claude -p 'Write a comprehensive conventional commit message for this diff. Output only the message, no markdown or backticks:')"
'@ }
@{ Name = 'claude channels (telegram)'; Trigger = 'ch'; Snippet = '--channels plugin:telegram@claude-plugins-official'; Global = $true; Context = '^claude(?:\s+-\S+)*\s+\S+$' }
