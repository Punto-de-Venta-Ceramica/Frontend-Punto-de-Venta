library;

/// Modelos de dominio para el Corte de Caja diario (HU-13).

class CorteCajaFailure implements Exception {
  const CorteCajaFailure(
    this.message, {
    this.fieldErrors = const {},
    this.sesionExpirada = false,
    this.noAbierto = false,
  });

  final String message;
  final Map<String, String> fieldErrors;
  final bool sesionExpirada;
  final bool noAbierto;

  @override
  String toString() => message;
}

/// Representa el corte de caja completo (activo o cerrado).
class CorteCaja {
  const CorteCaja({
    required this.id,
    required this.cajaId,
    required this.sucursalId,
    this.sucursalNombre = '',
    required this.usuarioId,
    required this.usuarioNombre,
    required this.fechaHoraApertura,
    this.fechaHoraCierre,
    required this.cerrado,
    required this.montoInicial,
    required this.totalVentas,
    required this.totalAnticipos,
    required this.totalLiquidaciones,
    required this.totalCancelaciones,
    required this.ventasEfectivo,
    required this.ventasTarjeta,
    required this.cancelacionesPedidos,
    required this.totalEfectivo,
    required this.totalTarjeta,
    required this.totalEstimado,
    this.totalReal,
    this.diferencia,
    this.productos = const [],
  });

  final int id;
  final int cajaId;
  final int sucursalId;
  final String sucursalNombre;
  final int usuarioId;
  final String usuarioNombre;
  final DateTime fechaHoraApertura;
  final DateTime? fechaHoraCierre;
  final bool cerrado;
  final double montoInicial;
  final double totalVentas;
  final double totalAnticipos;
  final double totalLiquidaciones;
  final double totalCancelaciones;
  final DesgloseMetodoPago ventasEfectivo;
  final DesgloseMetodoPago ventasTarjeta;
  final SeccionCancelaciones cancelacionesPedidos;
  final double totalEfectivo;
  final double totalTarjeta;
  final double totalEstimado;
  final double? totalReal;
  final double? diferencia;
  final List<ProductoVendido> productos;

  /// Total neto del día generado por ventas, anticipos y liquidaciones menos cancelaciones.
  double get totalNetoDia =>
      ventasEfectivo.subtotalNeto + ventasTarjeta.subtotalNeto;

  /// Efectivo que debe haber en caja (fondo inicial + subtotal neto en efectivo).
  double get efectivoEsperado => ventasEfectivo.totalEsperado;
}

/// Desglose de ingresos y egresos para un método de pago (Efectivo o Tarjeta).
class DesgloseMetodoPago {
  const DesgloseMetodoPago({
    required this.totalVentas,
    required this.anticipos,
    required this.liquidaciones,
    required this.cancelaciones,
    required this.subtotalNeto,
    required this.montoInicial,
    required this.totalEsperado,
  });

  final double totalVentas;
  final double anticipos;
  final double liquidaciones;
  final double cancelaciones;
  final double subtotalNeto;
  final double montoInicial;
  final double totalEsperado;
}

/// Sección de cancelaciones con su total y detalles por pedido cancelado.
class SeccionCancelaciones {
  const SeccionCancelaciones({
    required this.totalCancelaciones,
    required this.cancelacionesEfectivo,
    required this.cancelacionesTarjeta,
    this.detalles = const [],
  });

  final double totalCancelaciones;
  final double cancelacionesEfectivo;
  final double cancelacionesTarjeta;
  final List<CancelacionPedido> detalles;
}

/// Detalle de la cancelación de un pedido y su anticipo descontado.
class CancelacionPedido {
  const CancelacionPedido({
    required this.pedidoId,
    required this.folio,
    required this.monto,
    required this.metodoPago,
    required this.tipoPago,
    required this.fechaHora,
  });

  final int pedidoId;
  final String folio;
  final double monto;
  final String metodoPago;
  final String tipoPago;
  final DateTime fechaHora;
}

/// Producto vendido durante el turno de la caja.
class ProductoVendido {
  const ProductoVendido({
    required this.idProducto,
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  final int idProducto;
  final String nombre;
  final int cantidad;
  final double precioUnitario;
  final double subtotal;
}

/// Resumen de un corte de caja para listados históricos.
class ResumenCorteCaja {
  const ResumenCorteCaja({
    required this.id,
    required this.cajaId,
    required this.sucursalId,
    this.sucursalNombre = '',
    required this.usuarioId,
    required this.usuarioNombre,
    required this.fechaHoraApertura,
    this.fechaHoraCierre,
    required this.cerrado,
    required this.montoInicial,
    required this.totalVentas,
    required this.totalEstimado,
    this.totalReal,
    this.diferencia,
  });

  final int id;
  final int cajaId;
  final int sucursalId;
  final String sucursalNombre;
  final int usuarioId;
  final String usuarioNombre;
  final DateTime fechaHoraApertura;
  final DateTime? fechaHoraCierre;
  final bool cerrado;
  final double montoInicial;
  final double totalVentas;
  final double totalEstimado;
  final double? totalReal;
  final double? diferencia;
}
