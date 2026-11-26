import 'package:punto_de_venta/features/tickets/domain/ticket.dart';

import '../domain/pedido.dart';

/// Arma el ticket de un pedido terminado. [entrega] es la fecha y hora de la
/// venta: el momento en que se entrega e imprime.
Ticket ticketDePedido(
  Pedido pedido, {
  required String negocio,
  required String sucursal,
  required DateTime entrega,
}) {
  if (pedido.estado != 'TERMINADO') {
    throw const ImpresionException(
      'Solo se imprime el ticket de pedidos terminados.',
    );
  }
  return Ticket(
    tipo: TipoTicket.pedido,
    negocio: negocio,
    sucursal: sucursal,
    folio: pedido.folio,
    fecha: entrega,
    total: pedido.total,
    lineas: _lineas(pedido),
  );
}

/// Comprobante para el cliente de un pedido que aún no se entrega: lo que
/// pidió, lo que pagó (anticipo o pagos) y lo que le falta. [fecha] es cuando
/// se imprime.
Ticket ticketDeComprobante(
  Pedido pedido, {
  required String negocio,
  required String sucursal,
  required DateTime fecha,
}) {
  if (pedido.estado == 'TERMINADO' || pedido.estado == 'CANCELADO') {
    throw const ImpresionException(
      'El comprobante es solo para pedidos en curso.',
    );
  }
  if (pedido.pagado <= 0) {
    throw const ImpresionException('El pedido todavía no tiene pagos.');
  }
  return Ticket(
    tipo: TipoTicket.comprobante,
    negocio: negocio,
    sucursal: sucursal,
    folio: pedido.folio,
    fecha: fecha,
    total: pedido.total,
    pagado: pedido.pagado,
    entrega: pedido.fechaEntrega,
    lineas: _lineas(pedido),
  );
}

List<LineaTicket> _lineas(Pedido pedido) => [
  for (final d in pedido.productos)
    LineaTicket(
      nombre: d.nombre,
      cantidad: d.cantidad,
      // Sin precio de lista, se toma el efectivo: la línea cuadra igual.
      precioUnitario:
          d.precioUnitario ?? (d.cantidad > 0 ? d.subtotal / d.cantidad : 0),
      subtotal: d.subtotal,
      porcentajeDescuento: d.porcentajeDescuento,
    ),
];
