/// Ticket listo para imprimir, sin importar si sale de un pedido o de una
/// venta: cada módulo arma el suyo y la impresora no sabe de dónde viene.
class Ticket {
  const Ticket({
    required this.negocio,
    required this.sucursal,
    required this.lineas,
    required this.total,
    required this.fecha,
    this.folio,
    this.etiquetaFecha = 'Fecha:',
    this.eslogan,
  });

  final String negocio, sucursal;
  final String? folio;
  final List<LineaTicket> lineas;
  final double total;

  /// Fecha y hora de la venta (para un pedido: cuando se entrega).
  final DateTime fecha;

  /// Etiqueta de [fecha] en el ticket (en pedidos: "Entrega:").
  final String etiquetaFecha;

  /// Eslogan del negocio al pie del ticket; null o vacío = no se imprime.
  final String? eslogan;
}

class LineaTicket {
  const LineaTicket({
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
    this.porcentajeDescuento = 0,
  });
  final String nombre;
  final int cantidad;
  final double precioUnitario;

  /// Importe final de la línea, ya con descuento.
  final double subtotal;
  final double porcentajeDescuento;

  /// Cantidad por precio de lista, antes del descuento.
  double get importeBruto => cantidad * precioUnitario;

  /// Lo que se descontó; 0 si no hubo descuento.
  double get descuento {
    final diferencia = importeBruto - subtotal;
    return diferencia > 0.004 ? diferencia : 0;
  }
}

/// Impresora vinculada al dispositivo.
class ImpresoraTicket {
  const ImpresoraTicket({required this.nombre, required this.direccion});
  final String nombre;

  /// Dirección MAC (Android/Windows) o identificador (iOS).
  final String direccion;
}

/// Falla con un mensaje listo para mostrarse al usuario.
class ImpresionException implements Exception {
  const ImpresionException(this.message);
  final String message;
  @override
  String toString() => message;
}
