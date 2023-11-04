from dataclasses import dataclass
from itertools import combinations
from ._stream import split_stream, combine_stream


@dataclass(frozen=True, order=True)
class Share:
    token: str
    x: int
    y: int
    threshold: int
    payload: bytes

    @classmethod
    def parse(cls, s, /):
        token, threshold, x, y, payload = s.split("-")
        return cls(
            token=token,
            threshold=int(threshold),
            x=int(x),
            y=int(y, 16),
            payload=bytes.fromhex(payload),
        )

    def __str__(self):
        return "%s-%d-%d-%x-%s" % (
            self.token,
            self.threshold,
            self.x,
            self.y,
            self.payload.hex(),
        )


class ShareManager:
    def __init__(self):
        self._shares = set()

    def add_share(self, share, /):
        self._shares.add(share)

    def add_shares(self, sequence, /):
        self._shares.update(sequence)

    def parse_shares(self, sequence, /):
        self._shares.update(Share.parse(x) for x in sequence)

    def parse_file(self, file, /):
        self.parse_shares(file)

    def get_shares_by_token(self, token, /):
        return set(share for share in self._shares if share.token == token)

    def print(self, **kwargs):
        for share in sorted(self._shares):
            print(share, **kwargs)


def make_shares(*, plaintext, threshold: int, shares, token):
    points, payload = split_stream(
        plaintext=plaintext, threshold=threshold, shares=shares
    )
    return set(
        Share(
            token=token,
            x=x,
            y=y,
            payload=payload,
            threshold=threshold,
        )
        for x, y in points
    )


def combine_shares(all_shares, /):
    try:
        threshold = next(iter(all_shares)).threshold
    except StopIteration:
        threshold = 0

    for shares in combinations(all_shares, threshold):
        points, payload = _shares_to_points(shares)
        try:
            secret = combine_stream(points=points, payload=payload)
        except:
            continue

        return secret

    raise ValueError("Irrecoverable secret")


def _shares_to_points(shares, /):
    if not shares:
        raise ValueError("No shares")

    try:
        (payload,) = set(share.payload for share in shares)
    except ValueError:
        raise ValueError("Inconsistent payloads")

    points = set((share.x, share.y) for share in shares)

    return points, payload
