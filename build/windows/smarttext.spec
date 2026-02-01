# -*- mode: python ; coding: utf-8 -*-

from pathlib import Path
from PyInstaller.utils.hooks import collect_all

# SPECPATH = directory containing this spec file (build/windows)
ROOT = Path(SPECPATH).resolve().parents[1]

# Collect EVERYTHING needed for PySide6 (Qt, plugins, DLLs, etc.)
pyside6_datas, pyside6_binaries, pyside6_hiddenimports = collect_all("PySide6")

datas = [
    (str(ROOT / "src" / "smarttext" / "qml"), "qml"),
] + pyside6_datas

binaries = pyside6_binaries
hiddenimports = pyside6_hiddenimports

a = Analysis(
    [str(ROOT / "src" / "smarttext" / "main.py")],
    pathex=[str(ROOT / "src")],
    binaries=binaries,
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name="SmartText",
    console=False,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    name="SmartText",
)
