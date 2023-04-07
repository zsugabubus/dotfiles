import json
import socket


class MpvClient:
	class _CommandProxy:
		def __init__(self, client: "MpvClient", arg0: str, /):
			self.client = client
			self.arg0 = arg0

		def __call__(self, *args):
			request_id = self.client._send_request([self.arg0, *args])
			return self.client._get_response(request_id)

	def __init__(self, path, /):
		self.path = path

	def __enter__(self):
		self.connect()
		return self

	def __exit__(self, *args):
		self.close()

	def __getattr__(self, key, /):
		return self._CommandProxy(self, key)

	def connect(self):
		if self.path is str:
			self.socket = socket.socket(socket.AF_UNIX)
			self.socket.connect(self.path)
		else:
			self.socket = self.path
		self.rx = self.socket.makefile("r")
		self.tx = self.socket.makefile("w")
		self.request_id = 0

	def close(self):
		self.socket.close()

	def wait_event(self, name: str):
		msg = self._read_message()
		if msg["event"] == name:
			return

	def _send_request(self, command, /):
		self.request_id += 1
		payload = {
			"request_id": self.request_id,
			"command": command,
		}
		self.tx.write(json.dumps(payload) + "\n")
		self.tx.flush()
		return self.request_id

	def _get_response(self, request_id: int, /):
		while True:
			msg = self._read_message()
			if "request_id" not in msg:
				continue

			assert msg["request_id"] <= request_id
			if msg["request_id"] == request_id:
				if msg["error"] != "success":
					raise ValueError(msg["error"])
				return msg.get("data")

	def _read_message(self):
		return json.loads(self.rx.readline())
