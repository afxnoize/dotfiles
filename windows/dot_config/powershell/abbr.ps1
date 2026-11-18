# zabrze-style abbreviation expansion for PSReadLine.
# Rule files are .ps1 scripts that output one hashtable per rule (see abbr/*.ps1).

function ConvertTo-AbbrRule {
  param([Parameter(Mandatory)] [hashtable] $Definition)

  $d = $Definition
  $label = $d.Name ?? $d.Trigger ?? $d.TriggerPattern
  if ([bool]$d.Trigger -eq [bool]$d.TriggerPattern) {
    throw "abbr '$label': set exactly one of Trigger or TriggerPattern"
  }
  if (($null -eq $d.Snippet) -eq ($null -eq $d.Evaluate)) {
    throw "abbr '$label': set exactly one of Snippet or Evaluate"
  }
  if ($d.Evaluate -and $d.Evaluate -isnot [scriptblock]) { throw "abbr '$label': Evaluate must be a scriptblock" }
  if ($d.If -and $d.If -isnot [scriptblock]) { throw "abbr '$label': If must be a scriptblock" }

  $pattern = if ($d.TriggerPattern) { $d.TriggerPattern } else { '^' + [regex]::Escape($d.Trigger) + '$' }
  [pscustomobject]@{
    Name     = $label
    Trigger  = [regex]::new($pattern)
    Snippet  = $d.Snippet
    Evaluate = $d.Evaluate
    Global   = [bool]$d.Global
    Context  = if ($d.Context) { [regex]::new($d.Context) }
    Cursor   = $d.Cursor
    If       = $d.If
  }
}

function Import-AbbrRule {
  param([Parameter(Mandatory)] [string] $Path)

  Get-ChildItem -Path $Path -Filter *.ps1 -File |
    Sort-Object Name |
    ForEach-Object { & $_.FullName } |
    ForEach-Object { ConvertTo-AbbrRule $_ }
}

function Test-AbbrInQuote([string] $Text) {
  $quote = $null
  for ($i = 0; $i -lt $Text.Length; $i++) {
    $c = $Text[$i]
    if ($quote -eq '"' -and $c -eq '`') { $i++; continue }
    if ($quote) { if ($c -eq $quote) { $quote = $null } }
    elseif ($c -eq '"' -or $c -eq "'") { $quote = $c }
  }
  [bool]$quote
}

# Returns $null when nothing expands; otherwise the new line, the new cursor,
# and whether the cursor was placed at the rule's marker.
function Expand-AbbrLine {
  param([string] $Line, [int] $Cursor, [object[]] $Rules)

  if ($Cursor -lt $Line.Length -and -not [char]::IsWhiteSpace($Line[$Cursor])) { return }
  $left = $Line.Substring(0, $Cursor)
  $word = [regex]::Match($left, '[^\s|;&({]+$')
  if (-not $word.Success) { return }
  $prefix = $left.Substring(0, $word.Index)
  if (Test-AbbrInQuote $prefix) { return }
  $atCommand = $prefix -match '(^|[|;&({])\s*$'

  foreach ($rule in $Rules) {
    if (-not $rule.Global -and -not $atCommand) { continue }
    $match = $rule.Trigger.Match($word.Value)
    if (-not $match.Success) { continue }
    if ($rule.Context -and -not $rule.Context.IsMatch($left)) { continue }
    if ($rule.If -and -not (& $rule.If)) { continue }

    $text = $rule.Snippet
    if ($rule.Evaluate) {
      $groups = @{}
      foreach ($name in $rule.Trigger.GetGroupNames()) {
        if ($match.Groups[$name].Success) { $groups[$name] = $match.Groups[$name].Value }
      }
      try { $text = (@(& $rule.Evaluate $groups) -join "`n") } catch { continue }
      if (-not $text) { continue }
    }

    $placed = $false
    $offset = $text.Length
    if ($rule.Cursor) {
      $at = $text.IndexOf($rule.Cursor)
      if ($at -ge 0) {
        $text = $text.Remove($at, $rule.Cursor.Length)
        $offset = $at
        $placed = $true
      }
    }
    return [pscustomobject]@{
      Line   = $prefix + $text + $Line.Substring($Cursor)
      Cursor = $prefix.Length + $offset
      Placed = $placed
    }
  }
}

function Invoke-AbbrExpansion([object[]] $Rules) {
  $line = $null; $cursor = $null
  [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
  $result = Expand-AbbrLine -Line $line -Cursor $cursor -Rules $Rules
  if ($result) {
    [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $line.Length, $result.Line)
    [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($result.Cursor)
  }
  $result
}

function Enable-Abbr {
  param([Parameter(Mandatory)] [string] $Path)

  $rules = @(Import-AbbrRule $Path)
  Set-PSReadLineKeyHandler -Key Spacebar -BriefDescription ExpandAbbr -ScriptBlock {
    if (-not (Invoke-AbbrExpansion $rules).Placed) {
      [Microsoft.PowerShell.PSConsoleReadLine]::Insert(' ')
    }
  }.GetNewClosure()
  Set-PSReadLineKeyHandler -Key Enter -BriefDescription ExpandAbbrAndAccept -ScriptBlock {
    [void](Invoke-AbbrExpansion $rules)
    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
  }.GetNewClosure()
}
