import '../domain/ticket.dart';

/// Puerto hacia la impresora térmica (hoy Bluetooth con ESC/POS).
abstract interface class ImpresoraTicketsPort {
  /// Impresoras vinculadas al dispositivo. Lanza [ImpresionException] si no
  /// hay permisos, el Bluetooth está apagado o la plataforma no lo soporta.
  Future<List<ImpresoraTicket>> vinculadas();
  Future<void> imprimir(ImpresoraTicket impresora, Ticket ticket);
}

/// Recuerda la última impresora usada para no preguntarla en cada ticket.
abstract interface class ImpresoraPreferidaPort {
  Future<ImpresoraTicket?> leer();
  Future<void> guardar(ImpresoraTicket impresora);
}

class ImpresionTickets {
  const ImpresionTickets(this._impresora, this._preferida);
  final ImpresoraTicketsPort _impresora;
  final ImpresoraPreferidaPort _preferida;

  Future<List<ImpresoraTicket>> vinculadas() => _impresora.vinculadas();
  Future<ImpresoraTicket?> preferida() => _preferida.leer();

  /// Imprime y, si sale bien, deja [impresora] como la preferida.
  Future<void> imprimir(ImpresoraTicket impresora, Ticket ticket) async {
    await _impresora.imprimir(impresora, ticket);
    await _preferida.guardar(impresora);
  }
}
