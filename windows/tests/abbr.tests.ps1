# Tests for the expansion engine in abbr.ps1, using rules defined here rather than the shipped ones.
# Run: pwsh -NoProfile -File windows/tests/abbr.tests.ps1
$ErrorActionPreference = 'Stop'
$root = Join-Path $PSScriptRoot '..\dot_config\powershell'
. (Join-Path $root 'abbr.ps1')
$failures = 0

function New-Rules([hashtable[]] $Definitions) { @($Definitions | ForEach-Object { ConvertTo-AbbrRule $_ }) }

function Assert-Expand {
  param([object[]] $Rules, [string] $Line, [string] $Expected, [int] $Cursor = $Line.Length, [int] $ExpectedCursor = -1, [object] $Placed = $null, [string] $Because)
  $r = Expand-AbbrLine -Line $Line -Cursor $Cursor -Rules $Rules
  $ok = "$($r.Line)" -ceq $Expected -and
    ($ExpectedCursor -lt 0 -or $r.Cursor -eq $ExpectedCursor) -and
    ($null -eq $Placed -or $r.Placed -eq $Placed)
  if (-not $ok) {
    $script:failures++
    Write-Host "FAIL ${Because}: '$Line' -> '$($r.Line)' (cursor $($r.Cursor), placed $($r.Placed)), expected '$Expected'"
  }
}

function Assert-Throws([hashtable] $Definition, [string] $Because) {
  try { ConvertTo-AbbrRule $Definition | Out-Null } catch { return }
  $script:failures++
  Write-Host "FAIL accepted an invalid rule: $Because"
}

# Trigger is an exact match; TriggerPattern is a regex
$rules = New-Rules @{ Trigger = 'g'; Snippet = 'git' }, @{ Trigger = 'a.b'; Snippet = 'dot' }, @{ TriggerPattern = '^d+$'; Snippet = 'many-d' }
Assert-Expand $rules 'g' 'git' -ExpectedCursor 3 -Placed $false -Because 'literal trigger'
Assert-Expand $rules 'gg' '' -Because 'literal trigger does not match a longer word'
Assert-Expand $rules 'axb' '' -Because 'literal trigger escapes regex metacharacters'
Assert-Expand $rules 'ddd' 'many-d' -Because 'pattern trigger'

# Only the word right before the cursor expands, and only when the cursor ends it
Assert-Expand $rules 'g rest' 'git rest' -Cursor 1 -ExpectedCursor 3 -Because 'text after the cursor is kept'
Assert-Expand $rules 'gx' '' -Cursor 1 -Because 'cursor inside a word'
Assert-Expand $rules '' '' -Because 'empty line'
Assert-Expand $rules 'g ' '' -Because 'cursor after whitespace'

# Non-global rules expand only in command position
foreach ($line in 'x; g', 'x;g', 'x | g', 'x|g', 'x && g', '& g', '(g', '{g', '{ g', '  g') {
  Assert-Expand $rules $line ($line.Substring(0, $line.Length - 1) + 'git') -Because "command position: '$line'"
}
Assert-Expand $rules 'echo g' '' -Because 'non-global rule in argument position'
$global = New-Rules @{ Trigger = 'g'; Snippet = 'git'; Global = $true }
Assert-Expand $global 'echo g' 'echo git' -Because 'global rule in argument position'

# No expansion inside quotes
Assert-Expand $global 'echo "a g' '' -Because 'inside double quotes'
Assert-Expand $global "echo 'a g" '' -Because 'inside single quotes'
Assert-Expand $global 'echo "a" g' 'echo "a" git' -Because 'after a closed quote'
Assert-Expand $global 'echo "a`" g' '' -Because 'escaped quote does not close the string'
Assert-Expand $global 'echo ''a`'' g' 'echo ''a`'' git' -Because 'backtick does not escape inside single quotes'

# Context matches the text from line start to cursor, trigger included
$ctx = New-Rules @{ Trigger = 'st'; Snippet = 'status'; Global = $true; Context = '^git\s+\S+$' }
Assert-Expand $ctx 'git st' 'git status' -Because 'context matches'
Assert-Expand $ctx 'git log st' '' -Because 'context does not match'
Assert-Expand $ctx 'git st --x' 'git status --x' -Cursor 6 -Because 'context ignores text after the cursor'

