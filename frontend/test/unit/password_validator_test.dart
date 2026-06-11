import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/utils/password_validator.dart';

void main() {
  group('isStrongPassword', () {
    test('accepte un mot de passe conforme', () {
      expect(isStrongPassword('Abcdefg!'), isTrue);
      expect(isStrongPassword('Str0ng#Pass'), isTrue);
    });

    test('refuse si moins de 8 caractères', () {
      expect(isStrongPassword('Abc1!'), isFalse);
    });

    test('refuse sans majuscule', () {
      expect(isStrongPassword('abcdefg!'), isFalse);
    });

    test('refuse sans minuscule', () {
      expect(isStrongPassword('ABCDEFG!'), isFalse);
    });

    test('refuse sans caractère spécial', () {
      expect(isStrongPassword('Abcdefgh'), isFalse);
    });

    test('un chiffre seul ne compte pas comme caractère spécial', () {
      expect(isStrongPassword('Abcdefg1'), isFalse);
    });
  });
}
