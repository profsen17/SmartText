from __future__ import annotations

from PySide6.QtCore import QAbstractListModel, QModelIndex, Qt

from ..core.document import Document


class TabsModel(QAbstractListModel):
    TitleRole = Qt.UserRole + 1
    ModifiedRole = Qt.UserRole + 2

    def __init__(self) -> None:
        super().__init__()
        self._docs: list[Document] = []

    def rowCount(self, parent=QModelIndex()) -> int:
        return 0 if parent.isValid() else len(self._docs)

    def data(self, index: QModelIndex, role: int):
        if not index.isValid():
            return None
        i = index.row()
        if i < 0 or i >= len(self._docs):
            return None
        doc = self._docs[i]
        if role == self.TitleRole:
            return doc.title
        if role == self.ModifiedRole:
            return doc.modified
        return None

    def roleNames(self):
        return {
            self.TitleRole: b"title",
            self.ModifiedRole: b"modified",
        }

    # ---- helpers used by controller ----
    def docs(self) -> list[Document]:
        return self._docs

    def add_doc(self, doc: Document) -> int:
        row = len(self._docs)
        self.beginInsertRows(QModelIndex(), row, row)
        self._docs.append(doc)
        self.endInsertRows()
        return row

    def remove_doc(self, row: int) -> None:
        if row < 0 or row >= len(self._docs):
            return
        self.beginRemoveRows(QModelIndex(), row, row)
        self._docs.pop(row)
        self.endRemoveRows()

    def update_row(self, row: int) -> None:
        if row < 0 or row >= len(self._docs):
            return
        idx = self.index(row, 0)
        self.dataChanged.emit(idx, idx, [self.TitleRole, self.ModifiedRole])

    def reset(self, docs: list[Document]) -> None:
        self.beginResetModel()
        self._docs = docs
        self.endResetModel()

