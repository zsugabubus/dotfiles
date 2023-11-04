#!/usr/bin/python3
import argparse
from sys import stdin, stdout
from os import environ
from os.path import join

from . import combine_shares, make_shares, ShareManager


def split(*, file, threshold, shares, token):
    plaintext = file.read()
    shares = make_shares(
        plaintext=plaintext, threshold=threshold, shares=shares, token=token
    )
    manager = ShareManager()
    manager.add_shares(shares)
    manager.print()


def combine(*, file, token):
    manager = ShareManager()
    manager.parse_file(file)
    shares = manager.get_shares_by_token(token)
    print_secret(combine_shares(shares).decode("UTF-8"))


def print_secret(secret: str, file=stdout):
    if secret and file.isatty():
        print(f"{secret[0]}*** (tty output obfuscated)", file=file)
    else:
        print(secret, file=file)


parser = argparse.ArgumentParser(
    prog="shamir", description="Shamir's secret share scheme"
)

subparsers = parser.add_subparsers(metavar="COMMAND", required=True)

subparser = subparsers.add_parser("split", help="split secret")
subparser.add_argument("-f", "--file", type=argparse.FileType("r"), default=stdin)
subparser.add_argument("-t", "--threshold", type=int, required=True)
subparser.add_argument("-n", "--shares", type=int, required=True)
subparser.add_argument("-w", "--token", required=True)
subparser.set_defaults(func=split)

subparser = subparsers.add_parser("combine", help="combine shares")
subparser.add_argument("-f", "--file", type=argparse.FileType("r"), default=stdin)
subparser.add_argument("-w", "--token", required=True)
subparser.set_defaults(func=combine)

args = parser.parse_args()
args = vars(args)
args.pop("func")(**args)
