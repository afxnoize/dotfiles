# Helpers for the Script resources in configuration.*.dsc.yaml.
# curl.exe, tar.exe and .NET APIs instead of Invoke-WebRequest, Get-FileHash and
# Expand-Archive: winget's hosted PowerShell builds its own module path, so those may not load.

function Get-ReleaseStampPath([string]$Name) {
  Join-Path $env:LOCALAPPDATA "dotfiles\releases\$Name"
}

function Get-Sha256([string]$Path) {
  $stream = [IO.File]::OpenRead($Path)
  try {
    -join ([Security.Cryptography.SHA256]::Create().ComputeHash($stream) | ForEach-Object { $_.ToString('x2') })
  } finally {
    $stream.Close()
  }
}

# Downloads into %TEMP% and returns the path. Without -Sha256 the file is not verified.
function Save-Download {
  param(
    [Parameter(Mandatory)][string]$Url,
    [string]$Sha256
  )
  $path = Join-Path $env:TEMP ([IO.Path]::GetFileName(([uri]$Url).AbsolutePath))
  curl.exe -fsSL $Url -o $path
  if ($LASTEXITCODE) { throw "download failed: $Url" }
  if ($Sha256) {
    $actual = Get-Sha256 $path
    if ($actual -ne $Sha256) {
      [IO.File]::Delete($path)
      throw "hash mismatch for ${Url}: expected $Sha256, got $actual"
    }
  }
  $path
}

function Test-UserPath([string]$Dir) {
  $entries = [Environment]::GetEnvironmentVariable('Path', 'User') -split ';' | ForEach-Object { $_.Trim().TrimEnd('\') }
  $entries -icontains $Dir
}

function Add-UserPath([string]$Dir) {
  if (Test-UserPath $Dir) { return }
  # Edit the raw registry value: [Environment]::SetEnvironmentVariable would
  # write back expanded %VARIABLES% and turn REG_EXPAND_SZ into REG_SZ.
  $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
  try {
    $raw = [string]$key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    $kind = if ($key.GetValueNames() -contains 'Path') { $key.GetValueKind('Path') } else { [Microsoft.Win32.RegistryValueKind]::ExpandString }
    $key.SetValue('Path', $(if ($raw) { $raw.TrimEnd(';') + ';' + $Dir } else { $Dir }), $kind)
  } finally {
    $key.Close()
  }
  # Setting any user variable broadcasts the environment change to running programs.
  [Environment]::SetEnvironmentVariable('DOTFILES_INSTALLING', '1', 'User')
  [Environment]::SetEnvironmentVariable('DOTFILES_INSTALLING', $null, 'User')
}

# True when the release with this hash is installed, every -Require file exists,
# and -PathDir is on user PATH.
function Test-Release {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Sha256,
    [string[]]$Require,
    [string]$PathDir
  )
  $stamp = Get-ReleaseStampPath $Name
  (Test-Path $stamp) -and ([IO.File]::ReadAllText($stamp).Trim() -eq $Sha256) -and
    -not ($Require | Where-Object { $_ -and -not (Test-Path -LiteralPath $_) }) -and
    (-not $PathDir -or (Test-UserPath $PathDir))
}

# -FileName installs the download itself under that name; -Extract installs the zip entries matching the wildcard.
function Install-Release {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Url,
    [Parameter(Mandatory)][string]$Sha256,
    [Parameter(Mandatory)][string]$Dir,
    [string]$FileName,
    [string]$Extract,
    [string[]]$Require,
    [switch]$AddToPath,
    [switch]$RegisterFont
  )
  if ([bool]$FileName -eq [bool]$Extract) { throw "${Name}: pass exactly one of -FileName and -Extract" }
  if (Test-Release -Name $Name -Sha256 $Sha256 -Require $Require -PathDir $(if ($AddToPath) { $Dir })) { return }

  $download = Save-Download -Url $Url -Sha256 $Sha256
  $extracted = "$download-extracted"
  try {
    $stamp = Get-ReleaseStampPath $Name
    New-Item -ItemType Directory -Path $Dir, (Split-Path $stamp) -Force -ErrorAction Stop | Out-Null
    if ($FileName) {
      Copy-Item -Path $download -Destination (Join-Path $Dir $FileName) -Force -ErrorAction Stop
    } else {
      New-Item -ItemType Directory -Path $extracted -Force -ErrorAction Stop | Out-Null
      tar.exe -xf $download -C $extracted
      if ($LASTEXITCODE) { throw "${Name}: extraction failed: $download" }
      $files = Get-ChildItem -Path $extracted -Recurse -File -Filter $Extract
      if (-not $files) { throw "${Name}: no files match $Extract" }
      foreach ($file in $files) {
        Copy-Item -Path $file.FullName -Destination (Join-Path $Dir $file.Name) -Force -ErrorAction Stop
      }
      if ($RegisterFont) {
        # Per-user fonts are registered under HKCU with the full path of the file.
        $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Software\Microsoft\Windows NT\CurrentVersion\Fonts')
        try {
          foreach ($file in $files) {
            $key.SetValue("$($file.BaseName) (TrueType)", (Join-Path $Dir $file.Name))
          }
        } finally {
          $key.Close()
        }
      }
    }
    if ($AddToPath) { Add-UserPath $Dir }
    [IO.File]::WriteAllText($stamp, $Sha256)
  } finally {
    Remove-Item -Path $download, $extracted -Recurse -Force -ErrorAction SilentlyContinue
  }
}
