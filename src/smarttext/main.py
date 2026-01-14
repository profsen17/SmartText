from __future__ import annotations

import sys
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

from .app import bootstrap


def main() -> int:
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()

    bootstrap(engine)

    if not engine.rootObjects():
        return 1
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
