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
        if (movimientos.length > 3)
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
    final colorTipo = devolucion ? BarroTheme.error : colorMetodo;
    final iconoTipo = switch (movimiento.tipo) {
      TipoMovimientoReporte.venta => Icons.shopping_bag_outlined,
      TipoMovimientoReporte.anticipo => Icons.savings_outlined,
      TipoMovimientoReporte.liquidacion => Icons.task_alt_rounded,
      TipoMovimientoReporte.devolucion => Icons.assignment_return_outlined,
    };
    final etiquetaRegistro = movimiento.vendedor != null
        ? 'Registró'
        : movimiento.creadorPedido != null
        ? 'Pedido creado por'
        : null;
    final nombreRegistro = movimiento.vendedor ?? movimiento.creadorPedido;
    final metodo = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bordeCard),
      ),
      child: Row(
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
              weight: FontWeight.w700,
              color: colorMetodo,
            ),
          ),
        ],
      ),
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
            22,
            28,
            weight: FontWeight.w800,
            color: devolucion ? BarroTheme.error : colorMetodo,
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconoReporte(
                iconoTipo,
                color: colorTipo,
                fondo: Colors.white,
                tamano: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movimiento.tipo.etiqueta,
                      style: BarroTheme.type(17, 23, weight: FontWeight.w700),
                    ),
                    // La referencia del pedido ya llega como "Pedido PED-000022".
                    Text.rich(
                      venta
                          ? TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'Folio: ',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                TextSpan(text: movimiento.referencia),
                              ],
                            )
                          : TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'Pedido: ',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                TextSpan(
                                  text: movimiento.referencia.replaceFirst(
                                    RegExp(r'^Pedido\s+'),
                                    '',
                                  ),
                                ),
                              ],
                            ),
                      style: BarroTheme.type(
                        13,
                        19,
                        color: BarroTheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: 'Hora ${movimiento.horaLocal}',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: BarroTheme.secondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        movimiento.horaLocal,
                        style: BarroTheme.type(
                          12,
                          16,
                          weight: FontWeight.w600,
                          color: BarroTheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (movimiento.productos.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Text(
                      'Detalle de productos no disponible.',
                      style: BarroTheme.type(
                        13,
                        19,
                        color: BarroTheme.secondary,
                      ),
                    ),
                  ),
                for (final producto in productos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          constraints: const BoxConstraints(minWidth: 38),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: BarroTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${producto.cantidad} ×',
                            textAlign: TextAlign.center,
                            style: BarroTheme.type(
                              13,
                              19,
                              weight: FontWeight.w700,
                              color: BarroTheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
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
              ],
            ),
          ),
          const SizedBox(height: 14),
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
                crossAxisAlignment: CrossAxisAlignment.end,
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
                child: etiquetaRegistro == null
                    ? Text(
                        'Usuario no registrado',
                        style: BarroTheme.type(
                          12,
                          18,
                          color: BarroTheme.secondary,
                        ),
                      )
                    : Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$etiquetaRegistro: ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(text: nombreRegistro),
                          ],
                        ),
                        style: BarroTheme.type(
                          12,
                          18,
                          color: BarroTheme.secondary,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
