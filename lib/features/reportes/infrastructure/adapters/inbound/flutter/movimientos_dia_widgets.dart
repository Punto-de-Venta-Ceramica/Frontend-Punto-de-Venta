import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';

import '../../../../domain/movimiento_reporte.dart';
import 'reporte_widgets.dart';

final _monedaMovimiento = NumberFormat.currency(
  locale: 'es_MX',
  symbol: r'$',
  decimalDigits: 2,
);

class MovimientosDia extends StatelessWidget {
  const MovimientosDia({
    required this.movimientos,
    required this.onVerTodos,
    required this.onActualizar,
    super.key,
  });

  final List<MovimientoReporte> movimientos;
  final VoidCallback onVerTodos;
  final VoidCallback onActualizar;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Movimientos del día',
              style: BarroTheme.type(21, 28, weight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Actualizar movimientos',
            color: BarroTheme.primary,
            onPressed: onActualizar,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (movimientos.isEmpty)
        const MovimientosDiaVacios()
      else ...[
        for (final movimiento in movimientos.take(3)) ...[
          MovimientoReporteCard(
            key: ValueKey('${movimiento.tipo.name}-${movimiento.id}'),
            movimiento: movimiento,
            compacto: true,
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            side: const BorderSide(color: BarroTheme.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: onVerTodos,
          icon: const Icon(Icons.receipt_long_outlined, size: 20),
          label: Text('Ver todos (${movimientos.length})'),
        ),
      ],
    ],
  );
}

class MovimientosDiaVacios extends StatelessWidget {
  const MovimientosDiaVacios({super.key});

  @override
  Widget build(BuildContext context) => PanelReporte(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const IconoReporte(Icons.receipt_long_outlined),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sin movimientos en esta fecha',
                style: BarroTheme.type(15, 21, weight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Aquí aparecerán las ventas y los pagos de pedidos de la sucursal.',
                style: BarroTheme.type(13, 19, color: BarroTheme.secondary),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class MovimientoReporteCard extends StatefulWidget {
  const MovimientoReporteCard({
    required this.movimiento,
    this.compacto = false,
    super.key,
  });

  final MovimientoReporte movimiento;
  final bool compacto;

  @override
  State<MovimientoReporteCard> createState() => _MovimientoReporteCardState();
}

class _MovimientoReporteCardState extends State<MovimientoReporteCard> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final movimiento = widget.movimiento;
    final venta = movimiento.tipo == TipoMovimientoReporte.venta;
    final devolucion = movimiento.tipo == TipoMovimientoReporte.devolucion;
    final efectivo = movimiento.medioPago == MedioPagoReporte.efectivo;
    final colorMetodo = efectivo ? verdeEfectivo : azulTarjeta;
    final fondoCard = efectivo ? fondoEfectivo : fondoTarjeta;
    final bordeCard = colorMetodo.withValues(alpha: 0.25);
    final mostrarTodos = !widget.compacto || _expandido;
    final productos = mostrarTodos
        ? movimiento.productos
        : movimiento.productos.take(3);
    final importe = _monedaMovimiento.format(movimiento.importe.abs());
    final registro = movimiento.vendedor != null
        ? 'Registró ${movimiento.vendedor}'
        : movimiento.creadorPedido != null
        ? 'Pedido creado por ${movimiento.creadorPedido}'
        : 'Usuario no registrado';
    final metodo = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          efectivo ? Icons.payments_outlined : Icons.credit_card_rounded,
          size: 18,
          color: colorMetodo,
        ),
        const SizedBox(width: 6),
        Text(
          efectivo ? 'Efectivo' : 'Tarjeta',
          style: BarroTheme.type(
            13,
            19,
            weight: FontWeight.w600,
            color: colorMetodo,
          ),
        ),
      ],
    );
    final total = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          devolucion
              ? 'Devuelto'
              : venta
              ? 'Total'
              : 'Cobrado',
          style: BarroTheme.type(12, 16, color: BarroTheme.secondary),
        ),
        Text(
          devolucion ? '−$importe' : importe,
          style: BarroTheme.type(
            19,
            26,
            weight: FontWeight.w700,
            color: devolucion ? BarroTheme.error : BarroTheme.text,
          ),
        ),
      ],
    );
    return PanelReporte(
      color: fondoCard,
      borderColor: bordeCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  venta
                      ? 'Venta ${movimiento.referencia}'
                      : movimiento.tipo.etiqueta,
                  style: BarroTheme.type(17, 23, weight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Semantics(
                label: 'Hora ${movimiento.horaLocal}',
                child: Text(
                  movimiento.horaLocal,
                  style: BarroTheme.type(13, 23, color: BarroTheme.secondary),
                ),
              ),
            ],
          ),
          if (!venta) ...[
            const SizedBox(height: 2),
            Text(
              movimiento.referencia,
              style: BarroTheme.type(13, 19, color: BarroTheme.secondary),
            ),
          ],
          const SizedBox(height: 14),
          if (movimiento.productos.isEmpty)
            Text(
              'Detalle de productos no disponible.',
              style: BarroTheme.type(13, 19, color: BarroTheme.secondary),
            ),
          for (final producto in productos)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 30),
                    child: Text(
                      '${producto.cantidad} ×',
                      style: BarroTheme.type(
                        14,
                        21,
                        weight: FontWeight.w700,
                        color: BarroTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      producto.nombre,
                      style: BarroTheme.type(14, 21),
                    ),
                  ),
                ],
              ),
            ),
          if (!mostrarTodos && movimiento.productos.length > 3)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _expandido = true),
                child: Text(
                  'Ver ${movimiento.productos.length - 3} productos más',
                ),
              ),
            ),
          const Divider(height: 24, color: BarroTheme.border),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth <
                  MediaQuery.textScalerOf(context).scale(265)) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(alignment: Alignment.centerLeft, child: metodo),
                    const SizedBox(height: 8),
                    total,
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  metodo,
                  const SizedBox(width: 12),
                  Flexible(child: total),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.person_outline_rounded,
                size: 17,
                color: BarroTheme.secondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  registro,
                  style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
