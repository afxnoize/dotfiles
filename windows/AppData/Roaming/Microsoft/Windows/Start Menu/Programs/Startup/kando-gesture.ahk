#Requires AutoHotkey v2.0
#SingleInstance Force

; Open the Kando pie menu by circling the mouse cursor.
; Kando has no built-in mouse gesture trigger, so this script watches the cursor
; and sends the menu shortcut. Set the same shortcut in Kando's settings.
; Once the circle is recognized, the shortcut is sent only after the cursor rests,
; so leftover motion does not select an item in the freshly opened menu.

; Tunables
INTERVAL_MS := 10         ; polling interval
STEP_PX     := 8          ; min travel before sampling a new heading
TURNS       := 1.5        ; full rotations required to arm
MAX_TURN    := 1.75       ; rad (~100deg); sharper bends are zigzags, not circles
IDLE_MS     := 150        ; reset after the cursor rests this long
MAX_MS      := 1500       ; rotations must finish within this window
SETTLE_MS   := 20         ; once armed, fire only after the cursor rests this long
COOLDOWN_MS := 800
SEND_KEYS   := "^!+{F18}" ; must match the Kando menu shortcut
PI          := 3.141592653589793

CoordMode "Mouse", "Screen"
MouseGetPos &ax, &ay
prevAngle := "", total := 0, startTick := 0, armed := false
lastMoveTick := A_TickCount, lastFire := 0
SetTimer Poll, INTERVAL_MS

Poll() {
    global
    MouseGetPos &x, &y
    now := A_TickCount

    ; Ignore drags so drawing or selecting text never opens the menu.
    if GetKeyState("LButton") || GetKeyState("RButton") || GetKeyState("MButton") {
        Reset(x, y)
        return
    }

    dx := x - ax, dy := y - ay
    if (dx * dx + dy * dy < STEP_PX * STEP_PX) {
        if (armed && now - lastMoveTick >= SETTLE_MS) {
            lastFire := now
            Send SEND_KEYS
            Reset(x, y)
        } else if (!armed && now - lastMoveTick > IDLE_MS) {
            Reset(x, y)
        }
        return
    }
    lastMoveTick := now
    ax := x, ay := y

    ; Gesture already recognized; wait for the cursor to settle.
    if armed
        return

    angle := DllCall("msvcrt\atan2", "Double", dy, "Double", dx, "Cdecl Double")
    if (prevAngle = "") {
        prevAngle := angle, total := 0, startTick := now
        return
    }

    d := angle - prevAngle
    if (d > PI)
        d -= 2 * PI
    else if (d < -PI)
        d += 2 * PI
    prevAngle := angle

    if (Abs(d) > MAX_TURN || now - startTick > MAX_MS) {
        total := 0, startTick := now
        return
    }

    total += d
    if (Abs(total) >= TURNS * 2 * PI && now - lastFire > COOLDOWN_MS)
        armed := true
}

Reset(x, y) {
    global
    ax := x, ay := y, prevAngle := "", total := 0, armed := false
}
