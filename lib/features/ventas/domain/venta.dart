enum MetodoPagoVenta {
  efectivo('EFECTIVO', 'Efectivo'),
  tarjeta('TARJETA', 'Tarjeta');

  const MetodoPagoVenta(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;
}

class ProductoVenta {
  const ProductoVenta({
    required this.id,
    required this.nombre,
    required this.precio,
    required this.existencia,
    this.imagenUrl,
    this.areaNombre,
    this.categoriaNombre,
    this.descuentos = const [],
  });

  final int id;
  final String nombre;
  final num precio;
  final int existencia;
  final String? imagenUrl;
  final String? areaNombre;
  final String? categoriaNombre;
  final List<RangoDescuentoVenta> descuentos;

  RangoDescuentoVenta? descuentoPara(int cantidad) {
    RangoDescuentoVenta? aplicable;
    for (final rango in descuentos) {
      if (rango.aplicaA(cantidad) &&
          (aplicable == null ||
              rango.cantidadMinima > aplicable.cantidadMinima)) {
        aplicable = rango;
      }
    }
    return aplicable;
  }
}

class RangoDescuentoVenta {
  const RangoDescuentoVenta({
    required this.cantidadMinima,
    required this.porcentaje,
    this.cantidadMaxima,
  });

  final int cantidadMinima;
  final int? cantidadMaxima;
  final num porcentaje;

  bool aplicaA(int cantidad) =>
      porcentaje > 0 &&
      cantidad >= cantidadMinima &&
      (cantidadMaxima == null || cantidad <= cantidadMaxima!);
}

class PaginaProductosVenta {
  const PaginaProductosVenta({
    required this.productos,
    required this.pagina,
    required this.totalElementos,
    required this.ultima,
  });

  final List<ProductoVenta> productos;
  final int pagina;
  final int totalElementos;
  final bool ultima;
}

class SeleccionVenta {
  const SeleccionVenta({
    required this.producto,
    required this.cantidad,
    bool aplicarDescuento = false,
  }) : _descuentoMarcado = aplicarDescuento;

  static const maximoProductos = 200;

  final ProductoVenta producto;
  final int cantidad;
  final bool _descuentoMarcado;

  num? get porcentajeDisponible => producto.descuentoPara(cantidad)?.porcentaje;

  bool get aplicarDescuento =>
      _descuentoMarcado && porcentajeDisponible != null;

  SeleccionVenta actualizar(ProductoVenta producto, int cantidad) =>
      SeleccionVenta(
        producto: producto,
        cantidad: cantidad,
        aplicarDescuento:
            aplicarDescuento &&
            porcentajeDisponible ==
                producto.descuentoPara(cantidad)?.porcentaje,
      );

  num get importe {
    final bruto =
        BigInt.from((producto.precio * 100).round()) * BigInt.from(cantidad);
    final porcentaje = _descuentoMarcado ? porcentajeDisponible : null;
    if (porcentaje == null) return bruto.toDouble() / 100;

    final factor = 10000 - (porcentaje * 100).round();
    final subtotal =
        (bruto * BigInt.from(factor) + BigInt.from(5000)) ~/ BigInt.from(10000);
    return subtotal.toDouble() / 100;
  }
}

class DetalleVenta {
  const DetalleVenta({
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  final String nombre;
  final int cantidad;
  final num precioUnitario;
  final num subtotal;
}

class CotizacionVenta {
  const CotizacionVenta({
    required this.detalles,
    required this.descuento,
    required this.total,
  });

  final List<DetalleVenta> detalles;
  final num descuento;
  final num total;
}

class VentaRegistrada {
  const VentaRegistrada({
    required this.id,
    required this.folio,
    required this.total,
    this.cambio,
    this.negocioEslogan,
  });

  final int id;

  /// Folio que ve el cliente (VTA-000123); va en el ticket.
  final String folio;
  final num total;
  final num? cambio;

  /// Eslogan del negocio para el pie del ticket; null si no tiene.
  final String? negocioEslogan;
}

class VentaFailure implements Exception {
  const VentaFailure(this.mensaje, {this.estado, this.errorMonto});

  final String mensaje;
  final int? estado;
  final String? errorMonto;

  bool get sesionExpirada => estado == 401;
  bool get resultadoIncierto => estado == 408 || (estado ?? 500) >= 500;
}
