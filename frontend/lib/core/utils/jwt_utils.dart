import 'dart:convert';

/// Rôle réservé à l'administration, bloqué sur l'app mobile.
const String kSuperAdminRole = 'super_admin';

/// Décode le payload d'un JWT et renvoie le rôle, ou null si le token est illisible.
/// Sert à filtrer le super_admin côté client (LinkedIn, refresh au lancement).
String? roleFromToken(String? token) {
  if (token == null || token.isEmpty) return null;
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final decoded = jsonDecode(payload);
    return decoded is Map<String, dynamic> ? decoded['role'] as String? : null;
  } catch (_) {
    return null;
  }
}

/// Vrai si le token appartient à un super_admin.
bool isSuperAdminToken(String? token) => roleFromToken(token) == kSuperAdminRole;
