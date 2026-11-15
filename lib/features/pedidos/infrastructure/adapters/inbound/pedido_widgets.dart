import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_widgets.dart';
import '../../../domain/pedido.dart';

/// Etiqueta de color con el estado del pedido. Misma en listado y detalle.
class PedidoEstadoChip extends StatelessWidget {
  const PedidoEstadoChip(this.estado, {super.key});
  final String estado;

  static (Color fondo, Color texto, IconData icono) colores(String estado) =>
      switch (estado) {
        'ENCARGADO' => (
          const Color(0xFFF3EEEB),
          BarroTheme.secondary,
          Icons.schedule_rounded,
        ),
        'PRODUCCION' => (
          productoSuave,
          BarroTheme.primary,
          Icons.handyman_outlined,
        ),
        'ENTREGADO' => (
          const Color(0xFFFFF3DC),
          const Color(0xFF8A5A00),
          Icons.local_shipping_outlined,
        ),
        'TERMINADO' => (
          const Color(0xFFECF7F0),
          BarroTheme.success,
          Icons.check_circle_outline_rounded,
        ),
        'CANCELADO' => (
          productoErrorSuave,
          BarroTheme.error,
          Icons.cancel_outlined,
        ),
        _ => (productoSuave, BarroTheme.primary, Icons.receipt_long_outlined),
      };

  @override
  Widget build(BuildContext context) {
    final (fondo, color, icono) = colores(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            EstadosPedido.etiqueta(estado),
            style: BarroTheme.type(
              12,
              18,
              weight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
