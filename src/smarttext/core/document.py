from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


@dataclass
class Document:
    text: str = ""
    path: Path | None = None
    modified: bool = False

    # ✅ remember caret per file
    cursor_pos: int = 0

    @property
    def title(self) -> str:
        return self.path.name if self.path else "Untitled"

    def set_text(self, text: str) -> None:
        self.text = text
        self.modified = True
