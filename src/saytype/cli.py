"""SayType CLI — start, check, setup."""

import argparse
import sys


def cmd_start(args):
    """Launch the menu bar app."""
    from saytype.app import main
    main(model_size=args.model)


def cmd_check(args):
    """Run health checks."""
    from saytype.check import run_checks

    print("\n=== SayType Health Check ===\n")

    if args.inject:
        import time
        print("  WARNING: --inject will type into the focused app in 3s!")
        print("  Click on a text editor or terminal now.\n")
        time.sleep(3)

    results = run_checks(model_size=args.model, include_injection=args.inject)

    passed = sum(1 for r in results if r.passed)
    total = len(results)
    print(f"\n  Result: {passed}/{total} passed\n")

    failed = [r for r in results if not r.passed]
    if failed:
        print("  Failed checks:")
        for r in failed:
            print(f"    - {r.name}: {r.detail}")
        print()
        sys.exit(1)


def cmd_setup(args):
    """First-run setup: download model, create .app, check permissions."""
    import os
    import time

    print("\n  SayType — Voice Dictation for macOS")
    print("  ====================================\n")

    # Step 1: System check
    print("  Step 1/4: System Check")
    py_version = f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}"
    print(f"    Python {py_version} ({sys.executable})  OK")

    import platform
    mac_ver = platform.mac_ver()[0]
    arch = platform.machine()
    print(f"    macOS {mac_ver} ({arch})  OK")
    print()

    # Step 2: Choose model
    print("  Step 2/4: Choose Whisper Model")
    print("    Models determine transcription quality vs speed:")
    print("      tiny.en   ~75MB   - Fast, good for commands (recommended)")
    print("      small     ~500MB  - Better accuracy, slight delay")
    print("      medium    ~1.5GB  - Best accuracy, noticeable delay")
    print()

    model = args.model
    if not model:
        model = input("    Choose model [tiny.en]: ").strip() or "tiny.en"
        if model not in ("tiny.en", "small", "medium"):
            print(f"    Unknown model '{model}', using tiny.en")
            model = "tiny.en"
    print(f"    Selected: {model}")
    print()

    # Step 3: Download model
    print("  Step 3/4: Download Model")
    print(f"    Downloading {model}...", end="", flush=True)
    try:
        from faster_whisper import WhisperModel
        WhisperModel(model, device="cpu", compute_type="int8")
        print(" done")
    except Exception as e:
        print(f" FAILED: {e}")
        sys.exit(1)
    print()

    # Step 4: Permissions
    print("  Step 4/4: Permissions")

    from saytype.keys import is_accessibility_trusted
    ax = is_accessibility_trusted()
    if ax:
        print("    Accessibility: GRANTED")
    else:
        print("    Accessibility: NOT GRANTED")
        print("      -> System Settings > Privacy & Security > Accessibility")
        print("      -> Add SayType.app or your terminal")
    print("    Microphone: will be prompted on first launch")
    print()

    print("  Setup complete! Run: saytype start")
    print("  Run 'saytype check' anytime to verify everything works.\n")


def main():
    parser = argparse.ArgumentParser(
        prog="saytype",
        description="SayType — Voice-to-text for macOS. Speak and it types.",
    )
    sub = parser.add_subparsers(dest="command")

    # start
    p_start = sub.add_parser("start", help="Launch the menu bar app")
    p_start.add_argument("--model", default="tiny.en", choices=["tiny.en", "small", "medium"])

    # check
    p_check = sub.add_parser("check", help="Run health checks")
    p_check.add_argument("--inject", action="store_true", help="Test live keystroke injection")
    p_check.add_argument("--model", default="tiny.en", choices=["tiny.en", "small", "medium"])

    # setup
    p_setup = sub.add_parser("setup", help="First-run setup")
    p_setup.add_argument("--model", default="", help="Skip model prompt")

    args = parser.parse_args()

    if args.command == "start":
        cmd_start(args)
    elif args.command == "check":
        cmd_check(args)
    elif args.command == "setup":
        cmd_setup(args)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
