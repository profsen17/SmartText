from __future__ import annotations

from pathlib import Path

from PySide6.QtCore import QObject, Signal, Slot, Property

from ..core.document import Document


class AppController(QObject):
    # Signals to notify QML when properties change
    documentTitleChanged = Signal()
    textChanged = Signal()
    modifiedChanged = Signal()
    statusMessageChanged = Signal()

    def __init__(self) -> None:
        super().__init__()
        self._doc = Document()
        self._status_message = "Ready"

    # ----- Properties exposed to QML -----

    def get_document_title(self) -> str:
        return self._doc.title

    documentTitle = Property(str, get_document_title, notify=documentTitleChanged)

    def get_text(self) -> str:
        return self._doc.text

    def set_text(self, value: str) -> None:
        if value == self._doc.text:
            return
        self._doc.set_text(value)
        self.textChanged.emit()
        self.modifiedChanged.emit()
        self.documentTitleChanged.emit()

    text = Property(str, get_text, set_text, notify=textChanged)

    def get_modified(self) -> bool:
        return self._doc.modified

    modified = Property(bool, get_modified, notify=modifiedChanged)

    def get_status_message(self) -> str:
        return self._status_message

    statusMessage = Property(str, get_status_message, notify=statusMessageChanged)

    def _set_status(self, msg: str) -> None:
        if msg == self._status_message:
            return
        self._status_message = msg
        self.statusMessageChanged.emit()

    # ----- Slots callable from QML -----

    @Slot()
    def new_file(self) -> None:
        self._doc = Document()
        self._set_status("New file")
        self.textChanged.emit()
        self.modifiedChanged.emit()
        self.documentTitleChanged.emit()

    @Slot(str)
    def open_file(self, file_url_or_path: str) -> None:
        path = self._to_path(file_url_or_path)
        if not path or not path.exists():
            self._set_status("Open cancelled / file not found")
            return

        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            # Fallback if file isn't utf-8
            text = path.read_text(encoding="utf-8", errors="replace")

        self._doc = Document(text=text, path=path, modified=False)
        self._set_status(f"Opened: {path.name}")

        self.textChanged.emit()
        self.modifiedChanged.emit()
        self.documentTitleChanged.emit()

    @Slot(str)
    def save_as(self, file_url_or_path: str) -> None:
        path = self._to_path(file_url_or_path)
        if not path:
            self._set_status("Save cancelled")
            return

        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(self._doc.text, encoding="utf-8")

        self._doc.path = path
        self._doc.modified = False
        self._set_status(f"Saved: {path.name}")

        self.modifiedChanged.emit()
        self.documentTitleChanged.emit()

    @Slot()
    def save(self) -> None:
        if not self._doc.path:
            self._set_status("No path yet — use Save As")
            return
        self._doc.path.write_text(self._doc.text, encoding="utf-8")
        self._doc.modified = False
        self._set_status(f"Saved: {self._doc.path.name}")
        self.modifiedChanged.emit()
        self.documentTitleChanged.emit()

    # ----- Helpers -----

    def _to_path(self, file_url_or_path: str) -> Path | None:
        if not file_url_or_path:
            return None

        # QML FileDialog returns a URL like: file:///home/user/file.txt
        if file_url_or_path.startswith("file:"):
            from PySide6.QtCore import QUrl
            return Path(QUrl(file_url_or_path).toLocalFile())

        return Path(file_url_or_path)
