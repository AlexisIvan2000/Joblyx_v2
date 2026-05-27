import pytest

from core.password import validate_password
from core.exceptions import (
    PasswordTooShort,
    PasswordTooLong,
    PasswordMissingUppercase,
    PasswordMissingLowercase,
    PasswordMissingSpecial,
)


class TestValidatePassword:
    def test_valid_password_passes(self):
        validate_password("Abcdef1!")

    def test_too_short(self):
        with pytest.raises(PasswordTooShort):
            validate_password("Ab1!")

    def test_too_long(self):
        # 73 octets, au dessus de la limite bcrypt de 72
        with pytest.raises(PasswordTooLong):
            validate_password("Aa!" + "x" * 70)

    def test_missing_uppercase(self):
        with pytest.raises(PasswordMissingUppercase):
            validate_password("abcdef1!")

    def test_missing_lowercase(self):
        with pytest.raises(PasswordMissingLowercase):
            validate_password("ABCDEF1!")

    def test_missing_special(self):
        with pytest.raises(PasswordMissingSpecial):
            validate_password("Abcdefg1")

    def test_length_checked_before_composition(self):
        # Un mot de passe trop court sans majuscule remonte d'abord la longueur
        with pytest.raises(PasswordTooShort):
            validate_password("ab!")
