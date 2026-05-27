import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/utils/jwt_utils.dart';

/// Construit un JWT factice (sans signature valide) avec le payload donné.
String _makeToken(Map<String, dynamic> payload) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${seg({'alg': 'HS256', 'typ': 'JWT'})}.${seg(payload)}.signature';
}

void main() {
  group('roleFromToken', () {
    test('extrait le rôle d\'un token valide', () {
      expect(roleFromToken(_makeToken({'sub': '1', 'role': 'user'})), 'user');
      expect(roleFromToken(_makeToken({'sub': '1', 'role': 'admin'})), 'admin');
      expect(
        roleFromToken(_makeToken({'sub': '1', 'role': 'super_admin'})),
        'super_admin',
      );
    });

    test('renvoie null si le payload n\'a pas de rôle', () {
      expect(roleFromToken(_makeToken({'sub': '1'})), isNull);
    });

    test('renvoie null pour un token malformé', () {
      expect(roleFromToken(null), isNull);
      expect(roleFromToken(''), isNull);
      expect(roleFromToken('not-a-jwt'), isNull);
      expect(roleFromToken('only.two'), isNull);
      expect(roleFromToken('header.@@@.sig'), isNull);
    });
  });

  group('isSuperAdminToken', () {
    test('vrai uniquement pour super_admin', () {
      expect(isSuperAdminToken(_makeToken({'role': 'super_admin'})), isTrue);
      expect(isSuperAdminToken(_makeToken({'role': 'admin'})), isFalse);
      expect(isSuperAdminToken(_makeToken({'role': 'user'})), isFalse);
      expect(isSuperAdminToken(null), isFalse);
    });
  });
}
