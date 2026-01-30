from __future__ import annotations

from PySide6.QtCore import QObject, Signal, QByteArray, QDataStream, QIODevice
from PySide6.QtNetwork import QLocalServer, QLocalSocket


class SingleInstance(QObject):
    messageReceived = Signal(str)

    def __init__(self, server_name: str, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self.server_name = server_name
        self.server = QLocalServer(self)

    def is_primary_running(self, timeout_ms: int = 150) -> bool:
        sock = QLocalSocket()
        sock.connectToServer(self.server_name)
        ok = sock.waitForConnected(timeout_ms)
        if ok:
            sock.disconnectFromServer()
        return ok

    def become_primary(self) -> bool:
        # 1) Try to listen normally
        if self.server.listen(self.server_name):
            self.server.newConnection.connect(self._on_new_connection)
            return True

        # 2) If listen failed, check if a real primary is running
        if self.is_primary_running():
            return False  # real primary exists => we're secondary

        # 3) Otherwise it's stale (crash leftover): remove & retry
        QLocalServer.removeServer(self.server_name)
        if self.server.listen(self.server_name):
            self.server.newConnection.connect(self._on_new_connection)
            return True

        return False

    def send_message(self, text: str, timeout_ms: int = 800) -> bool:
        sock = QLocalSocket()
        sock.connectToServer(self.server_name)
        if not sock.waitForConnected(timeout_ms):
            return False

        payload = QByteArray()
        ds = QDataStream(payload, QIODevice.WriteOnly)
        ds.writeQString(text)

        sock.write(payload)
        sock.flush()
        sock.waitForBytesWritten(timeout_ms)
        sock.disconnectFromServer()
        return True

    def _on_new_connection(self) -> None:
        sock = self.server.nextPendingConnection()
        if not sock:
            return

        def read_and_emit() -> None:
            ds = QDataStream(sock)
            msg = ds.readQString()
            self.messageReceived.emit(msg)
            sock.disconnectFromServer()
            sock.deleteLater()

        sock.readyRead.connect(read_and_emit)
    
    @staticmethod
    def primary_running(server_name: str, timeout_ms: int = 120) -> bool:
        sock = QLocalSocket()
        sock.connectToServer(server_name)
        ok = sock.waitForConnected(timeout_ms)
        if ok:
            sock.disconnectFromServer()
        return ok
