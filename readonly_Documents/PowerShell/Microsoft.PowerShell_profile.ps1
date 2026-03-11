#f45873b3-b655-43a6-b217-97c00aa0db58 PowerToys CommandNotFound module (lazy load)
$canary = $ExecutionContext.SessionState.InvokeCommand.CommandNotFoundAction
$ExecutionContext.SessionState.InvokeCommand.CommandNotFoundAction = [EventHandler[System.Management.Automation.CommandLookupEventArgs]] {
    param([object] $sender, [System.Management.Automation.CommandLookupEventArgs] $e)
    end {
        Import-Module -Name Microsoft.WinGet.CommandNotFound -ErrorAction SilentlyContinue
        # Remove this bootstrap handler after first invocation
        $ExecutionContext.SessionState.InvokeCommand.CommandNotFoundAction = $null
    }
}
#f45873b3-b655-43a6-b217-97c00aa0db58

# Import the Chocolatey Profile that contains the necessary code to enable
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab completion
# for `choco` will not function.
# See https://ch0.co/tab-completion for details.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}

# Aliases
function ll { Get-ChildItem -Force }
function Optimize-WSL { Optimize-VHD -Path $env:LocalAppData\Docker\wsl\main\ext4.vhdx -Mode full }

# oh-my-posh {{{

# Theme
# ## Dependencies
# - [ryanoasis/nerd-fonts](https://github.com/ryanoasis/nerd-fonts)
# - Config Terminal fonts
$env:POSH_SESSION_ID = "7d11e128-fc2a-4a49-80c7-db4979f57ce2";& 'C:\Users\s_kon.ad\AppData\Local\oh-my-posh\init.9595566853615471448.ps1'

$_scoopModulesDir = "$($(Get-Item $(Get-Command scoop.ps1).Path).Directory.Parent.FullName)\modules"
Import-Module "$_scoopModulesDir\posh-git"
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

# Need: scoop install scoop-completion
Import-Module "$_scoopModulesDir\scoop-completion"
Remove-Variable _scoopModulesDir

# }}} - omp

# mise {{{
$Env:Path='C:\Users\s_kon.ad\scoop\apps\mise\current\bin'+[IO.Path]::PathSeparator+$env:Path
$env:MISE_SHELL = 'pwsh'
if (-not (Test-Path -Path Env:/__MISE_ORIG_PATH)) {
    $env:__MISE_ORIG_PATH = $env:PATH
}

function mise {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments=$true)]  # Allow any number of arguments, including none
        [string[]] $arguments
    )

    $previous_out_encoding = $OutputEncoding
    $previous_console_out_encoding = [Console]::OutputEncoding
    $OutputEncoding = [Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8

    function _reset_output_encoding {
        $OutputEncoding = $previous_out_encoding
        [Console]::OutputEncoding = $previous_console_out_encoding
    }

    if ($arguments.count -eq 0) {
        & "C:\Users\s_kon.ad\scoop\apps\mise\current\bin\mise.exe"
        _reset_output_encoding
        return
    } elseif ($arguments -contains '-h' -or $arguments -contains '--help') {
        & "C:\Users\s_kon.ad\scoop\apps\mise\current\bin\mise.exe" @arguments
        _reset_output_encoding
        return
    }

    $command = $arguments[0]
    if ($arguments.Length -gt 1) {
        $remainingArgs = $arguments[1..($arguments.Length - 1)]
    } else {
        $remainingArgs = @()
    }

    switch ($command) {
        { $_ -in 'deactivate', 'shell', 'sh' } {
            & "C:\Users\s_kon.ad\scoop\apps\mise\current\bin\mise.exe" $command @remainingArgs | Out-String | Invoke-Expression -ErrorAction SilentlyContinue
            _reset_output_encoding
        }
        default {
            & "C:\Users\s_kon.ad\scoop\apps\mise\current\bin\mise.exe" $command @remainingArgs
            $status = $LASTEXITCODE
            if ($(Test-Path -Path Function:\_mise_hook)){
                _mise_hook
            }
            _reset_output_encoding
            # Pass down exit code from mise after _mise_hook
            if ($PSVersionTable.PSVersion.Major -ge 7) {
                pwsh -NoProfile -Command exit $status
            } else {
                powershell -NoProfile -Command exit $status
            }
        }
    }
}

