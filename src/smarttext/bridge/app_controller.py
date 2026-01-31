from __future__ import annotations

from pathlib import Path
from PySide6.QtCore import QObject, Signal, Slot, Property, QCoreApplication, QUrl

from ..core.document import Document
from .tabs_model import TabsModel
from .session_store import SessionStore


class AppController(QObject):
    documentTitleChanged = Signal()
    textChanged = Signal()
    modifiedChanged = Signal()
    statusMessageChanged = Signal()
    currentIndexChanged = Signal()
    cursorPositionChanged = Signal()
    scrollYChanged = Signal()

    # requests to QML
    requestSaveAs = Signal()
    def __init__(self) -> None:
        super().__init__()

        self._tabs = TabsModel()
        self._session = SessionStore()
        self._current_index = 0
        self._status_message = "Ready"
        self._reset_session_on_exit = False

        restored = self._session.load()
        self._restored_session = bool(restored)  # <--- add this

        if restored:
            docs, index = restored
            self._tabs.reset(docs)
            self._current_index = index
        else:
            self._tabs.add_doc(Document())
            self._current_index = 0

    def _is_pristine_placeholder(self) -> bool:
        if self._restored_session:
            return False
        if self._tabs.count() != 1:
            return False
        d = self._tabs.doc_at(0)
        return (d.path is None) and (not d.modified) and (d.text == "")

    def _find_pristine_placeholder_index(self) -> int | None:
        for i in range(self._tabs.count()):
            d = self._tabs.doc_at(i)
            if d.path is None and (not d.modified) and d.text == "":
                return i
        return None


    # -------------------------
    # Helpers
    # -------------------------
    def _to_path(self, file_url_or_path: str) -> Path | None:
        if not file_url_or_path:
            return None
        if file_url_or_path.startswith("file:"):
            return Path(QUrl(file_url_or_path).toLocalFile())
        return Path(file_url_or_path)

    def _set_status(self, msg: str) -> None:
        if msg == self._status_message:
            return
        self._status_message = msg
        self.statusMessageChanged.emit()

    def _current_doc(self) -> Document:
        if self._current_index < 0 or self._current_index >= self._tabs.count():
            if self._tabs.count() == 0:
                self._tabs.add_doc(Document())
            self._current_index = 0
        return self._tabs.doc_at(self._current_index)

    def _sync_current_to_qml(self) -> None:
        self.currentIndexChanged.emit()
        self.textChanged.emit()
        self.modifiedChanged.emit()
        self.documentTitleChanged.emit()
        self.cursorPositionChanged.emit()
        self.scrollYChanged.emit()

    def _open_new_tab(self, doc: Document) -> None:
        new_row = self._tabs.add_doc(doc)
        self.set_current_index(new_row)

    def _norm_path(self, p: Path) -> Path:
        """Normalize a path for comparisons (best-effort resolve)."""
        try:
            # strict=False avoids errors for odd paths; still normalizes '..' etc
            return p.expanduser().resolve(strict=False)
        except Exception:
            return p.expanduser().absolute()

    def _find_open_path_index(self, path: Path) -> int | None:
        """Return tab index if a doc with this path is already open."""
        target = self._norm_path(path)
        for i in range(self._tabs.count()):
            d = self._tabs.doc_at(i)
            if d.path is None:
                continue
            if self._norm_path(d.path) == target:
                return i
        return None

    # -------------------------
    # Exposed properties
    # -------------------------
    def get_status_message(self) -> str:
        return self._status_message

    statusMessage = Property(str, get_status_message, notify=statusMessageChanged)

    def get_current_index(self) -> int:
        return self._current_index

    @Slot(int)
    def set_current_index(self, index: int) -> None:
        if index < 0 or index >= self._tabs.count():
            return
        if index == self._current_index:
            return
        self._current_index = index
        self._sync_current_to_qml()

    currentIndex = Property(int, get_current_index, notify=currentIndexChanged)

    def get_document_title(self) -> str:
        # IMPORTANT: title comes from current doc, not self._doc
        return self._current_doc().title

    documentTitle = Property(str, get_document_title, notify=documentTitleChanged)

    def get_text(self) -> str:
        return self._current_doc().text

    def set_text(self, value: str) -> None:
        doc = self._current_doc()
        if value == doc.text:
            return
        doc.set_text(value)
        self.textChanged.emit()
        self.modifiedChanged.emit()
        self.documentTitleChanged.emit()
        self._tabs.update_row(self._current_index)

    text = Property(str, get_text, set_text, notify=textChanged)

    def get_modified(self) -> bool:
        return self._current_doc().modified

    modified = Property(bool, get_modified, notify=modifiedChanged)

    # If your TabsModel is used directly in QML:
    def get_tabs_model(self) -> QObject:
        return self._tabs

    tabsModel = Property(QObject, get_tabs_model, constant=True)

    def get_cursor_position(self) -> int:
        return int(self._current_doc().cursor_pos)

    cursorPosition = Property(int, get_cursor_position, notify=cursorPositionChanged)

    def get_scroll_y(self) -> float:
        return float(self._current_doc().scroll_y)

    # -------------------------
    # Slots callable from QML
    # -------------------------
    @Slot()
    def new_file(self) -> None:
        self._open_new_tab(Document())
        self._set_status("New file")

    @Slot(str)
    def open_file(self, file_url_or_path: str) -> None:
        path = self._to_path(file_url_or_path)
        if not path or not path.exists():
            self._set_status("Open cancelled / file not found")
            return

        # ✅ If already open, just switch to that tab
        existing_i = self._find_open_path_index(path)
        if existing_i is not None:
            self.set_current_index(existing_i)
            self._set_status(f"Already open: {path.name}")
            return

        # Otherwise load from disk
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            text = path.read_text(encoding="utf-8", errors="replace")

        opened_doc = Document(text=text, path=self._norm_path(path), modified=False)
        opened_doc.cursor_pos = 0

        placeholder_i = self._find_pristine_placeholder_index()
        if placeholder_i is not None:
            self._tabs.set_doc(placeholder_i, opened_doc)
            self.set_current_index(placeholder_i)
        else:
            self._open_new_tab(opened_doc)

        self._set_status(f"Opened: {path.name}")

    @Slot()
    def save(self) -> None:
        doc = self._current_doc()

        # Save behaves like Save As if no path yet
        if doc.path is None:
            self._set_status("Choose a location to save…")
            self.requestSaveAs.emit()
            return

        doc.path.parent.mkdir(parents=True, exist_ok=True)
        doc.path.write_text(doc.text, encoding="utf-8")

        doc.modified = False
        self._tabs.update_row(self._current_index)

        self.modifiedChanged.emit()
        self.documentTitleChanged.emit()
        self._set_status(f"Saved: {doc.path.name}")

    @Slot(str)
    def save_as(self, file_url_or_path: str) -> None:
        path = self._to_path(file_url_or_path)
        if not path:
            self._set_status("Save cancelled")
            return

        doc = self._current_doc()
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(doc.text, encoding="utf-8")

        doc.path = path
        doc.modified = False
        self._tabs.update_row(self._current_index)

        self.modifiedChanged.emit()
        self.documentTitleChanged.emit()
        self._set_status(f"Saved: {path.name}")

    @Slot(int)
    def close_tab(self, index: int) -> None:
        if self._tabs.count() <= 1:
            self._reset_session_on_exit = True
            QCoreApplication.quit()
            return

        self._tabs.remove_doc(index)

        if index == self._current_index:
            self._current_index = min(index, self._tabs.count() - 1)
            self._sync_current_to_qml()
        elif index < self._current_index:
            self._current_index -= 1
            self.currentIndexChanged.emit()

    @Slot(int)
    def set_cursor_position(self, pos: int) -> None:
        doc = self._current_doc()
        # clamp to text length so it never breaks
        pos = max(0, min(int(pos), len(doc.text)))
        if doc.cursor_pos == pos:
            return
        doc.cursor_pos = pos
        self.cursorPositionChanged.emit()

    @Slot(float)
    def set_scroll_y(self, y: float) -> None:
        doc = self._current_doc()
        y = max(0.0, float(y))
        if doc.scroll_y == y:
            return
        doc.scroll_y = y
        self.scrollYChanged.emit()

    scrollY = Property(float, get_scroll_y, notify=scrollYChanged)

    # -------------------------
    # Session
    # -------------------------

    def save_session(self) -> None:
        if self._reset_session_on_exit:
            self._session.save([Document()], 0)
            return
        self._session.save(self._tabs.docs(), self._current_index)
