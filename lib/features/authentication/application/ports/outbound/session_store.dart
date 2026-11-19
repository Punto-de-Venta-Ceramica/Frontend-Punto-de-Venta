import '../../../domain/auth_session.dart';

/// Guarda la sesión en el dispositivo para que sobreviva al cierre de la app.
/// Solo se borra cuando el usuario cierra sesión o la sesión vence.
abstract interface class SessionStore {
  Future<AuthSession?> leer();
  Future<void> guardar(AuthSession session);
  Future<void> borrar();
}
