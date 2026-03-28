"""Keystroke injection via AppleScript (System Events)."""

import ctypes
import subprocess
import time

_ax_checked = False
_ax_trusted = False


def is_accessibility_trusted() -> bool:
    global _ax_checked, _ax_trusted
    if _ax_checked:
        return _ax_trusted
    try:
        lib = ctypes.cdll.LoadLibrary(
            "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices"
        )
        func = lib.AXIsProcessTrusted
        func.restype = ctypes.c_bool
        _ax_trusted = func()
    except Exception:
        _ax_trusted = False
    _ax_checked = True
    print(f"[keys] AXIsProcessTrusted: {_ax_trusted}", flush=True)
    return _ax_trusted


def _applescript(script: str) -> bool:
    result = subprocess.run(
        ["osascript", "-e", script],
        capture_output=True, timeout=5,
    )
    if result.returncode != 0:
        err = result.stderr.decode().strip()
        print(f"[keys] AppleScript error: {err}", flush=True)
        return False
    return True


def type_text(text: str) -> bool:
    t0 = time.time()
    result = subprocess.run(["pbcopy"], input=text.encode(), capture_output=True)
    if result.returncode != 0:
        print(f"[keys] pbcopy failed: {result.stderr.decode()}", flush=True)
        return False
    time.sleep(0.05)
    ok = _applescript(
        'tell application "System Events" to keystroke "v" using command down'
    )
    dt = (time.time() - t0) * 1000
    print(f"[keys] type_text ok={ok} len={len(text)} dt={dt:.0f}ms", flush=True)
    return ok


def press_enter() -> bool:
    ok = _applescript('tell application "System Events" to key code 36')
    print(f"[keys] press_enter ok={ok}", flush=True)
    return ok


def press_ctrl_c() -> bool:
    ok = _applescript(
        'tell application "System Events" to keystroke "c" using control down'
    )
    print(f"[keys] press_ctrl_c ok={ok}", flush=True)
    return ok


def type_y_enter() -> bool:
    ok = _applescript('''
        tell application "System Events"
            keystroke "y"
            delay 0.02
            key code 36
        end tell
    ''')
    print(f"[keys] type_y_enter ok={ok}", flush=True)
    return ok


def type_n_enter() -> bool:
    ok = _applescript('''
        tell application "System Events"
            keystroke "n"
            delay 0.02
            key code 36
        end tell
    ''')
    print(f"[keys] type_n_enter ok={ok}", flush=True)
    return ok
