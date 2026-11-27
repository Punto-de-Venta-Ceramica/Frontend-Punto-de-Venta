import 'package:punto_de_venta/features/tickets/domain/ticket.dart';

import '../domain/venta.dart';

/// Arma el ticket de una venta ya registrada. Las líneas salen de la
/// cotización del servidor y el total, de la venta confirmada. [fecha] es el
/// momento del registro, para que una reimpresión no cambie la hora.
Ticket ticketDeVenta(
  VentaRegistrada venta,
  CotizacionVenta cotizacion, {
  required List<SeleccionVenta> productos,
  required String negocio,
  required String sucursal,
  required DateTime fecha,
}) => Ticket(
  tipo: TipoTicket.venta,
  negocio: negocio,
  sucursal: sucursal,
  folio: venta.folio,
  fecha: fecha,
  total: venta.total.toDouble(),
  eslogan: venta.negocioEslogan,
  lineas: [
    for (final (i, detalle) in cotizacion.detalles.indexed)
      LineaTicket(
        nombre: detalle.nombre,
        cantidad: detalle.cantidad,
        precioUnitario: detalle.precioUnitario.toDouble(),
        subtotal: detalle.subtotal.toDouble(),
        porcentajeDescuento: _porcentaje(
          i < productos.length ? productos[i] : null,
          detalle,
        ),
      ),
  ],
);

/// Porcentaje aplicado a la línea, tomado de lo que eligió el vendedor. Solo
/// es informativo: el importe descontado se calcula con precio y subtotal.
double _porcentaje(SeleccionVenta? seleccion, DetalleVenta detalle) {
  if (seleccion == null ||
      seleccion.nombre != detalle.nombre) {
    return 0;
  }
  return seleccion.porcentajeAplicado?.toDouble() ?? 0;
}
