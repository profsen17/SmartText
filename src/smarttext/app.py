from __future__ import annotations

import sys
from pathlib import Path
from PySide6.QtCore import QUrl, QCoreApplication
from PySide6.QtQml import QQmlApplicationEngine

from .bridge.app_controller import AppController
from .core.settings_store import SettingsStore


def _resource_path(rel: str) -> Path:
    """
    Works both in dev (source tree) and in PyInstaller one-folder builds.
    """
    if getattr(sys, "frozen", False) and hasattr(sys, "_MEIPASS"):
        return Path(sys._MEIPASS) / rel  # type: ignore[attr-defined]
    return Path(__file__).resolve().parent / rel


def bootstrap(engine: QQmlApplicationEngine) -> None:
    # Controllers
    engine._app_controller = AppController()
    engine._settings_store = SettingsStore()

    # Expose to QML
    engine.rootContext().setContextProperty("app", engine._app_controller)
    engine.rootContext().setContextProperty("settingsStore", engine._settings_store)

    # Save session on exit
    QCoreApplication.instance().aboutToQuit.connect(engine._app_controller.save_session)

    # Load QML (frozen-safe)
    qml_path = _resource_path("qml/Main.qml")
    engine.load(QUrl.fromLocalFile(str(qml_path)))
