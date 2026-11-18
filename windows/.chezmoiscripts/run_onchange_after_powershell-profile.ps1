# Point the PowerShell 7 profile at the chezmoi-managed one.
# $PROFILE lives under Documents, which may be redirected outside $HOME (e.g. OneDrive),
# so it cannot be a chezmoi target. chezmoi runs .ps1 with Windows PowerShell 5.1,
# whose $PROFILE differs, so the PowerShell 7 path is built from the Documents folder.
$ErrorActionPreference = 'Stop'

$profilePath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Microsoft.PowerShell_profile.ps1'
$line = '. "$env:XDG_CONFIG_HOME\powershell\profile.ps1"'

if (Test-Path $profilePath) {
  if ((Get-Content -Raw $profilePath).Trim() -eq $line) { return }
  Copy-Item $profilePath "$profilePath.bak" -Force
} else {
  New-Item -ItemType Directory -Force (Split-Path $profilePath) | Out-Null
}
Set-Content -Path $profilePath -Value $line
