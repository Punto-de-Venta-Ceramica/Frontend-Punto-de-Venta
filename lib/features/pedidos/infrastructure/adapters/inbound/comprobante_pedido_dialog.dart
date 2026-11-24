import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_widgets.dart';
import 'package:punto_de_venta/features/tickets/application/impresion_tickets.dart';
import 'package:punto_de_venta/features/tickets/infrastructure/adapters/inbound/seccion_imprimir_ticket.dart';

import '../../../application/gestion_pedidos.dart';
import '../../../application/ticket_pedido.dart';
import '../../../domain/pedido.dart';

/// Se abre al registrar un pedido con anticipo: ofrece imprimir el comprobante
/// para el cliente. Si se cierra sin imprimir, el mismo botón está en el
/// detalle del pedido.
class ComprobantePedidoDialog extends StatefulWidget {
  const ComprobantePedidoDialog({
    required this.gestion,
    required this.pedidoId,
    required this.negocio,
    required this.sucursal,
    required this.impresion,
    super.key,
  });
  final GestionPedidos gestion;
  final int pedidoId;
  final String negocio, sucursal;
  final ImpresionTickets impresion;

  @override
  State<ComprobantePedidoDialog> createState() =>
      _ComprobantePedidoDialogState();
}

class _ComprobantePedidoDialogState extends State<ComprobantePedidoDialog> {
  static const _verdeSuave = Color(0xFFE8F5EE);
  static const _verdeAro = Color(0xFFC6E6D3);

  // El ticket lleva el folio y los importes que guardó el servidor.
  late final Future<Pedido> _pedido = widget.gestion.obtener(widget.pedidoId);
  bool _imprimiendo = false;

  Widget _importe(String etiqueta, String valor, {Color? color}) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: BarroTheme.type(11, 16, color: BarroTheme.placeholder),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            valor,
            style: BarroTheme.type(
              15,
              21,
              weight: FontWeight.w700,
              color: color ?? BarroTheme.text,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _contenido(Pedido pedido) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: BarroTheme.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            _importe('Total', formatoPrecio(pedido.total)),
            _importe('Anticipo', formatoPrecio(pedido.pagado)),
            _importe(
              'Saldo',
              formatoPrecio(pedido.saldo),
              color: pedido.saldo > 0 ? BarroTheme.primary : BarroTheme.success,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      SeccionImprimirTicket(
        impresion: widget.impresion,
        onImprimiendo: (valor) => setState(() => _imprimiendo = valor),
        ticket: () => ticketDeComprobante(
          pedido,
          negocio: widget.negocio,
          sucursal: widget.sucursal,
          fecha: DateTime.now(),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: BarroTheme.background,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: _verdeSuave,
                      shape: BoxShape.circle,
                      border: Border.all(color: _verdeAro, width: 6),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      size: 32,
                      color: BarroTheme.success,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Pedido registrado',
                  textAlign: TextAlign.center,
                  style: BarroTheme.type(21, 27, weight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Imprime el comprobante del anticipo para el cliente.',
                  textAlign: TextAlign.center,
                  style: BarroTheme.type(13, 19, color: BarroTheme.placeholder),
                ),
                const SizedBox(height: 18),
                FutureBuilder<Pedido>(
                  future: _pedido,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) return _contenido(snapshot.data!);
                    if (snapshot.hasError) {
                      return Text(
                        'No se pudo cargar el pedido. Imprime el comprobante '
                        'desde el detalle del pedido.',
                        textAlign: TextAlign.center,
                        style: BarroTheme.type(13, 19, color: BarroTheme.error),
                      );
                    }
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  'Si lo cierras, puedes imprimirlo después desde el detalle '
                  'del pedido.',
                  textAlign: TextAlign.center,
                  style: BarroTheme.type(12, 18, color: BarroTheme.placeholder),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  key: const ValueKey('comprobante-listo'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _imprimiendo ? null : () => Navigator.pop(context),
                  child: const Text('Listo'),
                ),
              ],
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              tooltip: 'Cerrar',
              onPressed: _imprimiendo ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      ),
    ),
  );
}