function Global:_mise_hook {
    if ($env:MISE_SHELL -eq "pwsh"){
        & "C:\Users\s_kon.ad\scoop\apps\mise\current\bin\mise.exe" hook-env $args -s pwsh | Out-String | Invoke-Expression -ErrorAction SilentlyContinue
    }
}

function __enable_mise_chpwd{
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        if ($env:MISE_PWSH_CHPWD_WARNING -ne '0') {
            Write-Warning "mise: chpwd functionality requires PowerShell version 7 or higher. Your current version is $($PSVersionTable.PSVersion). You can add `$env:MISE_PWSH_CHPWD_WARNING=0` to your environment to disable this warning."
        }
        return
    }
    if (-not $__mise_pwsh_chpwd){
        $Global:__mise_pwsh_chpwd= $true
        $_mise_chpwd_hook = [EventHandler[System.Management.Automation.LocationChangedEventArgs]] {
            param([object] $source, [System.Management.Automation.LocationChangedEventArgs] $eventArgs)
            end {
                _mise_hook
            }
        };
        $__mise_pwsh_previous_chpwd_function=$ExecutionContext.SessionState.InvokeCommand.LocationChangedAction;

        if ($__mise_original_pwsh_chpwd_function) {
            $ExecutionContext.SessionState.InvokeCommand.LocationChangedAction = [Delegate]::Combine($__mise_pwsh_previous_chpwd_function, $_mise_chpwd_hook)
        }
        else {
            $ExecutionContext.SessionState.InvokeCommand.LocationChangedAction = $_mise_chpwd_hook
        }
    }
}
__enable_mise_chpwd
Remove-Item -ErrorAction SilentlyContinue -Path Function:/__enable_mise_chpwd

function __enable_mise_prompt {
    if (-not $__mise_pwsh_previous_prompt_function){
        $Global:__mise_pwsh_previous_prompt_function=$function:prompt
        function global:prompt {
            if (Test-Path -Path Function:\_mise_hook){
                _mise_hook
            }
            & $__mise_pwsh_previous_prompt_function
        }
    }
}
__enable_mise_prompt
Remove-Item -ErrorAction SilentlyContinue -Path Function:/__enable_mise_prompt

_mise_hook
if (-not $__mise_pwsh_command_not_found){
    $Global:__mise_pwsh_command_not_found= $true
    function __enable_mise_command_not_found {
        $_mise_pwsh_cmd_not_found_hook = [EventHandler[System.Management.Automation.CommandLookupEventArgs]] {
            param([object] $Name, [System.Management.Automation.CommandLookupEventArgs] $eventArgs)
            end {
                if ([Microsoft.PowerShell.PSConsoleReadLine]::GetHistoryItems()[-1].CommandLine -match ([regex]::Escape($Name))) {
                    if (& "C:\Users\s_kon.ad\scoop\apps\mise\current\bin\mise.exe" hook-not-found -s pwsh -- $Name){
                        _mise_hook
                        if (Get-Command $Name -ErrorAction SilentlyContinue){
                            $EventArgs.Command = Get-Command $Name
                            $EventArgs.StopSearch = $true
                        }
                    }
                }
            }
        }
        $current_command_not_found_function = $ExecutionContext.SessionState.InvokeCommand.CommandNotFoundAction
        if ($current_command_not_found_function) {
            $ExecutionContext.SessionState.InvokeCommand.CommandNotFoundAction = [Delegate]::Combine($current_command_not_found_function, $_mise_pwsh_cmd_not_found_hook)
        }
        else {
            $ExecutionContext.SessionState.InvokeCommand.CommandNotFoundAction = $_mise_pwsh_cmd_not_found_hook
        }
    }
    __enable_mise_command_not_found
    Remove-Item -ErrorAction SilentlyContinue -Path Function:/__enable_mise_command_not_found
}
# }}} - mise

# ghq-fzf
Set-PSReadLineKeyHandler -Chord 'Ctrl+g' -ScriptBlock {
    try {
        $ghqRoot = ghq root
        if (-not $ghqRoot) { return }

        $src = ghq list |
            fzf --preview "bat --style=header,grid --line-range :80 $ghqRoot/{}/README.*"

        if ($src) {
            Set-Location (Join-Path $ghqRoot $src)
        }
    }
    catch {
        # 何もしない（fzfキャンセル時など）
    }
}
