class ProductoPedido {
  const ProductoPedido({
    required this.id,
    required this.nombre,
    required this.precio,
    this.cantidadMinima,
    this.cantidadMaxima,
    this.porcentajeDescuento,
  });
  final int id;
  final String nombre;
  final double precio;
  final int? cantidadMinima, cantidadMaxima;
  final double? porcentajeDescuento;

  bool aplicaDescuento(int cantidad) =>
      cantidadMinima != null &&
      porcentajeDescuento != null &&
      porcentajeDescuento! > 0 &&
      cantidad >= cantidadMinima! &&
      (cantidadMaxima == null || cantidad <= cantidadMaxima!);
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

class CortePedido {
  const CortePedido({required this.id, required this.apertura});
  final int id;
  final String apertura;
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
    required this.corteId,
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
  final int? corteId;
}
