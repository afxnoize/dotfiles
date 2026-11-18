# Walk up from $dir looking for .git (a directory, or a file in worktrees/submodules).
# Done in-process so that directories outside a repository never spawn git.exe.
function Find-GitRoot([string] $dir) {
  while ($dir) {
    $dotGit = Join-Path $dir '.git'
    if ([IO.Directory]::Exists($dotGit) -or [IO.File]::Exists($dotGit)) { return $dir }
    $dir = [IO.Path]::GetDirectoryName($dir)
  }
}

function Get-GitPromptSegment {
  $loc = $ExecutionContext.SessionState.Path.CurrentLocation
  if ($loc.Provider.Name -ne 'FileSystem' -or -not (Find-GitRoot $loc.ProviderPath)) { return '' }

  $lines = git --no-optional-locks status --porcelain=v2 --branch 2>$null
  if ($LASTEXITCODE -ne 0) { return '' }

  $branch = ''; $oid = ''; $ahead = 0; $behind = 0
  $staged = 0; $unstaged = 0; $untracked = 0; $conflicted = 0
  foreach ($line in $lines) {
    switch -Regex ($line) {
      '^# branch\.oid (\S+)' { $oid = $Matches[1] }
      '^# branch\.head (.+)' { $branch = $Matches[1] }
      '^# branch\.ab \+(\d+) -(\d+)' { $ahead = [int]$Matches[1]; $behind = [int]$Matches[2] }
      '^[12] (.)(.)' {
        if ($Matches[1] -ne '.') { $staged++ }
        if ($Matches[2] -ne '.') { $unstaged++ }
      }
      '^u ' { $conflicted++ }
      '^\? ' { $untracked++ }
    }
  }
  if ($branch -eq '(detached)') { $branch = $oid.Substring(0, [Math]::Min(7, $oid.Length)) }

  $s = $PSStyle
  $out = " $($s.Foreground.Magenta)$branch$($s.Reset)"
  if ($ahead) { $out += " $($s.Foreground.Cyan)↑$ahead$($s.Reset)" }
  if ($behind) { $out += " $($s.Foreground.Cyan)↓$behind$($s.Reset)" }
  if ($conflicted) { $out += " $($s.Foreground.Red)!$conflicted$($s.Reset)" }
  if ($staged) { $out += " $($s.Foreground.Green)+$staged$($s.Reset)" }
  if ($unstaged) { $out += " $($s.Foreground.Yellow)~$unstaged$($s.Reset)" }
  if ($untracked) { $out += " $($s.Foreground.BrightBlack)?$untracked$($s.Reset)" }
  $out
}

# Same as zsh's ^g^g: pick a ghq repository, most recently modified first, and cd into it.
# The cd goes through AcceptLine so it lands in history and the prompt redraws.
if (Get-Module PSReadLine) {
  Set-PSReadLineKeyHandler -Chord 'Ctrl+g,Ctrl+g' -BriefDescription ghq-fzf -ScriptBlock {
    $root = ghq root
    $src = ghq list |
      Sort-Object { [IO.Directory]::GetLastWriteTimeUtc((Join-Path $root $_)) } -Descending |
      fzf --preview "bat --color=always --style=header,grid --line-range :80 $root/{}/README.md"
    if (-not $src) { return }
    $dir = (Join-Path $root $src).Replace("'", "''")
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert("cd '$dir'")
    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
  }
}

function prompt {
  $ok = $?
  $exitCode = $global:LASTEXITCODE

  $path = $ExecutionContext.SessionState.Path.CurrentLocation.Path
  if ($path -eq $HOME -or $path.StartsWith($HOME + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    $path = '~' + $path.Substring($HOME.Length)
  }
  $mark = if ($ok) { "$($PSStyle.Foreground.Green)>" } else { "$($PSStyle.Foreground.Red)>" }
  $text = "$($PSStyle.Foreground.Blue)$path$($PSStyle.Reset)$(Get-GitPromptSegment)`n$mark$($PSStyle.Reset) "

  $global:LASTEXITCODE = $exitCode
  $text
}

# Expand abbreviations on Space and Enter. PSReadLine is absent in non-interactive sessions.
if (Get-Module PSReadLine) {
  . "$PSScriptRoot\abbr.ps1"
  try { Enable-Abbr "$PSScriptRoot\abbr" } catch { Write-Warning "abbr disabled: $_" }
}

# Initialize after prompt is defined, in case zoxide wraps it.
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
  Invoke-Expression (& { (zoxide init powershell | Out-String) })
}
