from time import time
from hmac import digest
from base64 import b32decode, b16decode
from struct import unpack


def hotp(*, secret: str, counter: int, digits=6):
    string = digest(
        key=b32decode(secret, casefold=True),
        msg=b16decode("%016X" % counter),
        digest="sha1",
    )
    offset = string[-1] % 16
    binary = unpack(">I", string[offset : offset + 4])[0] & 0x7FFFFFFF
    otp = binary % (10**digits)
    return str(otp).zfill(digits)


def totp(*, period=30, **args):
    return hotp(counter=int(time()) // period, **args)
