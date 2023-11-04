import pytest
from otp import *


@pytest.fixture
def secret():
    return "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"


@pytest.fixture
def codes():
    return (
        "755224",
        "287082",
        "359152",
        "969429",
        "338314",
        "254676",
        "287922",
        "162583",
        "399871",
        "520489",
    )


# def test_totp(codes, secret, monkeypatch):
#     monkeypatch.setattr('time.time', lambda: 0 / 0)
#     assert totp(secret=secret) == hotp(secret=secret, counter=0)


def test_hotp(codes, secret):
    # https://datatracker.ietf.org/doc/html/rfc4226#page-32
    for i, expected_code in enumerate(codes):
        assert hotp(counter=i, secret=secret) == expected_code
