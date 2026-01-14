from __future__ import annotations

from pathlib import Path

from PySide6.QtCore import QUrl
from PySide6.QtQml import QQmlApplicationEngine

from .bridge.app_controller import AppController
from .core.settings_store import SettingsStore


def bootstrap(engine: QQmlApplicationEngine) -> None:
    engine._settings = SettingsStore()            # keep strong ref
    engine._app_controller = AppController()      # keep strong ref

    ctx = engine.rootContext()
    ctx.setContextProperty("settingsStore", engine._settings)  # ✅ renamed
    ctx.setContextProperty("app", engine._app_controller)

    qml_path = Path(__file__).resolve().parent / "qml" / "Main.qml"
    engine.load(QUrl.fromLocalFile(str(qml_path)))
