# Run: pwsh -NoProfile -File windows/tests/abbr.tests.ps1
$ErrorActionPreference = 'Stop'
$root = Join-Path $PSScriptRoot '..\dot_config\powershell'
. (Join-Path $root 'abbr.ps1')
$rules = @(Import-AbbrRule (Join-Path $root 'abbr'))
$failures = 0

function Assert-Expand([string] $Line, [string] $Expected, [int] $Cursor = $Line.Length, [int] $ExpectedCursor = -1) {
  $r = Expand-AbbrLine -Line $Line -Cursor $Cursor -Rules $rules
  $actual = $r ? $r.Line : $null
  $ok = "$actual" -ceq $Expected -and ($ExpectedCursor -lt 0 -or $r.Cursor -eq $ExpectedCursor)
  if (-not $ok) {
    $script:failures++
    Write-Host "FAIL '$Line' -> '$actual' (cursor $($r.Cursor)), expected '$Expected' (cursor $ExpectedCursor)"
  }
}

function Assert-Throws([hashtable] $Definition, [string] $Because) {
  try { ConvertTo-AbbrRule $Definition | Out-Null } catch { return }
  $script:failures++
  Write-Host "FAIL accepted an invalid rule: $Because"
}

Assert-Expand 'g' 'git'
Assert-Expand 'echo hi; g' 'echo hi; git'
Assert-Expand 'Get-Item x | g' 'Get-Item x | git'
Assert-Expand 'git st' 'git status'
Assert-Expand 'git s' 'git status'
Assert-Expand 'echo g' $null
Assert-Expand 'echo st' $null
Assert-Expand 'echo "a; g' $null
Assert-Expand 'gx' $null -Cursor 1
Assert-Expand 'g rest' 'git rest' -Cursor 1 -ExpectedCursor 3
Assert-Expand 'git cm' 'git commit -m ""' -ExpectedCursor 15
Assert-Expand 'git dfsi' 'git diff --staged --ignore-all-space'
Assert-Expand 'git d' 'git diff'
Assert-Expand 'git ress' 'git restore --staged'
Assert-Expand 'git bvv' 'git branch -vv'
Assert-Expand 'git branch vv' 'git branch -vv'
Assert-Expand 'git w' 'git wt'
Assert-Expand 'git log 5' 'git log -5'
Assert-Expand 'git diff 3' 'git diff HEAD~3 HEAD'
Assert-Expand 'git rebase c' 'git rebase --continue'
Assert-Expand 'git push origin f' 'git push origin --force-with-lease'
Assert-Expand 'git log g' 'git log --grep=""' -ExpectedCursor 16
Assert-Expand 'c' 'z'
Assert-Expand 'gh' 'ghtkn exec -e GH_TOKEN -- gh'
Assert-Expand 'chezmoi app' 'chezmoi apply'
Assert-Expand 'eza -l :n' 'eza -l -s modified -r'
Assert-Expand 'ls x-co' 'ls $env:XDG_CONFIG_HOME' -ExpectedCursor 23
Assert-Expand 'echo yyyy-mm-dd' ('echo ' + (Get-Date).ToString('yyyy-MM-dd'))
Assert-Expand 'echo yyyy/mm/dd+1' ('echo ' + (Get-Date).AddDays(1).ToString('yyyy\/MM\/dd'))
Assert-Expand 'claude --resume ch' 'claude --resume --channels plugin:telegram@claude-plugins-official'
Assert-Expand 'tailscale serve bg' 'tailscale serve --bg'

$conditional = @(ConvertTo-AbbrRule @{ Trigger = 'x'; Snippet = 'no'; If = { $false } }; ConvertTo-AbbrRule @{ Trigger = 'x'; Snippet = 'yes' })
if ((Expand-AbbrLine -Line 'x' -Cursor 1 -Rules $conditional).Line -ne 'yes') { $failures++; Write-Host 'FAIL If did not fall through' }

Assert-Throws @{ Trigger = 'a'; TriggerPattern = '^a$'; Snippet = 'x' } 'both Trigger and TriggerPattern'
Assert-Throws @{ Trigger = 'a' } 'neither Snippet nor Evaluate'
Assert-Throws @{ Trigger = 'a'; Evaluate = 'x' } 'Evaluate that is not a scriptblock'

if ($failures) { Write-Host "$failures failure(s)"; exit 1 }
Write-Host "all passed ($($rules.Count) rules loaded)"
