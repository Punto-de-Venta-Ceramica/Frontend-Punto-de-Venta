/// Descuento por volumen: aplica de [cantidadMinima] a [cantidadMaxima] piezas (null = sin tope).
class EscalonDescuento {
  const EscalonDescuento({
    required this.cantidadMinima,
    this.cantidadMaxima,
    required this.porcentaje,
  });
  final int cantidadMinima;
  final int? cantidadMaxima;
  final double porcentaje;

  bool aplicaA(int cantidad) =>
      cantidad >= cantidadMinima &&
      (cantidadMaxima == null || cantidad <= cantidadMaxima!);
}

class ProductoPedido {
  const ProductoPedido({
    required this.id,
    required this.nombre,
    required this.precio,
    this.descuentos = const [],
  });
  final int id;
  final String nombre;
  final double precio;

  /// Escalones por cantidad (p. ej. 5–10, 11–20, 21+); solo aplica aquel en que cae la cantidad.
  final List<EscalonDescuento> descuentos;

  /// Porcentaje del escalón en que cae la cantidad, o null si no cae en ninguno.
  /// Igual que el backend: si hubiera varios, gana el de mayor cantidad mínima.
  double? porcentajePara(int cantidad) {
    EscalonDescuento? elegido;
    for (final escalon in descuentos) {
      if (escalon.aplicaA(cantidad) &&
          (elegido == null ||
              escalon.cantidadMinima > elegido.cantidadMinima)) {
        elegido = escalon;
      }
    }
    final porcentaje = elegido?.porcentaje;
    return porcentaje != null && porcentaje > 0 ? porcentaje : null;
  }

  bool aplicaDescuento(int cantidad) => porcentajePara(cantidad) != null;

  /// Estima el subtotal en centavos, con el redondeo por línea del backend.
  BigInt subtotalEstimadoCentavos(int cantidad) {
    final precioCentavos = BigInt.from((precio * 100).round());
    final descuento = ((porcentajePara(cantidad) ?? 0) * 100).round();
    final importe =
        precioCentavos * BigInt.from(cantidad) * BigInt.from(10000 - descuento);
    return (importe + BigInt.from(5000)) ~/ BigInt.from(10000);
  }
}

class LineaPedido {
  const LineaPedido({required this.productoId, required this.cantidad});
  final int productoId, cantidad;
}

class AvisoPedido {
  const AvisoPedido({
    required this.id,
    required this.titulo,
    required this.mensaje,
    required this.leida,
  });
  final int id;
  final String titulo, mensaje;
  final bool leida;
}

class Pedido {
  const Pedido({
    required this.id,
    required this.folio,
    required this.estado,
    required this.cliente,
    required this.telefono,
    required this.ciudad,
    required this.colonia,
    required this.calle,
    required this.descripcion,
    required this.tipoEntrega,
    required this.productos,
    required this.total,
    required this.pagado,
    required this.saldo,
  });
  final int id;
  final String folio, estado, cliente, telefono, ciudad, colonia, calle;
  final String descripcion, tipoEntrega;
  final List<DetallePedido> productos;
  final double total, pagado, saldo;
}

class DetallePedido {
  const DetallePedido({
    required this.nombre,
    required this.cantidad,
    required this.subtotal,
    required this.porcentajeDescuento,
  });
  final String nombre;
  final int cantidad;
  final double subtotal, porcentajeDescuento;
}

class DatosPedido {
  const DatosPedido({
    required this.sucursalId,
    required this.descripcion,
    required this.cliente,
    required this.telefono,
    required this.ciudad,
    required this.colonia,
    required this.calle,
    required this.productos,
    required this.tipoEntrega,
    required this.descripcionEnvio,
    required this.monto,
    required this.metodo,
  });
  final int sucursalId;
  final List<LineaPedido> productos;
  final String descripcion,
      cliente,
      telefono,
      ciudad,
      colonia,
      calle,
      tipoEntrega,
      descripcionEnvio,
      metodo;
  final double monto;
}
