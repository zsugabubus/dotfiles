#!/usr/bin/python3
import argparse
from . import run_server

parser = argparse.ArgumentParser(
    prog="http", formatter_class=argparse.ArgumentDefaultsHelpFormatter
)

parser.add_argument(
    "-p", "--port", type=int, nargs="?", default=8000, help="specify alternate port"
)

parser.add_argument(
    "path",
    metavar="PATH",
    type=str,
    nargs="?",
    default=None,
    help="redirect all traffic to this path",
)

args = parser.parse_args()
run_server(("", args.port), only_path=args.path)
