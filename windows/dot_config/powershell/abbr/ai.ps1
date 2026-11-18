# Ported from dot_config/zabrze/ai.toml. cage and happy have no Windows build.
$hasBunx = { [bool](Get-Command bunx -ErrorAction Ignore) }
$hasUvx = { [bool](Get-Command uvx -ErrorAction Ignore) }

@{ Name = 'cc-sdd (system design doc)'; TriggerPattern = '^(?:cc)?-?sdd$'; Snippet = 'bunx cc-sdd@latest --lang ja'; If = $hasBunx }
@{ Name = 'difit'; Trigger = 'difit'; Snippet = 'bunx difit'; If = $hasBunx }
@{ Name = 'skills add'; Trigger = 'skills'; Snippet = 'bunx skills add'; If = $hasBunx }
@{ Name = 'specify init'; Trigger = 'specify'; Snippet = 'uvx --from git+https://github.com/github/spec-kit.git specify init'; If = $hasUvx }
@{ Name = 'mcp add serena'; Trigger = 'mcp-add-serena'; If = $hasUvx
  Snippet = 'claude mcp add serena -- uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context claude-code --mode planning --mode no-onboarding --project-from-cwd' }

@{ Name = 'ai commit message'; Trigger = 'aicm'
  Snippet = @'
git commit -e -m "$(git diff --staged | claude -p 'Write a comprehensive conventional commit message for this diff. Output only the message, no markdown or backticks:')"
'@ }
@{ Name = 'claude channels (telegram)'; Trigger = 'ch'; Snippet = '--channels plugin:telegram@claude-plugins-official'; Global = $true; Context = '^claude(?:\s+-\S+)*\s+\S+$' }
