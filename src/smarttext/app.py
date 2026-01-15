from __future__ import annotations

from pathlib import Path
from PySide6.QtCore import QUrl, QCoreApplication
from PySide6.QtQml import QQmlApplicationEngine

from .bridge.app_controller import AppController
from .core.settings_store import SettingsStore


def bootstrap(engine: QQmlApplicationEngine) -> None:
    # Controllers
    engine._app_controller = AppController()
    engine._settings_store = SettingsStore()

    # Expose to QML
    engine.rootContext().setContextProperty("app", engine._app_controller)
    engine.rootContext().setContextProperty("settingsStore", engine._settings_store)

    # Save session on exit
    QCoreApplication.instance().aboutToQuit.connect(
        engine._app_controller.save_session
    )

    # Load QML
    qml_path = Path(__file__).resolve().parent / "qml" / "Main.qml"
    engine.load(QUrl.fromLocalFile(str(qml_path)))
