import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/authentication/domain/auth_failure.dart';
import 'package:frontend/features/settings/domain/user_failure.dart';

void main() {
  group('AuthFailure.resolve', () {
    test('code d\'erreur stable prioritaire', () {
      expect(AuthFailure.resolve(null, code: 'password_too_short'),
          'auth_error.password_too_short');
      expect(AuthFailure.resolve(null, code: 'weak_password'),
          'auth_error.weak_password');
    });

    test('le code prime sur le texte du message', () {
      expect(
        AuthFailure.resolve('Invalid email or password', code: 'weak_password'),
        'auth_error.weak_password',
      );
    });

    test('fallback sur le texte du message si pas de code', () {
      expect(AuthFailure.resolve('Invalid email or password'),
          'auth_error.invalid_credentials');
    });

    test('fallback sur le statut HTTP si ni code ni texte connus', () {
      expect(AuthFailure.resolve(null, statusCode: 400), 'auth_error.bad_request');
      expect(AuthFailure.resolve(null, statusCode: 401), 'auth_error.unauthorized');
    });

    test('unknown en dernier recours', () {
      expect(AuthFailure.resolve(null), 'auth_error.unknown');
      expect(AuthFailure.resolve('message inconnu'), 'auth_error.unknown');
    });
  });

  group('UserFailure.resolve', () {
    test('code d\'erreur stable prioritaire', () {
      expect(UserFailure.resolve(null, code: 'password_missing_uppercase'),
          'settings_error.password_missing_uppercase');
    });

    test('le code prime sur le texte', () {
      expect(
        UserFailure.resolve('Current password is incorrect',
            code: 'password_too_short'),
        'settings_error.password_too_short',
      );
    });

    test('fallback sur le texte du message', () {
      expect(UserFailure.resolve('Current password is incorrect'),
          'settings_error.wrong_password');
    });

    test('fallback sur le statut HTTP', () {
      expect(UserFailure.resolve(null, statusCode: 409), 'settings_error.conflict');
    });

    test('unknown en dernier recours', () {
      expect(UserFailure.resolve(null), 'settings_error.unknown');
    });
  });
}
