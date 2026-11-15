import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../application/impresion_tickets.dart';
import '../../../domain/ticket.dart';

/// Guarda en el dispositivo la última impresora con la que se imprimió.
class SecureImpresoraPreferida implements ImpresoraPreferidaPort {
  const SecureImpresoraPreferida([
    this._storage = const FlutterSecureStorage(),
  ]);
  final FlutterSecureStorage _storage;

  static const _direccion = 'impresora_tickets_direccion';
  static const _nombre = 'impresora_tickets_nombre';

  @override
  Future<ImpresoraTicket?> leer() async {
    try {
      final direccion = await _storage.read(key: _direccion);
      if (direccion == null || direccion.isEmpty) return null;
      final nombre = await _storage.read(key: _nombre);
      return ImpresoraTicket(nombre: nombre ?? direccion, direccion: direccion);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> guardar(ImpresoraTicket impresora) async {
    try {
      await _storage.write(key: _direccion, value: impresora.direccion);
      await _storage.write(key: _nombre, value: impresora.nombre);
    } catch (_) {
      // Si no se puede guardar, la próxima vez solo se vuelve a preguntar.
    }
  }
}
