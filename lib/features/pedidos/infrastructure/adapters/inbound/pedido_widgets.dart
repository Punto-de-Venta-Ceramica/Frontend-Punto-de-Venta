import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_widgets.dart';
import '../../../domain/pedido.dart';

/// "Tipo de entrega:" con el ícono y el nombre. Misma en listado y detalle.
class PedidoTipoEntrega extends StatelessWidget {
  const PedidoTipoEntrega(this.tipo, {this.tamano = 13, super.key});
  final String tipo;
  final double tamano;

  static String nombre(String tipo) => switch (tipo) {
    'DOMICILIO' => 'A domicilio',
    'LOCAL' => 'En sucursal',
    _ => tipo,
  };

  @override
  Widget build(BuildContext context) {
    final alto = tamano + 7;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        Text(
          'Tipo de entrega:',
          style: BarroTheme.type(tamano, alto, color: BarroTheme.secondary),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              tipo == 'DOMICILIO'
                  ? Icons.local_shipping_outlined
                  : Icons.storefront_outlined,
              size: tamano + 3,
              color: BarroTheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              nombre(tipo),
              style: BarroTheme.type(tamano, alto, weight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }
}

/// Selector del estado: muestra el actual y solo habilita el siguiente paso
/// permitido para el rol (mismas reglas que el backend). Terminado y cancelado
/// no se editan aquí.
class PedidoEstadoSelector extends StatelessWidget {
  const PedidoEstadoSelector({
    required this.estado,
    required this.esPropietario,
    required this.onCambiar,
    this.habilitado = true,
    super.key,
  });
  final String estado;
  final bool esPropietario;
  final ValueChanged<String> onCambiar;
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    if (!EstadosPedido.progreso.contains(estado)) {
      return const SizedBox.shrink();
    }
    bool permitido(String destino) => EstadosPedido.puedeCambiar(
      estado,
      destino,
      esPropietario: esPropietario,
    );
    final editable = habilitado && EstadosPedido.progreso.any(permitido);
    return DropdownButtonFormField<String>(
      key: ValueKey('estado-$estado'),
      initialValue: estado,
      decoration: productoDecoracion().copyWith(
        labelText: 'Estado del pedido',
        helperText: !esPropietario
            ? 'Solo el propietario puede cambiar a producción o entregado.'
            : estado == 'ENCARGADO'
            ? 'Debe pasar por producción antes de entregarse.'
            : null,
        helperMaxLines: 2,
      ),
      items: [
        for (final opcion in EstadosPedido.progreso)
          DropdownMenuItem(
            value: opcion,
            enabled: opcion == estado || permitido(opcion),
            child: Text(
              EstadosPedido.etiqueta(opcion),
              style: opcion == estado || permitido(opcion)
                  ? null
                  : BarroTheme.type(14, 21, color: BarroTheme.placeholder),
            ),
          ),
      ],
      onChanged: editable
          ? (nuevo) {
              if (nuevo != null && nuevo != estado) onCambiar(nuevo);
            }
          : null,
    );
  }
}

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
