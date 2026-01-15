from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict

from PySide6.QtCore import QObject, Property, Signal, Slot, QStandardPaths


def _app_data_dir() -> Path:
    base = QStandardPaths.writableLocation(QStandardPaths.AppDataLocation)
    p = Path(base)
    p.mkdir(parents=True, exist_ok=True)
    return p


class SettingsStore(QObject):
    # notify signals
    fontSizeChanged = Signal()
    shortcutNewChanged = Signal()
    shortcutOpenChanged = Signal()
    shortcutSaveChanged = Signal()
    shortcutSaveAsChanged = Signal()
    themeChanged = Signal()

    # optional signal if you want to debug
    loaded = Signal()
    saved = Signal()

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)

        self._path = _app_data_dir() / "userSettings.json"

        # defaults
        self._font_size = 11
        self._theme = "Dark"   # Dark | White | Purple

        self._shortcut_new = "Ctrl+N"
        self._shortcut_open = "Ctrl+O"
        self._shortcut_save = "Ctrl+S"
        self._shortcut_save_as = "Ctrl+Shift+S"

        self.load()

    # ---------- file i/o ----------
    def _to_dict(self) -> Dict[str, Any]:
        return {
            "fontSize": int(self._font_size),
            "theme": self._theme,
            "shortcuts": {
                "new": self._shortcut_new,
                "open": self._shortcut_open,
                "save": self._shortcut_save,
                "saveAs": self._shortcut_save_as,
            },
        }

    def _apply_dict(self, data: Dict[str, Any]) -> None:
        fs = data.get("fontSize", self._font_size)
        sc = data.get("shortcuts", {})

        self.setFontSize(int(fs))
        self.setTheme(str(data.get("theme")))
        self.setShortcutNew(str(sc.get("new", self._shortcut_new)))
        self.setShortcutOpen(str(sc.get("open", self._shortcut_open)))
        self.setShortcutSave(str(sc.get("save", self._shortcut_save)))
        self.setShortcutSaveAs(str(sc.get("saveAs", self._shortcut_save_as)))

    @Slot()
    def load(self) -> None:
        if not self._path.exists():
            # first run: write defaults
            self.save()
            self.loaded.emit()
            return

        try:
            data = json.loads(self._path.read_text(encoding="utf-8"))
            if isinstance(data, dict):
                self._apply_dict(data)
        except Exception:
            # if file is corrupted, keep defaults and rewrite
            self.save()

        self.loaded.emit()

    @Slot()
    def save(self) -> None:
        try:
            self._path.write_text(
                json.dumps(self._to_dict(), indent=2, ensure_ascii=False),
                encoding="utf-8",
            )
        finally:
            self.saved.emit()

    # ---------- normalization helper ----------
    @Slot(str, result=str)
    def normalizeSequence(self, seq: str) -> str:
        if not seq:
            return ""
        s = "".join(str(seq).split())  # remove spaces
        # normalize common modifier casing
        s = s.replace("CTRL", "Ctrl").replace("ctrl", "Ctrl")
        s = s.replace("SHIFT", "Shift").replace("shift", "Shift")
        s = s.replace("ALT", "Alt").replace("alt", "Alt")
        s = s.replace("META", "Meta").replace("meta", "Meta")
        return s

    # ---------- properties ----------
    def getFontSize(self) -> int:
        return self._font_size

    def setFontSize(self, v: int) -> None:
        v = int(v)
        if v == self._font_size:
            return
        self._font_size = v
        self.fontSizeChanged.emit()
        self.save()

    fontSize = Property(int, getFontSize, setFontSize, notify=fontSizeChanged)

    def getTheme(self) -> str:
        return self._theme

    def setTheme(self, v: str) -> None:
        v = str(v)
        if v == self._theme:
            return
        self._theme = v
        self.themeChanged.emit()
        self.save()

    theme = Property(str, getTheme, setTheme, notify=themeChanged)

    def getShortcutNew(self) -> str:
        return self._shortcut_new

    def setShortcutNew(self, v: str) -> None:
        v = self.normalizeSequence(v)
        if v == self._shortcut_new:
            return
        self._shortcut_new = v
        self.shortcutNewChanged.emit()
        self.save()

    shortcutNew = Property(str, getShortcutNew, setShortcutNew, notify=shortcutNewChanged)

    def getShortcutOpen(self) -> str:
        return self._shortcut_open

    def setShortcutOpen(self, v: str) -> None:
        v = self.normalizeSequence(v)
        if v == self._shortcut_open:
            return
        self._shortcut_open = v
        self.shortcutOpenChanged.emit()
        self.save()

    shortcutOpen = Property(str, getShortcutOpen, setShortcutOpen, notify=shortcutOpenChanged)

    def getShortcutSave(self) -> str:
        return self._shortcut_save

    def setShortcutSave(self, v: str) -> None:
        v = self.normalizeSequence(v)
        if v == self._shortcut_save:
            return
        self._shortcut_save = v
        self.shortcutSaveChanged.emit()
        self.save()

    shortcutSave = Property(str, getShortcutSave, setShortcutSave, notify=shortcutSaveChanged)

    def getShortcutSaveAs(self) -> str:
        return self._shortcut_save_as

    def setShortcutSaveAs(self, v: str) -> None:
        v = self.normalizeSequence(v)
        if v == self._shortcut_save_as:
            return
        self._shortcut_save_as = v
        self.shortcutSaveAsChanged.emit()
        self.save()

    shortcutSaveAs = Property(
        str, getShortcutSaveAs, setShortcutSaveAs, notify=shortcutSaveAsChanged
    )

    # Optional: expose the file path for debugging in QML if you want
    @Property(str, constant=True)
    def settingsPath(self) -> str:
        return str(self._path)
