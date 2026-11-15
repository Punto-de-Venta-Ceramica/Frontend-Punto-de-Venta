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
    negocio: negocio,
    sucursal: sucursal,
    folio: pedido.folio,
    etiquetaFecha: 'Entrega:',
    eslogan: pedido.negocioEslogan,
    fecha: entrega,
    total: pedido.total,
    lineas: [
      for (final d in pedido.productos)
        LineaTicket(
          nombre: d.nombre,
          cantidad: d.cantidad,
          // Sin precio de lista, se toma el efectivo: la línea cuadra igual.
          precioUnitario:
              d.precioUnitario ??
              (d.cantidad > 0 ? d.subtotal / d.cantidad : 0),
          subtotal: d.subtotal,
          porcentajeDescuento: d.porcentajeDescuento,
        ),
    ],
  );
}
