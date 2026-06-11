// Politique mot de passe alignée sur le backend (core/password.py)
final _uppercase = RegExp(r'[A-Z]');
final _lowercase = RegExp(r'[a-z]');
final _special = RegExp(r'''[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;'`~]''');

/// Vrai si le mot de passe respecte la politique : 8 caractères minimum,
/// une majuscule, une minuscule et un caractère spécial.
bool isStrongPassword(String value) {
  return value.length >= 8 &&
      _uppercase.hasMatch(value) &&
      _lowercase.hasMatch(value) &&
      _special.hasMatch(value);
}
