import 'package:punto_de_venta/features/authentication/application/ports/outbound/session_store.dart';
import 'package:punto_de_venta/features/authentication/domain/auth_session.dart';

/// Almacén de sesión en memoria para pruebas (sin canal nativo).
class MemorySessionStore implements SessionStore {
  MemorySessionStore([this.session]);
  AuthSession? session;
  @override
  Future<AuthSession?> leer() async => session;
  @override
  Future<void> guardar(AuthSession session) async => this.session = session;
  @override
  Future<void> borrar() async => session = null;
}
