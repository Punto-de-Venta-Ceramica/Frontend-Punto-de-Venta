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
    this.areaId,
    this.area,
    this.categoriaId,
    this.categoria,
    this.imagenUrl,
  });
  final int id;
  final String nombre;
  final double precio;

  /// Área y categoría del catálogo, para filtrar al elegir el producto. Son
  /// null si el servidor no las envía.
  final int? areaId, categoriaId;
  final String? area, categoria;

  /// Imagen del producto en el catálogo; null si no tiene.
  final String? imagenUrl;

  /// Cantidad mínima del siguiente escalón de mayoreo por encima de
  /// [cantidad], o null si ya no hay uno mayor.
  int? siguienteEscalon(int cantidad) {
    int? siguiente;
    for (final escalon in descuentos) {
      if (escalon.porcentaje > 0 &&
          escalon.cantidadMinima > cantidad &&
          (siguiente == null || escalon.cantidadMinima < siguiente)) {
        siguiente = escalon.cantidadMinima;
      }
    }
    return siguiente;
  }

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
  /// Sin [conDescuento] se calcula a precio de lista.
  BigInt subtotalEstimadoCentavos(int cantidad, {bool conDescuento = true}) {
    final precioCentavos = BigInt.from((precio * 100).round());
    final descuento = conDescuento
        ? ((porcentajePara(cantidad) ?? 0) * 100).round()
        : 0;
    final importe =
        precioCentavos * BigInt.from(cantidad) * BigInt.from(10000 - descuento);
    return (importe + BigInt.from(5000)) ~/ BigInt.from(10000);
  }
}

class LineaPedido {
  const LineaPedido({
    required this.productoId,
    required this.cantidad,
    this.aplicarDescuento = true,
  });
  final int productoId, cantidad;

  /// Si se usa el descuento vigente del producto. El servidor lo resuelve por
  /// jerarquía (producto, luego categoría, luego área); aquí solo se decide
  /// aplicarlo o no.
  final bool aplicarDescuento;

  LineaPedido conDescuento(bool aplicar) => LineaPedido(
    productoId: productoId,
    cantidad: cantidad,
    aplicarDescuento: aplicar,
  );

  LineaPedido conCantidad(int nueva) => LineaPedido(
    productoId: productoId,
    cantidad: nueva,
    aplicarDescuento: aplicarDescuento,
  );
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
    this.descripcionEnvio = '',
    this.fechaCreacion,
  });
  final int id;
  final String folio, estado, cliente, telefono, ciudad, colonia, calle;
  final String descripcion, tipoEntrega, descripcionEnvio;
  final List<DetallePedido> productos;
  final double total, pagado, saldo;

  /// Cuándo se encargó el pedido (hora local); null si no llegó.
  final DateTime? fechaCreacion;
}

/// Datos editables de un pedido (solo propietario). No incluye productos ni
/// pagos: esos no se modifican con esta operación.
class DatosEdicionPedido {
  const DatosEdicionPedido({
    required this.descripcion,
    required this.tipoEntrega,
    required this.descripcionEnvio,
    required this.cliente,
    required this.telefono,
    this.ciudad = '',
    this.colonia = '',
    this.calle = '',
  });
  final String descripcion, tipoEntrega, descripcionEnvio;
  final String cliente, telefono, ciudad, colonia, calle;
}

class DetallePedido {
  const DetallePedido({
    required this.nombre,
    required this.cantidad,
    required this.subtotal,
    required this.porcentajeDescuento,
    this.precioUnitario,
    this.imagenUrl,
  });
  final String nombre;
  final int cantidad;
  final double subtotal, porcentajeDescuento;

  /// Precio de lista con el que se registró la línea, antes del descuento.
  final double? precioUnitario;

  /// Imagen del producto en el catálogo; null si no tiene.
  final String? imagenUrl;
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

/// Estados del pedido para el filtro del listado.
class EstadosPedido {
  EstadosPedido._();

  /// Filtro con el que abre el listado. El propietario ve lo encargado (los
  /// pedidos que tiene que hacer); el empleado, lo entregado en sucursal, que
  /// es lo que le falta terminar.
  static String porDefecto({required bool esPropietario}) =>
      esPropietario ? 'ENCARGADO' : 'ENTREGADO';

  /// Estados del selector de la tarjeta, en orden.
  static const progreso = ['ENCARGADO', 'PRODUCCION', 'ENTREGADO'];

  /// Si [destino] puede elegirse desde [actual]. Mismas reglas que el backend:
  /// solo el propietario pone en producción o marca como entregado, y no se
  /// puede saltar de encargado a entregado. El empleado solo termina pedidos.
  static bool puedeCambiar(
    String actual,
    String destino, {
    required bool esPropietario,
  }) => switch ((actual, destino)) {
    ('ENCARGADO', 'PRODUCCION') => esPropietario,
    ('PRODUCCION', 'ENTREGADO') => esPropietario,
    _ => false,
  };

  static const todos = [
    'ENCARGADO',
    'PRODUCCION',
    'ENTREGADO',
    'TERMINADO',
    'CANCELADO',
  ];

  static String etiqueta(String estado) => switch (estado) {
    'ENCARGADO' => 'Encargado',
    'PRODUCCION' => 'En producción',
    'ENTREGADO' => 'Entregado',
    'TERMINADO' => 'Terminado',
    'CANCELADO' => 'Cancelado',
    _ => estado,
  };
}

/// Producto de una fila del listado: solo nombre y cantidad.
class LineaResumen {
  const LineaResumen({required this.nombre, required this.cantidad});
  final String nombre;
  final int cantidad;
}

/// Fila del listado paginado. No trae el folio: está en el detalle ([Pedido]).
class ResumenPedido {
  const ResumenPedido({
    required this.id,
    required this.estado,
    required this.cliente,
    required this.tipoEntrega,
    required this.productos,
    required this.total,
    required this.pagado,
    required this.saldo,
  });
  final int id;
  final String estado, cliente, tipoEntrega;
  final List<LineaResumen> productos;
  final double total, pagado, saldo;
}

/// Una página del listado (pagina empieza en 0).
class PaginaPedidos {
  const PaginaPedidos({
    required this.pedidos,
    required this.pagina,
    required this.ultima,
    required this.total,
  });
  final List<ResumenPedido> pedidos;
  final int pagina;
  final bool ultima;
  final int total;
}
