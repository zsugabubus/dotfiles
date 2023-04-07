from mpv import MpvServer
import pytest


@pytest.fixture(scope="module")
def mpv_server_args():
	return [
		"--no-config",
		"--ao=null",
		"--vo=null",
	]


@pytest.fixture
def mpv_server(mpv_server_args):
	with MpvServer(mpv_server_args) as s:
		yield s


@pytest.fixture
def mp(mpv_server):
	mpv_server.client.wait_event("idle")
	return mpv_server.client


@pytest.fixture
def playlist(mp):
	def inner(prop: str = "filename"):
		from time import sleep

		sleep(0.5) # WTF?
		return [e[prop] for e in mp.get_property("playlist")]

	return inner


@pytest.fixture
def appendfiles(mp):
	def inner(files: [str]):
		for f in files:
			mp.loadfile(f, "append")

	return inner


@pytest.fixture
def loadfiles(mp, appendfiles):
	def inner(*args):
		mp.playlist_clear()
		return appendfiles(*args)

	return inner
