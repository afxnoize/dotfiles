# Ported from dot_config/zabrze/config.toml. Entries for tools without a Windows
# build (tmux, pueue, nix, awk) and for coreutils flags pwsh lacks are left out.
$eza = 'eza --group-directories-first'

# navigation and listing
@{ Name = 'zoxide'; TriggerPattern = '^cd?$'; Snippet = 'z' }
@{ Name = 'eza'; Trigger = 'l'; Snippet = $eza }
@{ Name = 'eza --git'; Trigger = 'ls'; Snippet = "$eza --git" }
@{ Name = 'eza -a'; Trigger = 'la'; Snippet = "$eza -a" }
@{ Name = 'eza --git -l'; Trigger = 'll'; Snippet = "$eza --git -l" }
@{ Name = 'eza --git -la'; Trigger = 'lla'; Snippet = "$eza --git -la" }
@{ Name = 'eza --tree'; Trigger = 'tree'; Snippet = "$eza --tree" }
@{ Name = 'eza sort newest first'; Trigger = ':n'; Snippet = '-s modified -r'; Global = $true; Context = '^eza\s+' }
@{ Name = 'eza sort largest first'; Trigger = ':s'; Snippet = '-s size -r'; Global = $true; Context = '^eza\s+' }

# shell
@{ Name = 'Remove-Item -Recurse -Force'; Trigger = 'rmf'; Snippet = 'Remove-Item -Recurse -Force' }
@{ Name = 'curl --compressed'; Trigger = 'curl'; Snippet = 'curl --compressed' }
@{ Name = 'discard all output'; Trigger = 'null'; Snippet = '*> $null'; Global = $true }
@{ Name = '$env:XDG_CONFIG_HOME'; Trigger = 'x-co'; Snippet = '$env:XDG_CONFIG_HOME{}'; Cursor = '{}'; Global = $true }
@{ Name = 'yyyymmdd date expansion'; TriggerPattern = '^yyyy(?<sep1>.?)mm(?<sep2>.?)dd(?<diff>[+-]\d+)?$'; Global = $true
  Evaluate = {
    param($m)
    $d = (Get-Date).AddDays([int]($m.diff ?? 0))
    '{0:yyyy}{1}{0:MM}{2}{0:dd}' -f $d, $m.sep1, $m.sep2
  } }

# tools
@{ Name = 'just'; Trigger = 'j'; Snippet = 'just' }
@{ Name = 'nvim'; Trigger = 'ni'; Snippet = 'nvim' }
@{ Name = 'nvim .'; Trigger = 'nid'; Snippet = 'nvim .' }
@{ Name = 'uv run python *.py'; TriggerPattern = '^(?<file>.+\.py)$'; If = { [bool](Get-Command uv -ErrorAction Ignore) }
  Evaluate = { param($m) "uv run python $($m.file)" } }

# docker
@{ Name = 'docker'; Trigger = 'd'; Snippet = 'docker' }
@{ Name = 'docker compose'; Trigger = 'dc'; Snippet = 'docker compose' }
@{ Name = 'docker compose (subcommand)'; TriggerPattern = '^co?$'; Snippet = 'compose'; Global = $true; Context = '^docker\s+' }
