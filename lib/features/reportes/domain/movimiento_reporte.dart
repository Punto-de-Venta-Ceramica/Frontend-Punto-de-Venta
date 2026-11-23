enum TipoMovimientoReporte {
  venta('Venta'),
  anticipo('Anticipo'),
  liquidacion('Liquidación'),
  devolucion('Devolución');

  const TipoMovimientoReporte(this.etiqueta);

  final String etiqueta;
}

enum MedioPagoReporte { efectivo, tarjeta }

class ProductoMovimientoReporte {
  const ProductoMovimientoReporte({
    required this.id,
    required this.nombre,
    required this.cantidad,
  });

  final int id;
  final String nombre;
  final int cantidad;
}

class MovimientoReporte {
  const MovimientoReporte({
    required this.id,
    required this.fechaHora,
    required this.horaLocal,
    required this.tipo,
    required this.medioPago,
    required this.referencia,
    required this.importe,
    required this.productos,
    this.vendedor,
    this.creadorPedido,
  });

  final int id;
  final DateTime fechaHora;
  final String horaLocal;
  final TipoMovimientoReporte tipo;
  final MedioPagoReporte medioPago;
  final String referencia;
  final num importe;
  final List<ProductoMovimientoReporte> productos;
  final String? vendedor;
  final String? creadorPedido;
}
