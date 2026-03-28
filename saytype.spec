# -*- mode: python ; coding: utf-8 -*-
"""PyInstaller spec for SayType.app"""

import os
import sys
from PyInstaller.utils.hooks import collect_data_files, collect_dynamic_libs

block_cipher = None

# Collect faster-whisper and ctranslate2 data/libs
datas = collect_data_files("faster_whisper")
binaries = collect_dynamic_libs("ctranslate2")

a = Analysis(
    ["src/saytype/app.py"],
    pathex=[],
    binaries=binaries,
    datas=datas + [
        ("src/saytype/resources/AppIcon.icns", "resources"),
        ("src/saytype/resources/Info.plist", "resources"),
    ],
    hiddenimports=[
        "saytype",
        "saytype.app",
        "saytype.engine",
        "saytype.keys",
        "saytype.check",
        "saytype.cli",
        "faster_whisper",
        "ctranslate2",
        "webrtcvad",
        "sounddevice",
        "numpy",
        "huggingface_hub",
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=["tkinter", "matplotlib", "scipy", "pandas", "PIL"],
    noarchive=False,
    cipher=block_cipher,
)

pyz = PYZ(a.pure, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name="SayType",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=False,
    target_arch=None,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=False,
    name="SayType",
)

app = BUNDLE(
    coll,
    name="SayType.app",
    icon="src/saytype/resources/AppIcon.icns",
    bundle_identifier="com.saytype.app",
    info_plist={
        "CFBundleName": "SayType",
        "CFBundleDisplayName": "SayType",
        "CFBundleVersion": "0.1.0",
        "CFBundleShortVersionString": "0.1.0",
        "LSUIElement": True,
        "NSMicrophoneUsageDescription": "SayType needs microphone access to transcribe your speech.",
        "NSHighResolutionCapable": True,
    },
)
