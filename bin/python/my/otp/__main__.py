#!/usr/bin/python3
from . import hotp, totp
from base64 import b32decode
import argparse


def b32encoded(arg):
    try:
        b32decode(arg, casefold=True)
    except:
        raise ValueError
    return arg


b32encoded.__name__ = "base32-encoded"

parser = argparse.ArgumentParser(prog="otp", description="OAUTH OTP generator")

parser.add_argument(
    "-d", "--digits", type=int, default=6, help="digits (default: %(default)s)"
)
parser.add_argument("secret", type=b32encoded, metavar="SECRET", help="secret")

subparsers = parser.add_subparsers(metavar="TYPE", required=True)

parser_hotp = subparsers.add_parser("hotp", help="hash-based OTP")
parser_hotp.add_argument(
    "-c", "--counter", type=int, required=True, help="moving factor"
)
parser_hotp.set_defaults(func=hotp)

parser_totp = subparsers.add_parser("totp", help="time-based OTP")
parser_totp.add_argument(
    "-p", "--period", type=int, default=30, help="period (default: %(default)s)"
)
parser_totp.set_defaults(func=totp)

args = parser.parse_args()
args = vars(args)
print(args.pop("func")(**args))
