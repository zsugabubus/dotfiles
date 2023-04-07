from ._client import MpvClient
import socket
import subprocess


class MpvServer:
	def __init__(self, args: [str] = []):
		self._args = args

	def listen(self):
		(left, right) = socket.socketpair(socket.AF_UNIX)
		self.client = MpvClient(left)
		self.process = subprocess.Popen(
			[
				"mpv",
				f"--input-ipc-client=fd://{right.fileno()}",
				"--idle",
				*self._args,
			],
			pass_fds=(right.fileno(),),
		)

	def close(self):
		self.process.kill()

	def __enter__(self):
		self.listen()
		self.client = self.client.__enter__()
		return self

	def __exit__(self, *args):
		self.client.__exit__()
		self.close()
