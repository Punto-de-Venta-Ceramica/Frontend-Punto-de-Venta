import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_widgets.dart';
import 'package:punto_de_venta/features/sucursal/infrastructure/adapters/inbound/flutter/sucursal_widgets.dart';

import '../../../domain/pedido.dart';

/// Confirmación para terminar un pedido entregado. Sigue el mismo estilo que
/// el diálogo de cancelar pedido, pero en verde porque es una acción positiva.
/// Devuelve `true` si el usuario confirma.
class TerminarPedidoDialog extends StatelessWidget {
  const TerminarPedidoDialog({required this.pedido, super.key});
  final ResumenPedido pedido;

  static const _verdeSuave = Color(0xFFE8F5EE);
  static const _verdeAro = Color(0xFFC6E6D3);

  Widget _punto(IconData icono, String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 18, color: BarroTheme.secondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            texto,
            style: BarroTheme.type(13, 19, color: BarroTheme.secondary),
          ),
        ),
      ],
    ),
  );

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

  @override
  Widget build(BuildContext context) {
    final piezas = pedido.productos.fold<int>(0, (s, l) => s + l.cantidad);
    final conSaldo = pedido.saldo > 0;
    return Dialog(
      backgroundColor: BarroTheme.background,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
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
                    Icons.task_alt_rounded,
                    size: 32,
                    color: BarroTheme.success,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '¿Terminar este pedido?',
                textAlign: TextAlign.center,
                style: BarroTheme.type(21, 27, weight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                '¿Estás seguro de terminar el pedido de ${pedido.cliente}? '
                'Ya no podrá cambiar de estado.',
                textAlign: TextAlign.center,
                style: BarroTheme.type(13, 19, color: BarroTheme.placeholder),
              ),
              const SizedBox(height: 18),
              // Resumen del pedido que se va a cerrar.
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: BarroTheme.border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: sucursalSuave,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.person_outline_rounded,
                            size: 20,
                            color: BarroTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pedido.cliente,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: BarroTheme.type(
                                  15,
                                  21,
                                  weight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '$piezas ${piezas == 1 ? 'pieza' : 'piezas'}',
                                style: BarroTheme.type(
                                  12,
                                  18,
                                  color: BarroTheme.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: BarroTheme.border),
                    ),
                    Row(
                      children: [
                        _importe('Total', formatoPrecio(pedido.total)),
                        _importe('Pagado', formatoPrecio(pedido.pagado)),
                        _importe(
                          'Saldo',
                          formatoPrecio(pedido.saldo),
                          color: conSaldo
                              ? BarroTheme.primary
                              : BarroTheme.success,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: BarroTheme.border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _punto(
                      Icons.flag_outlined,
                      'El pedido pasará a estado Terminado.',
                    ),
                    _punto(
                      Icons.lock_outline_rounded,
                      'Esta acción no se puede deshacer.',
                    ),
                  ],
                ),
              ),
              if (conSaldo) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF6E5),
                    border: Border.all(color: const Color(0xFFF2D59B)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: Color(0xFF9A6200),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            style: BarroTheme.type(
                              13,
                              19,
                              color: const Color(0xFF6B4500),
                            ),
                            children: [
                              const TextSpan(text: 'Este pedido tiene '),
                              TextSpan(
                                text: formatoPrecio(pedido.saldo),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const TextSpan(text: ' de saldo pendiente.'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              FilledButton.icon(
                key: const ValueKey('pedido-terminar-confirmar'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: BarroTheme.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                label: const Text('Sí, terminar'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: BarroTheme.secondary,
                  side: const BorderSide(color: BarroTheme.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.pop(context, false),
                icon: const Icon(Icons.close_rounded, size: 20),
                label: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
