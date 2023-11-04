#!/usr/bin/python3
import argparse
from os.path import join
from os import environ
from sys import stdout

import logging


class Keyring:
    filename = ".passss2"

    def __init__(self):
        self.manager = None

    def _load_manager(self):
        from ._utils import mountpoints
        from my.shamir import ShareManager

        manager = ShareManager()

        def add_file(path):
            try:
                with open(path) as f:
                    manager.parse_file(f)
            except (FileNotFoundError, OSError):
                pass
            except:
                logging.exception(f"File {path!r} contains corrupt data")

        def add_dir(path):
            add_file(join(path, self.filename))

        for path in mountpoints():
            add_dir(path)

        add_dir(environ["HOME"])
        return manager

    def retrieve_secret(self, token: str):
        from my.shamir import combine_shares

        if self.manager is None:
            self.manager = self._load_manager()

        shares = self.manager.get_shares_by_token(token)
        return combine_shares(shares)

    def retrieve_master_secret(self):
        return self.retrieve_secret(environ["USER"])

    def decrypt_gpg_file(self, path):
        import subprocess

        try:
            return subprocess.check_output(
                [
                    "/usr/bin/gpg",
                    "--batch",
                    "--quiet",
                    "--decrypt",
                    "--pinentry-mode=error",
                    path,
                ]
            )
        except subprocess.CalledProcessError as e:
            if e.returncode != 2:
                raise

            passphrase = self.retrieve_master_secret()
            return subprocess.check_output(
                [
                    "/usr/bin/gpg",
                    "--batch",
                    "--quiet",
                    "--decrypt",
                    "--pinentry-mode=loopback",
                    "--passphrase-fd",
                    "0",
                    path,
                ],
                input=passphrase,
            )


def decrypt_file(file, /):
    if file.endswith(".gpg"):
        keyring = Keyring()
        return keyring.decrypt_gpg_file(file)
    else:
        with open(file, "rb") as f:
            return f.read()


def magic(s):
    import re

    ret = []
    for line in s.splitlines():
        ret.append(line)
        if m := re.search(r"secret=([A-Za-z0-9]+)", line):
            (secret,) = m.groups()

            import my.otp

            ret.append(my.otp.totp(secret=secret))
    return "\n".join(ret)


def secret(*, token):
    keyring = Keyring()
    stdout.buffer.write(keyring.retrieve_secret(token))


def decrypt(*, file):
    stdout.buffer.write(decrypt_file(file))


def copy(*, file, to):
    import subprocess

    content = decrypt_file(file).decode("utf-8").splitlines()[0].encode("utf-8")

    try:
        match to:
            case "x11":
                subprocess.check_output(
                    [
                        "xclip",
                        "-i",
                        "-loops",
                        "1",
                    ],
                    input=content,
                )
            case "tmux":
                subprocess.check_output(
                    [
                        "tmux",
                        "load-buffer",
                        "-",
                    ],
                    input=content,
                )
            case "stdout":
                stdout.buffer.write(content)
            case _:
                raise ValueError
    except KeyboardInterrupt:
        pass


def view(*, file):
    import subprocess
    from tempfile import NamedTemporaryFile

    with NamedTemporaryFile(mode="w+t") as f:
        f.write(magic(decrypt_file(file).decode("utf-8")))
        f.flush()
        subprocess.run(["nvim", "-R", "--cmd", "set noundofile", "--", f.name])


def gen(*, length):
    import secrets
    import string

    chars = (
        string.ascii_lowercase
        + string.ascii_uppercase
        + string.digits
        + string.punctuation
    )
    print("".join([secrets.choice(chars) for _ in range(length)]))


parser = argparse.ArgumentParser(prog="pass", description="Password manager")

subparsers = parser.add_subparsers(metavar="COMMAND", required=True)

subparser = subparsers.add_parser(
    "secret", help="retrieve secret from keyring", aliases=["s"]
)
subparser.add_argument("token", metavar="TOKEN")
subparser.set_defaults(func=secret)

subparser = subparsers.add_parser("print", help="print secret file", aliases=["p"])
subparser.add_argument("file", metavar="FILE", default="-")
subparser.set_defaults(func=decrypt)

subparser = subparsers.add_parser("view", help="view secret file", aliases=["v"])
subparser.add_argument("file", metavar="FILE", default="-")
subparser.set_defaults(func=view)

subparser = subparsers.add_parser(
    "copy", help="copy first line of secret file", aliases=["c"]
)
subparser.add_argument("file", metavar="FILE", default="-")
subparser.add_argument(
    "-t", "--to", metavar="TO", choices=["x11", "tmux", "stdout"], default="x11"
)
subparser.set_defaults(func=copy)

subparser = subparsers.add_parser("password", help="generate password", aliases=["pw"])
subparser.add_argument("length", metavar="LENGTH", type=int, nargs="?", default=60)
subparser.set_defaults(func=gen)

args = parser.parse_args()
args = vars(args)
args.pop("func")(**args)
