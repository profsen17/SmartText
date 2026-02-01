from __future__ import annotations

import sys
from pathlib import Path

from PySide6.QtCore import QUrl, QTimer
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

from smarttext.app import bootstrap
from smarttext.bridge.single_instance import SingleInstance

SERVER_NAME = "SmartText.SingleInstance.v1"


def _argv_file_urls() -> list[str]:
    urls: list[str] = []
    for a in sys.argv[1:]:
        if not a or a.startswith("-"):
            continue
        p = Path(a).expanduser().resolve()
        urls.append(QUrl.fromLocalFile(str(p)).toString())
    return urls


def main() -> int:
    file_urls = _argv_file_urls()

    # ✅ If a primary is already running, forward and exit FAST (no GUI init)
    if SingleInstance.primary_running(SERVER_NAME):
        instance = SingleInstance(SERVER_NAME)
        for u in file_urls:
            instance.send_message(u)
        return 0

    # Only primary instance creates the GUI application
    app = QGuiApplication(sys.argv)

    QGuiApplication.setDesktopFileName("smarttext")

    instance = SingleInstance(SERVER_NAME)
    if not instance.become_primary():
        # rare race: primary appeared between checks
        for u in file_urls:
            instance.send_message(u)
        return 0

    engine = QQmlApplicationEngine()
    bootstrap(engine)

    if not engine.rootObjects():
        return 1

    def on_message(file_url: str) -> None:
        QTimer.singleShot(0, lambda: engine._app_controller.open_file(file_url))

        def activate_main() -> None:
            # Your main QML ApplicationWindow is the first root object
            roots = engine.rootObjects()
            if roots:
                win = roots[0]
                try:
                    # bring forward without "showing" other hidden windows
                    if hasattr(win, "raise_"):
                        win.raise_()
                    win.requestActivate()
                except Exception:
                    pass
                return

            # Fallback: activate any *visible* window
            for w in app.allWindows():
                if w.isVisible():
                    if hasattr(w, "raise_"):
                        w.raise_()
                    w.requestActivate()
                    break

        QTimer.singleShot(0, activate_main)

    instance.messageReceived.connect(on_message)

    # Open file(s) passed on first launch
    for u in file_urls:
        QTimer.singleShot(0, lambda u=u: engine._app_controller.open_file(u))

    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
