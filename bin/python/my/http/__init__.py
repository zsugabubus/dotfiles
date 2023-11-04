from http.server import SimpleHTTPRequestHandler
from http import HTTPStatus
import http.server
import io
import os
import socketserver


class MyTCPServer(socketserver.TCPServer):
    def __init__(self, *args, **kwargs):
        self.allow_reuse_address = True
        super().__init__(*args, **kwargs)


class MyHTTPRequestHandler(SimpleHTTPRequestHandler):
    BUFFER_SIZE = 1 << 16
    PLAYLIST_FILENAME = "index.m3u"

    def end_headers(self):
        # Just overwrite end_headers with no-op.
        pass

    def send_head(self):
        path = self.translate_path(self.path)

        dirname, filename = os.path.split(path)
        if filename == self.PLAYLIST_FILENAME:
            f = self.list_playlist(dirname)
        else:
            f = super().send_head()

        try:
            size = len(f.getbuffer())
        except AttributeError:
            try:
                size = os.fstat(f.fileno()).st_size
            except AttributeError:
                size = 0

        self.source_start = None
        self.source_end = None

        if hdr := self.headers.get("Range"):
            start, end = hdr.strip().strip("bytes=").split(",")[0].split("-")

            start = int(start) if start else None
            end = int(end) if end else None

            if start is None and end is not None:
                start = size - end
                end = size

            if start is None:
                start = 0

            if end is None:
                end = size

            if end != size:
                self.source_start = start
                self.source_end = end
            elif start != 0:
                self.source_start = start

            self.send_header("Content-Range", "bytes %s-%s/%s" % (start, end, size))
            self.send_header("Content-Length", str(end - start))

        super().end_headers()
        return f

    def copyfile(self, source, outputfile):
        if self.source_start is not None:
            source.seek(self.source_start)

            if self.source_end is not None:
                for chunk_start in range(
                    self.source_start, self.source_end, self.BUFFER_SIZE
                ):
                    chunk_end = min(self.source_end, chunk_start + self.BUFFER_SIZE)
                    buf = source.read(self.BUFFER_SIZE)
                    if not buf:
                        break
                    outputfile.write(buf)
                return

        super().copyfile(source, outputfile)

    def list_playlist(self, path):
        try:
            list = os.listdir(path)
        except OSError:
            self.send_error(HTTPStatus.NOT_FOUND, "No permission to list directory")
            return None
        list.sort(key=lambda a: a.lower())

        f = io.BytesIO()
        f.write("\n".join(list).encode("utf-8"))
        f.seek(0)
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-type", "application/x-mpegurl; charset=utf-8")
        self.send_header("Content-Length", str(len(f.getbuffer())))
        self.end_headers()
        return f

    def translate_path(self, path):
        if self.only_path:
            return self.only_path
        return super().translate_path(path)


def run_server(addr, /, only_path):
    path = only_path

    class RequestHandler(MyHTTPRequestHandler):
        nonlocal path
        only_path = path

    with MyTCPServer(addr, RequestHandler) as httpd:
        print("Listening on %s:%d" % (httpd.server_address))
        httpd.serve_forever()
