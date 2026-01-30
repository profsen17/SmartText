from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, List

from PySide6.QtCore import QObject, QStandardPaths

from ..core.document import Document


def _app_data_dir() -> Path:
    base = QStandardPaths.writableLocation(QStandardPaths.AppDataLocation)
    p = Path(base)
    p.mkdir(parents=True, exist_ok=True)
    return p


class SessionStore(QObject):
    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._path = _app_data_dir() / "session.json"

    # ---------- SAVE ----------
    def save(self, docs: List[Document], current_index: int) -> None:
        data = {
            "currentIndex": current_index,
            "tabs": [
                # session_store.py inside tabs list
                {
                    "path": str(doc.path) if doc.path else None,
                    "text": doc.text,
                    "modified": doc.modified,
                    "cursorPos": doc.cursor_pos,
                    "scrollY": doc.scroll_y,
                }
                for doc in docs
            ],
        }

        self._path.write_text(
            json.dumps(data, indent=2, ensure_ascii=False),
            encoding="utf-8",
        )

    # ---------- LOAD ----------
    def load(self) -> tuple[list[Document], int] | None:
        if not self._path.exists():
            return None

        try:
            data = json.loads(self._path.read_text(encoding="utf-8"))
        except Exception:
            return None

        docs: list[Document] = []

        for t in data.get("tabs", []):
            text = t.get("text", "")

            pos = int(t.get("cursorPos", 0))
            pos = max(0, min(pos, len(text)))

            scroll_y = float(t.get("scrollY", 0.0))
            if scroll_y < 0:
                scroll_y = 0.0

            docs.append(
                Document(
                    text=text,
                    path=Path(t["path"]) if t.get("path") else None,
                    modified=bool(t.get("modified", False)),
                    cursor_pos=pos,
                    scroll_y=scroll_y,
                )
            )

        if not docs:
            return None

        current_index = int(data.get("currentIndex", 0))
        current_index = max(0, min(current_index, len(docs) - 1))

        return docs, current_index