# The first matching rule wins, and a rule that cannot apply falls through to the next
$order = New-Rules @{ Trigger = 'x'; Snippet = 'first' }, @{ Trigger = 'x'; Snippet = 'second' }
Assert-Expand $order 'x' 'first' -Because 'first match wins'
$if = New-Rules @{ Trigger = 'x'; Snippet = 'no'; If = { $false } }, @{ Trigger = 'x'; Snippet = 'yes'; If = { $true } }
Assert-Expand $if 'x' 'yes' -Because 'If false falls through, If true applies'
$skip = New-Rules @{ Trigger = 'x'; Snippet = 'ctx'; Global = $true; Context = '^never' }, @{ Trigger = 'x'; Snippet = 'fallback' }
Assert-Expand $skip 'x' 'fallback' -Because 'context mismatch falls through'

# Evaluate receives the named groups and its output replaces the trigger
$eval = New-Rules @(
  @{ TriggerPattern = '^d(?<s>s)?(?<i>i)?$'; Evaluate = { param($m) 'diff' + ($m.s ? ' -s' : '') + ($m.i ? ' -i' : '') } }
  @{ Trigger = 'empty'; Evaluate = { '' } }
  @{ Trigger = 'empty'; Snippet = 'after-empty' }
  @{ Trigger = 'boom'; Evaluate = { throw 'boom' } }
  @{ Trigger = 'boom'; Snippet = 'after-throw' }
  @{ Trigger = 'lines'; Evaluate = { 'a'; 'b' } }
)
Assert-Expand $eval 'd' 'diff' -Because 'optional groups absent'
Assert-Expand $eval 'dsi' 'diff -s -i' -Because 'named groups passed to Evaluate'
Assert-Expand $eval 'di' 'diff -i' -Because 'only matched groups are set'
Assert-Expand $eval 'empty' 'after-empty' -Because 'empty Evaluate output falls through'
Assert-Expand $eval 'boom' 'after-throw' -Because 'throwing Evaluate falls through'
Assert-Expand $eval 'lines' "a`nb" -Because 'multiple outputs are joined with newlines'

# Cursor marks where the cursor goes; the marker itself is removed
$cur = New-Rules @{ Trigger = 'cm'; Snippet = 'commit -m "{}"'; Cursor = '{}' }, @{ Trigger = 'nomark'; Snippet = 'plain'; Cursor = '{}' }
Assert-Expand $cur 'cm' 'commit -m ""' -ExpectedCursor 11 -Placed $true -Because 'cursor placed at marker'
Assert-Expand $cur 'x; cm' 'x; commit -m ""' -ExpectedCursor 14 -Because 'marker offset includes the prefix'
Assert-Expand $cur 'nomark' 'plain' -ExpectedCursor 5 -Placed $false -Because 'snippet without the marker'

# Rule validation
Assert-Throws @{ Trigger = 'a'; TriggerPattern = '^a$'; Snippet = 'x' } 'both Trigger and TriggerPattern'
Assert-Throws @{ Snippet = 'x' } 'neither Trigger nor TriggerPattern'
Assert-Throws @{ Trigger = 'a' } 'neither Snippet nor Evaluate'
Assert-Throws @{ Trigger = 'a'; Snippet = 'x'; Evaluate = { 'y' } } 'both Snippet and Evaluate'
Assert-Throws @{ Trigger = 'a'; Evaluate = 'x' } 'Evaluate that is not a scriptblock'
Assert-Throws @{ Trigger = 'a'; Snippet = 'x'; If = '$true' } 'If that is not a scriptblock'
Assert-Throws @{ TriggerPattern = '('; Snippet = 'x' } 'invalid regex'

# Import-AbbrRule reads *.ps1 in file name order
$dir = Join-Path ([IO.Path]::GetTempPath()) "abbr-test-$PID"
New-Item -ItemType Directory -Path $dir -Force | Out-Null
try {
  Set-Content (Join-Path $dir 'b.ps1') "@{ Trigger = 'x'; Snippet = 'from-b' }"
  Set-Content (Join-Path $dir 'a.ps1') "@{ Trigger = 'x'; Snippet = 'from-a' }; @{ Trigger = 'y'; Snippet = 'y' }"
  Set-Content (Join-Path $dir 'c.txt') "@{ Trigger = 'x'; Snippet = 'from-txt' }"
  $imported = @(Import-AbbrRule $dir)
  if ($imported.Count -ne 3) { $failures++; Write-Host "FAIL import: expected 3 rules, got $($imported.Count)" }
  Assert-Expand $imported 'x' 'from-a' -Because 'files load in name order'
} finally {
  Remove-Item $dir -Recurse -Force
}

# The shipped rule files must at least load
$shipped = @(Import-AbbrRule (Join-Path $root 'abbr'))

if ($failures) { Write-Host "$failures failure(s)"; exit 1 }
Write-Host "all passed (shipped rules: $($shipped.Count))"
