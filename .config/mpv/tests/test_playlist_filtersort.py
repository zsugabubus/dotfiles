import pytest


@pytest.fixture(scope="module", autouse=True)
def my_script(mpv_server_args):
	import os.path

	script_file = os.path.expanduser(
		"~/.config/mpv/scripts/playlist-filtersort.lua",
	)
	mpv_server_args.extend(
		[
			"--script-opts=sort=none",
			f"--script={script_file}",
		]
	)


class TestSortBy:
	@pytest.fixture(autouse=True)
	def sort_by(self, mp):
		by = self.__class__.__name__[10:].lower()
		mp.set("script-opts", f"sort={by}")


class TestSortByNone(TestSortBy):
	def test_keeps_order_and_entries(self, mp, loadfiles, playlist):
		expected_playlist = [
			mp.loadfile(f, "append")["playlist_entry_id"]
			for f in [
				"z.mp3",
				"a.mp3",
				"z.mp3",
			]
		]
		assert playlist("id") == expected_playlist


class TestSortByName(TestSortBy):
	def test_ignores_dirname(self, loadfiles, playlist):
		loadfiles(
			[
				"a/z.mp3",
				"z/a.mp3",
				"a/z.mp3",
			]
		)
		assert playlist() == [
			"z/a.mp3",
			"a/z.mp3",
			"a/z.mp3",
		]

	def test_ignores_case(self, loadfiles, playlist):
		loadfiles(
			[
				"C.mp3",
				"A.mp3",
				"b.mp3",
			]
		)
		assert playlist() == [
			"A.mp3",
			"b.mp3",
			"C.mp3",
		]


class TestSortByPath(TestSortBy):
	def test_it_works(self, loadfiles, playlist):
		loadfiles(
			[
				"a/z.mp3",
				"A/z.mp3",
				"z/b.mp3",
				"z/a.mp3",
			]
		)
		assert playlist() == [
			"A/z.mp3",
			"a/z.mp3",
			"z/a.mp3",
			"z/b.mp3",
		]


class TestSortByAlpha(TestSortBy):
	def test_ignores_track_number(self, loadfiles, playlist):
		loadfiles(
			[
				"1. B.mp3",
				"2. C.mp3",
				"3. A.mp3",
			]
		)
		assert playlist() == [
			"3. A.mp3",
			"1. B.mp3",
			"2. C.mp3",
		]

	def test_uses_human_numeric_sort(self, loadfiles, playlist):
		loadfiles(
			[
				"a11 03.mp3",
				"a11 2.mp3",
				"a1.mp3",
			]
		)
		assert playlist() == [
			"a1.mp3",
			"a11 2.mp3",
			"a11 03.mp3",
		]


def test_sort_now_works(mp, loadfiles, appendfiles, playlist):
	loadfiles(["b", "c", "a"])
	mp.script_message("sort-now", "path")
	assert playlist() == ["a", "b", "c"]
	appendfiles(["0unsorted"])
	assert playlist() == ["a", "b", "c", "0unsorted"]


@pytest.mark.parametrize(
	"identifier",
	("sort", "sort-by", "playlist_filtersort-by"),
)
def test_runtime_option_update_works(identifier, mp, loadfiles, playlist):
	loadfiles(["b", "c", "d", "a"])
	mp.set("script-opts", f"{identifier}=path")
	assert playlist() == ["a", "b", "c", "d"]


def test_filter_works(loadfiles, playlist):
	loadfiles(
		[
			"a.TXT",
			"a.mkv",
			"a.Pdf",
			"a.rar",
		]
	)
	assert playlist() == [
		"a.mkv",
	]
