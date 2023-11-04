from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from ._block import split_block, combine_block
from secrets import randbits

# openssl prime -generate -bits 264 -hex
_PRIME_256 = 0xC935939968E7D029E3D0C10A9F2807DB81AA4D0B3D4C539D1E9F46269973F41B19
_NONCE = b"\0" * 16


def split_stream(*, plaintext, threshold: int, shares):
    secret = randbits(256)
    points = split_block(
        secret=secret, threshold=threshold, shares=shares, prime=_PRIME_256
    )

    key = secret.to_bytes(32, "big")

    cipher = AESGCM(key)
    payload = cipher.encrypt(_NONCE, plaintext.encode(), None)

    return points, payload


def combine_stream(*, points, payload: bytes):
    secret = combine_block(points=points, prime=_PRIME_256)

    key = secret.to_bytes(32, "big")
    cipher = AESGCM(key)
    return cipher.decrypt(_NONCE, payload, None)
