import re

from core.exceptions import (
    PasswordTooShort,
    PasswordTooLong,
    PasswordMissingUppercase,
    PasswordMissingLowercase,
    PasswordMissingSpecial,
)

MIN_LENGTH = 8
# bcrypt tronque silencieusement au delà de 72 octets, on refuse en amont
MAX_BYTES = 72

_SPECIAL_RE = re.compile(r'''[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;'`~]''')
_UPPERCASE_RE = re.compile(r"[A-Z]")
_LOWERCASE_RE = re.compile(r"[a-z]")


def validate_password(password: str) -> None:
    if len(password) < MIN_LENGTH:
        raise PasswordTooShort()
    if len(password.encode("utf-8")) > MAX_BYTES:
        raise PasswordTooLong()
    if not _UPPERCASE_RE.search(password):
        raise PasswordMissingUppercase()
    if not _LOWERCASE_RE.search(password):
        raise PasswordMissingLowercase()
    if not _SPECIAL_RE.search(password):
        raise PasswordMissingSpecial()
