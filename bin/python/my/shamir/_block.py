from secrets import randbelow
from ._math import eval_at, lagrange_interpolate


def split_block(*, secret: int, threshold: int, shares: int, prime: int):
    """
    Generates a random shamir pool for a given secret, returns share points.
    """
    if threshold < 1:
        raise ValueError("Threshold must be >= 1")
    if threshold > shares:
        raise ValueError("Threshold must be <= number of shares")

    poly = [secret] + [randbelow(prime) for _ in range(threshold - 1)]
    points = [(i, eval_at(poly, i, prime)) for i in range(1, shares + 1)]
    return points


def combine_block(*, points, prime: int):
    """
    Recover the secret from share points
    (points (x,y) on the polynomial).
    """
    if not points:
        return 0
    x_s, y_s = zip(*points)
    return lagrange_interpolate(0, x_s, y_s, prime)
