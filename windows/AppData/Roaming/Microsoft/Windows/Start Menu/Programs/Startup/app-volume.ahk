#Requires AutoHotkey v2.0
#SingleInstance Force

; Per-application volume hotkeys backed by NirCmd.
; configuration.personal.dsc.yaml installs NirCmd into %LOCALAPPDATA%\Programs\NirCmd.
; AutoHotkey v2 shares one case-insensitive namespace between functions and variables,
; so this path must not be named after the NirCmd() function.
NircmdExe := EnvGet("LOCALAPPDATA") "\Programs\NirCmd\nircmd.exe"

NirCmd(args) {
    Run('"' NircmdExe '" ' args, , "Hide")
}

; Ctrl+Alt+M: toggle mute of the focused application (mute mode 2 = toggle)
^!m::NirCmd("muteappvolume focused 2")

; Ctrl+Alt+Up / Down: change the focused application's volume by 10%
^!Up::NirCmd("changeappvolume focused 0.1")
^!Down::NirCmd("changeappvolume focused -0.1")

; Ctrl+Alt+G: toggle mute of a fixed process. Replace game.exe with the real exe name before enabling.
; ^!g::NirCmd('muteappvolume "game.exe" 2')
