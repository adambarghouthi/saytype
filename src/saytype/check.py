"""Health check and eval suite for SayType."""

import subprocess
import sys
import time


class Check:
    def __init__(self, name: str):
        self.name = name
        self.passed = False
        self.detail = ""
        self.dt_ms = 0

    def __repr__(self):
        status = "PASS" if self.passed else "FAIL"
        return f"  [{status}] {self.name} ({self.dt_ms:.0f}ms) {self.detail}"


def check_microphone() -> Check:
    c = Check("Microphone access")
    t0 = time.time()
    try:
        import sounddevice as sd
        import numpy as np
        audio = sd.rec(int(0.1 * 16000), samplerate=16000, channels=1, dtype="float32")
        sd.wait()
        rms = float(np.sqrt(np.mean(audio ** 2)))
        c.passed = True
        c.detail = f"rms={rms:.4f}"
    except Exception as e:
        c.detail = str(e)
    c.dt_ms = (time.time() - t0) * 1000
    return c


def check_whisper(model_size: str = "tiny.en") -> Check:
    c = Check(f"Whisper model ({model_size})")
    t0 = time.time()
    try:
        from faster_whisper import WhisperModel
        import numpy as np
        model = WhisperModel(model_size, device="cpu", compute_type="int8")
        silence = np.zeros(16000, dtype=np.float32)
        segments, _ = model.transcribe(silence, language="en", beam_size=1)
        list(segments)
        c.passed = True
        c.detail = "loaded + inference ok"
    except Exception as e:
        c.detail = str(e)
    c.dt_ms = (time.time() - t0) * 1000
    return c


def check_vad() -> Check:
    c = Check("VAD (webrtcvad)")
    t0 = time.time()
    try:
        import webrtcvad
        import numpy as np
        vad = webrtcvad.Vad(3)
        frame = np.zeros(480, dtype=np.int16).tobytes()
        result = vad.is_speech(frame, 16000)
        c.passed = True
        c.detail = f"silence_is_speech={result}"
    except Exception as e:
        c.detail = str(e)
    c.dt_ms = (time.time() - t0) * 1000
    return c


def check_clipboard() -> Check:
    c = Check("Clipboard roundtrip")
    t0 = time.time()
    try:
        test_str = f"saytype_eval_{int(time.time())}"
        subprocess.run(["pbcopy"], input=test_str.encode(), capture_output=True, check=True)
        result = subprocess.run(["pbpaste"], capture_output=True, check=True)
        got = result.stdout.decode()
        c.passed = (got == test_str)
        c.detail = f"match={c.passed}"
    except Exception as e:
        c.detail = str(e)
    c.dt_ms = (time.time() - t0) * 1000
    return c


def check_system_events() -> Check:
    c = Check("System Events access")
    t0 = time.time()
    try:
        result = subprocess.run(
            ["osascript", "-e", 'tell application "System Events" to return name of first process'],
            capture_output=True, timeout=5,
        )
        if result.returncode == 0:
            c.passed = True
            c.detail = "osascript ok"
        else:
            c.detail = result.stderr.decode().strip()
    except Exception as e:
        c.detail = str(e)
    c.dt_ms = (time.time() - t0) * 1000
    return c


def check_accessibility() -> Check:
    c = Check("AXIsProcessTrusted")
    t0 = time.time()
    try:
        import ctypes
        lib = ctypes.cdll.LoadLibrary(
            "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices"
        )
        func = lib.AXIsProcessTrusted
        func.restype = ctypes.c_bool
        trusted = func()
        c.passed = trusted
        c.detail = f"trusted={trusted}"
        if not trusted:
            c.detail += " (add app to System Settings > Accessibility)"
    except Exception as e:
        c.detail = str(e)
    c.dt_ms = (time.time() - t0) * 1000
    return c


def check_injection() -> Check:
    c = Check("Live keystroke injection")
    t0 = time.time()
    try:
        test_str = f"eval_{int(time.time()) % 10000}"
        subprocess.run(["pbcopy"], input=test_str.encode(), capture_output=True, check=True)
        time.sleep(0.05)
        result = subprocess.run(
            ["osascript", "-e", 'tell application "System Events" to keystroke "v" using command down'],
            capture_output=True, timeout=5,
        )
        if result.returncode == 0:
            c.passed = True
            c.detail = f"pasted '{test_str}' into focused app"
        else:
            c.detail = result.stderr.decode().strip()
    except Exception as e:
        c.detail = str(e)
    c.dt_ms = (time.time() - t0) * 1000
    return c


def run_checks(model_size: str = "tiny.en", include_injection: bool = False) -> list[Check]:
    checks = [
        lambda: check_microphone(),
        lambda: check_whisper(model_size),
        lambda: check_vad(),
        lambda: check_clipboard(),
        lambda: check_system_events(),
        lambda: check_accessibility(),
    ]
    if include_injection:
        checks.append(lambda: check_injection())

    results = []
    for fn in checks:
        result = fn()
        print(result)
        results.append(result)

    return results


def main():
    include_injection = "--inject" in sys.argv

    print("\n=== SayType Health Check ===\n")

    if include_injection:
        print("  WARNING: --inject will type into the focused app in 3s!")
        print("  Click on a text editor or terminal now.\n")
        time.sleep(3)

    results = run_checks(include_injection=include_injection)

    passed = sum(1 for r in results if r.passed)
    total = len(results)
    print(f"\n  Result: {passed}/{total} passed\n")

    failed = [r for r in results if not r.passed]
    if failed:
        print("  Failed checks:")
        for r in failed:
            print(f"    - {r.name}: {r.detail}")
        print()
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
