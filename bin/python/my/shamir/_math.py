from operator import mul
from functools import reduce


def product(sequence):
    return reduce(mul, sequence, 1)


def eval_at(poly, x, prime, /):
    accum = 0
    for coeff in reversed(poly):
        accum *= x
        accum += coeff
        accum %= prime
    return accum


def extended_gcd(a, b, /):
    """
    Division in integers modulus p means finding the inverse of the
    denominator modulo p and then multiplying the numerator by this
    inverse (Note: inverse of A is B such that A*B % p == 1). This can
    be computed via the extended Euclidean algorithm
    http://en.wikipedia.org/wiki/Modular_multiplicative_inverse#Computation
    """
    x, last_x = 0, 1
    y, last_y = 1, 0
    while b != 0:
        quot = a // b
        a, b = b, a % b
        x, last_x = last_x - quot * x, x
        y, last_y = last_y - quot * y, y
    return last_x, last_y


def mod_div(num, den, p):
    """Compute num / den modulo prime p

    To explain this, the result will be such that:
    den * mod_div(num, den, p) % p == num
    """
    inv, _ = extended_gcd(den, p)
    return num * inv % p


def lagrange_interpolate(x, x_s, y_s, p):
    """
    Find the y-value for the given x, given n (x, y) points;
    k points will define a polynomial of up to kth order.
    """
    k = len(x_s)

    nums = []
    dens = []
    for i in range(k):
        others = list(x_s)
        cur = others.pop(i)
        nums.append(product(x - o for o in others))
        dens.append(product(cur - o for o in others))
    den = product(dens)
    num = sum(mod_div(nums[i] * den * y_s[i] % p, dens[i], p) for i in range(k))
    return mod_div(num, den, p)
