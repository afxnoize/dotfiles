# zabrze-style abbreviation expansion for PSReadLine.
# Rule files are .ps1 scripts that output one hashtable per rule (see abbr/*.ps1).

function ConvertTo-AbbrRule {
  param([Parameter(Mandatory)] [hashtable] $Definition)

  $d = $Definition
  $label = $d.Name ?? $d.Trigger ?? $d.TriggerPattern
  $known = 'Name', 'Trigger', 'TriggerPattern', 'Snippet', 'Evaluate', 'Global', 'Context', 'Cursor', 'If'
  $unknown = $d.Keys | Where-Object { $_ -notin $known }
  if ($unknown) { throw "abbr '$label': unknown key(s): $($unknown -join ', ')" }
  if ([bool]$d.Trigger -eq [bool]$d.TriggerPattern) {
    throw "abbr '$label': set exactly one of Trigger or TriggerPattern"
  }
  if (($null -eq $d.Snippet) -eq ($null -eq $d.Evaluate)) {
    throw "abbr '$label': set exactly one of Snippet or Evaluate"
  }
  if ($d.Evaluate -and $d.Evaluate -isnot [scriptblock]) { throw "abbr '$label': Evaluate must be a scriptblock" }
  if ($d.If -and $d.If -isnot [scriptblock]) { throw "abbr '$label': If must be a scriptblock" }
  if ($d.Cursor -and $d.Cursor -isnot [string]) { throw "abbr '$label': Cursor must be a string" }

  $pattern = if ($d.TriggerPattern) { $d.TriggerPattern } else { '^' + [regex]::Escape($d.Trigger) + '$' }
  [pscustomobject]@{
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

  # NTFS already lists by name; the sort keeps the order on file systems that do not.
  Get-ChildItem -Path $Path -Filter *.ps1 -File |
    Sort-Object Name |
    ForEach-Object { & $_.FullName } |
    ForEach-Object { ConvertTo-AbbrRule $_ }
}

# A small lexer over the text before the word being typed. Returns $null inside a
# string or a comment; otherwise where the current statement starts and whether
# the text sits directly inside a hashtable literal (where words are keys).
function Get-AbbrScanState([string] $Text) {
  $quote = $null
  $stack = [System.Collections.Generic.Stack[string]]::new()
  $start = 0
  for ($i = 0; $i -lt $Text.Length; $i++) {
    $c = $Text[$i]
    $next = if ($i + 1 -lt $Text.Length) { $Text[$i + 1] } else { [char]0 }

    if ($quote -eq "'") {
      if ($c -eq "'") { if ($next -eq "'") { $i++ } else { $quote = $null } }
      continue
    }
    if ($quote -eq '"') {
      if ($c -eq '`') { $i++ }
      elseif ($c -eq '"') { if ($next -eq '"') { $i++ } else { $quote = $null } }
      continue
    }
    if ($quote) {
      if ($c -eq "`n" -and $Text.Substring($i + 1).StartsWith($quote[1] + '@')) { $i += 2; $quote = $null }
      continue
    }

    $tokenStart = $i -eq 0 -or [char]::IsWhiteSpace($Text[$i - 1]) -or $Text[$i - 1] -in '|', ';', '&', '(', '{'
    if ($c -eq '#' -and $tokenStart) {
      $end = $Text.IndexOf("`n", $i)
      if ($end -lt 0) { return }
      $i = $end - 1
      continue
    }
    if ($c -eq '<' -and $next -eq '#') {
      $end = $Text.IndexOf('#>', $i + 2)
      if ($end -lt 0) { return }
      $i = $end + 1
      continue
    }
    if ($c -eq '@' -and $next -in "'", '"') { $quote = "@$next"; $i++; continue }
    if ($c -in "'", '"') { $quote = [string]$c; continue }

    switch ($c) {
      { $_ -in '|', ';', '&', "`n" } { $start = $i + 1 }
      '(' { $stack.Push('paren'); $start = $i + 1 }
      '{' { $stack.Push($(if ($i -gt 0 -and $Text[$i - 1] -eq '@') { 'hash' } else { 'block' })); $start = $i + 1 }
      { $_ -in ')', '}' } { if ($stack.Count) { [void]$stack.Pop() } }
    }
  }
  if ($quote) { return }
  [pscustomobject]@{
    StatementStart = $start
    InHash         = $stack.Count -gt 0 -and $stack.Peek() -eq 'hash'
  }
}

# Returns $null when nothing expands; otherwise the new line, the new cursor,
# and whether the cursor was placed at the rule's marker.
function Expand-AbbrLine {
  param([string] $Line, [int] $Cursor, [object[]] $Rules)

  if ($Cursor -lt $Line.Length -and $Line[$Cursor] -notmatch '[\s)};|]') { return }
  $left = $Line.Substring(0, $Cursor)
  $word = [regex]::Match($left, '[^\s|;&({]+$')
  if (-not $word.Success) { return }
  $prefix = $left.Substring(0, $word.Index)
  $state = Get-AbbrScanState $prefix
  if (-not $state) { return }
  $atCommand = -not $state.InHash -and -not $prefix.Substring($state.StatementStart).Trim()
  $statement = $left.Substring($state.StatementStart).TrimStart()

  # If and Evaluate run on every keystroke; keep them from leaking $LASTEXITCODE to the prompt.
  $savedExitCode = $global:LASTEXITCODE
  try {
    foreach ($rule in $Rules) {
      if (-not $rule.Global -and -not $atCommand) { continue }
      $match = $rule.Trigger.Match($word.Value)
      if (-not $match.Success) { continue }
      if ($rule.Context -and -not $rule.Context.IsMatch($statement)) { continue }
      if ($rule.If -and -not $(try { & $rule.If 2>$null } catch { $false })) { continue }

      $text = $rule.Snippet
      if ($rule.Evaluate) {
        $groups = @{}
        foreach ($name in $rule.Trigger.GetGroupNames()) {
          if ($match.Groups[$name].Success) { $groups[$name] = $match.Groups[$name].Value }
        }
        try { $text = (@(& $rule.Evaluate $groups 2>$null) -join "`n") } catch { continue }
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
  } finally {
    $global:LASTEXITCODE = $savedExitCode
  }
}

# Decides what a key does: the expansion to apply, then what to do after it.
# A cursor placed at a marker waits for input, so Enter does not run the line.
# Keys still pending mean the text is being pasted, which is never expanded.
function Resolve-AbbrKey {
  param([ValidateSet('Space', 'Enter')] [string] $Key, [string] $Line, [int] $Cursor, [object[]] $Rules, [switch] $InputPending)

  $expansion = if (-not $InputPending) { Expand-AbbrLine -Line $Line -Cursor $Cursor -Rules $Rules }
  [pscustomobject]@{
    Expansion = $expansion
    Then      = if ($expansion.Placed) { 'None' } elseif ($Key -eq 'Space') { 'InsertSpace' } else { 'AcceptLine' }
  }
}

# A terminal paste arrives as a burst of keys. PSReadLine drains the console input
# into its private _queuedKeys before calling a handler, so Console.KeyAvailable
# alone misses it. Without that field (another PSReadLine version) only
# KeyAvailable is checked.
function Test-AbbrInputPending {
  if ($(try { [Console]::KeyAvailable } catch { $false })) { return $true }
  $flags = [Reflection.BindingFlags]'NonPublic,Static,Instance'
  $type = [Microsoft.PowerShell.PSConsoleReadLine]
  $singleton = $type.GetField('_singleton', $flags)?.GetValue($null)
  $queued = $type.GetField('_queuedKeys', $flags)?.GetValue($singleton)
  [bool]$queued.Count
}

function Invoke-AbbrKey([string] $Key, [object[]] $Rules) {
  $line = $null; $cursor = $null
  [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
  $action = Resolve-AbbrKey -Key $Key -Line $line -Cursor $cursor -Rules $Rules -InputPending:(Test-AbbrInputPending)
  if ($action.Expansion) {
    [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $line.Length, $action.Expansion.Line)
    [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($action.Expansion.Cursor)
  }
  switch ($action.Then) {
    'InsertSpace' { [Microsoft.PowerShell.PSConsoleReadLine]::Insert(' ') }
    'AcceptLine' { [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine() }
  }
}

function Enable-Abbr {
  param([Parameter(Mandatory)] [string] $Path)

  $rules = @(Import-AbbrRule $Path)
  Set-PSReadLineKeyHandler -Key Spacebar -BriefDescription ExpandAbbr -ScriptBlock {
    Invoke-AbbrKey Space $rules
  }.GetNewClosure()
  Set-PSReadLineKeyHandler -Key Enter -BriefDescription ExpandAbbrAndAccept -ScriptBlock {
    Invoke-AbbrKey Enter $rules
  }.GetNewClosure()
}
