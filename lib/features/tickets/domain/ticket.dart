/// De qué sale un ticket. Todos comparten formato; el tipo se imprime como
/// título y el folio lleva su propio prefijo (VTA- o PED-), así que en un
/// reclamo se distingue a simple vista si es de una venta o de un pedido.
enum TipoTicket {
  venta('TICKET DE VENTA', 'Fecha:'),
  pedido('TICKET DE PEDIDO', 'Entrega:'),

  /// Pedido aún no entregado con anticipo o pagos: muestra lo pagado y el saldo.
  comprobante('COMPROBANTE DE PEDIDO', 'Fecha:');

  const TipoTicket(this.titulo, this.etiquetaFecha);

  /// Título impreso bajo los datos del negocio.
  final String titulo;

  /// Etiqueta de [Ticket.fecha] (en pedidos, la fecha de entrega).
  final String etiquetaFecha;
}

/// Ticket listo para imprimir, sin importar si sale de un pedido o de una
/// venta: cada módulo arma el suyo y la impresora no sabe de dónde viene.
class Ticket {
  const Ticket({
    required this.tipo,
    required this.negocio,
    required this.sucursal,
    required this.lineas,
    required this.total,
    required this.fecha,
    this.folio,
    this.eslogan,
    this.pagado,
    this.entrega,
  });

  final TipoTicket tipo;
  final String negocio, sucursal;
  final String? folio;
  final List<LineaTicket> lineas;
  final double total;

  /// Fecha y hora de la venta (para un pedido: cuando se entrega).
  final DateTime fecha;

  /// Eslogan del negocio al pie del ticket; null o vacío = no se imprime.
  final String? eslogan;

  /// Lo pagado hasta ahora; null = no se imprimen pagado ni saldo.
  final double? pagado;

  /// Fecha de entrega acordada (solo el día); null = no se imprime.
  final DateTime? entrega;
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
