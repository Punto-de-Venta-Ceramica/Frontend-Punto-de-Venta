import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:punto_de_venta/features/authentication/application/ports/outbound/session_store.dart';
import 'package:punto_de_venta/features/authentication/domain/auth_session.dart';

/// Persiste la sesión cifrada (Keychain en iOS, Keystore en Android).
/// Cualquier fallo del almacenamiento se trata como "no hay sesión guardada".
class SecureSessionStore implements SessionStore {
  const SecureSessionStore([this._storage = const FlutterSecureStorage()]);
  final FlutterSecureStorage _storage;
  static const _clave = 'barrocontrol.sesion';

  @override
  Future<AuthSession?> leer() async {
    try {
      final texto = await _storage.read(key: _clave);
      if (texto == null) return null;
      final data = jsonDecode(texto);
      if (data is! Map) return null;
      final expira = DateTime.tryParse('${data['expiresAt']}');
      final refreshExpira = DateTime.tryParse('${data['refreshExpiresAt']}');
      if (data['token'] is! String ||
          data['refreshToken'] is! String ||
          data['userId'] is! int ||
          data['role'] is! String ||
          expira == null ||
          refreshExpira == null) {
        await borrar();
        return null;
      }
      final session = AuthSession(
        token: data['token'] as String,
        expiresAt: expira,
        refreshToken: data['refreshToken'] as String,
        refreshExpiresAt: refreshExpira,
        userId: data['userId'] as int,
        role: data['role'] as String,
      );
      if (session.isExpired) {
        await borrar();
        return null;
      }
      return session;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> guardar(AuthSession session) async {
    try {
      await _storage.write(
        key: _clave,
        value: jsonEncode({
          'token': session.token,
          'expiresAt': session.expiresAt.toIso8601String(),
          'refreshToken': session.refreshToken,
          'refreshExpiresAt': session.refreshExpiresAt.toIso8601String(),
          'userId': session.userId,
          'role': session.role,
        }),
      );
    } catch (_) {
      // Sin almacenamiento la sesión sigue funcionando mientras la app esté abierta.
    }
  }

  @override
  Future<void> borrar() async {
    try {
      await _storage.delete(key: _clave);
    } catch (_) {}
  }
}
