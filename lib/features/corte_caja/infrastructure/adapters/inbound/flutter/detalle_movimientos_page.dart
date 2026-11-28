import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import '../../../../domain/corte_caja.dart';
import 'corte_caja_widgets.dart';

/// Pantalla de detalle de movimientos y productos del día (Screen 2 del diseño HU-13).
class DetalleMovimientosPage extends StatelessWidget {
  const DetalleMovimientosPage({
    required this.corte,
    required this.esPropietario,
    this.negocioNombre = '',
    super.key,
  });

  final CorteCaja corte;
  final bool esPropietario;
  final String negocioNombre;

  @override
  Widget build(BuildContext context) {
    final fecha = corte.fechaHoraCierre ?? corte.fechaHoraApertura;
    final piezas = corte.productos.fold<num>(0, (s, p) => s + p.cantidad);
    // Un producto cobrado de varias formas ocupa varios renglones; se cuenta una vez.
    final distintos = corte.productos
        .map((p) => (p.idProducto, p.nombre))
        .toSet()
        .length;
    final cancelaciones = corte.cancelacionesPedidos.detalles;
    // Los productos de pedidos van en su propia tarjeta; aquí solo ventas directas.
    final ventas = [
      for (final p in corte.productos)
        if (p.metodoPago != null) p,
    ];

    return Scaffold(
      backgroundColor: BarroTheme.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CorteCabecera(esPropietario: esPropietario),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        foregroundColor: BarroTheme.primary,
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Corte de caja'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  CorteTitulo(
                    icono: Icons.receipt_long_rounded,
                    titulo: 'Detalle del día',
                    subtitulo:
                        'Sucursal ${corte.sucursalNombre} - ${formatFecha(fecha)}',
                    subtituloIcono: Icons.event_outlined,
                  ),
                  const SizedBox(height: 18),

                  // Indicadores rápidos del día.
                  Row(
                    children: [
                      Expanded(
                        child: _indicador(
                          icono: Icons.inventory_2_outlined,
                          valor: '$distintos',
                          etiqueta: distintos == 1 ? 'Producto' : 'Productos',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _indicador(
                          icono: Icons.layers_outlined,
                          valor: _numero(piezas),
                          etiqueta: piezas == 1 ? 'Pieza' : 'Piezas',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _indicador(
                          icono: Icons.event_busy_outlined,
                          valor: '${cancelaciones.length}',
                          etiqueta: 'Cancelados',
                          alerta: cancelaciones.isNotEmpty,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _separador('Ventas', Icons.storefront_outlined),
                  const SizedBox(height: 10),
                  // Card 1: Productos vendidos
                  CorteSeccion(
                    icono: Icons.shopping_bag_outlined,
                    titulo: 'Productos vendidos',
                    subtitulo:
                        'Ventas directas en mostrador, por método de pago',
                    child: ventas.isEmpty
                        ? _vacio()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final p in ventas) _producto(p),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _metodoBadge(
                                    'Efectivo',
                                    Icons.payments_outlined,
                                    corteVerde,
                                    corteVerdeSuave,
                                    formatDinero(
                                      corte.ventasEfectivo.totalVentas,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _metodoBadge(
                                    'Tarjeta',
                                    Icons.credit_card_rounded,
                                    corteAzul,
                                    corteAzulSuave,
                                    formatDinero(
                                      corte.ventasTarjeta.totalVentas,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: corteSuave,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.sell_outlined,
                                      size: 19,
                                      color: BarroTheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Total de ventas',
                                        style: BarroTheme.type(
                                          14,
                                          19,
                                          weight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      formatDinero(corte.totalVentas),
                                      style: BarroTheme.type(
                                        18,
                                        24,
                                        weight: FontWeight.w800,
                                        color: BarroTheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),

                  _separador('Pedidos', Icons.assignment_outlined),
                  const SizedBox(height: 10),
                  // Card 2: Pedidos con movimientos en el turno y sus totales.
                  CorteSeccion(
                    icono: Icons.assignment_outlined,
                    titulo: 'Pedidos del turno',
                    subtitulo:
                        'Anticipos, liquidaciones y cancelaciones cobrados en este corte',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (corte.pedidos.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'No hubo movimientos de pedidos en este turno.',
                              textAlign: TextAlign.center,
                              style: BarroTheme.type(
                                13,
                                18,
                                color: BarroTheme.placeholder,
                              ),
                            ),
                          ),
                        for (final p in corte.pedidos) _pedido(p),
                        const SizedBox(height: 4),
                        Text(
                          'Totales por método',
                          style: BarroTheme.type(
                            12,
                            16,
                            weight: FontWeight.w600,
                            color: BarroTheme.placeholder,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _movimiento(
                          'Anticipos',
                          Icons.schedule_rounded,
                          corte.ventasEfectivo.anticipos,
                          corte.ventasTarjeta.anticipos,
                        ),
                        const SizedBox(height: 10),
                        _movimiento(
                          'Liquidaciones',
                          Icons.task_alt_rounded,
                          corte.ventasEfectivo.liquidaciones,
                          corte.ventasTarjeta.liquidaciones,
                        ),
                        const SizedBox(height: 10),
                        _movimiento(
                          'Cancelaciones',
                          Icons.cancel_outlined,
                          corte.ventasEfectivo.cancelaciones,
                          corte.ventasTarjeta.cancelaciones,
                          negativo: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Card 3: Alertas de cancelaciones de pedidos
                  if (cancelaciones.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.report_gmailerrorred_rounded,
                          size: 18,
                          color: BarroTheme.error,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Pedidos cancelados en el turno',
                            style: BarroTheme.type(
                              14,
                              19,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...cancelaciones.map(
                      (d) => TarjetaCancelacionPedido(detalle: d),
                    ),
                    const SizedBox(height: 6),
                  ],

                  // Botón Volver al resumen
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: BarroTheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(54),
                      elevation: 2,
                      shadowColor: BarroTheme.primary.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: Text(
                      'Volver al resumen',
                      style: BarroTheme.type(
                        15,
                        20,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _numero(num n) =>
      n == n.roundToDouble() ? '${n.round()}' : n.toStringAsFixed(2);

  Widget _indicador({
    required IconData icono,
    required String valor,
    required String etiqueta,
    bool alerta = false,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    decoration: BoxDecoration(
      color: alerta ? const Color(0xFFFFF5F3) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: alerta
            ? BarroTheme.error.withValues(alpha: 0.25)
            : BarroTheme.border,
      ),
    ),
    child: Column(
      children: [
        CorteIcono(
          icono,
          tamano: 32,
          color: alerta ? BarroTheme.error : BarroTheme.primary,
          fondo: alerta ? const Color(0xFFFDE1DC) : corteSuave,
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            valor,
            style: BarroTheme.type(18, 24, weight: FontWeight.w800),
          ),
        ),
        Text(
          etiqueta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: BarroTheme.type(11, 15, color: BarroTheme.secondary),
        ),
      ],
    ),
  );

  Widget _vacio() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: BarroTheme.background,
            shape: BoxShape.circle,
            border: Border.all(color: BarroTheme.border),
          ),
          child: const Icon(
            Icons.remove_shopping_cart_outlined,
            color: BarroTheme.placeholder,
            size: 28,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'No se registraron productos vendidos en este turno.',
          textAlign: TextAlign.center,
          style: BarroTheme.type(13, 18, color: BarroTheme.placeholder),
        ),
      ],
    ),
  );

  Widget _producto(ProductoVendido p) {
    // Mismos colores e iconos que los totales de Efectivo y Tarjeta de abajo.
    final (etiqueta, icono, tono, fondo) = switch (p.metodoPago) {
      'TARJETA' => (
        'Tarjeta',
        Icons.credit_card_rounded,
        corteAzul,
        corteAzulSuave,
      ),
      'EFECTIVO' => (
        'Efectivo',
        Icons.payments_outlined,
        corteVerde,
        corteVerdeSuave,
      ),
      _ => (
        'Pedido',
        Icons.assignment_outlined,
        BarroTheme.primary,
        corteSuave,
      ),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tono.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 42),
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_numero(p.cantidad)}×',
              style: BarroTheme.type(
                14,
                19,
                weight: FontWeight.w800,
                color: tono,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.nombre,
                  style: BarroTheme.type(14, 19, weight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'P. unit. ${formatDinero(p.precioUnitario)}',
                  style: BarroTheme.type(12, 16, color: BarroTheme.secondary),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icono, size: 13, color: tono),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          etiqueta,
                          overflow: TextOverflow.ellipsis,
                          style: BarroTheme.type(
                            11,
                            14,
                            weight: FontWeight.w700,
                            color: tono,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatDinero(p.subtotal),
            style: BarroTheme.type(14, 19, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  /// Divide visualmente la pantalla entre ventas y pedidos.
  Widget _separador(String texto, IconData icono) => Row(
    children: [
      const Expanded(child: Divider(color: BarroTheme.border)),
      const SizedBox(width: 10),
      CortePastilla(
        icono: icono,
        texto: texto,
        color: BarroTheme.primary,
        fondo: corteSuave,
      ),
      const SizedBox(width: 10),
      const Expanded(child: Divider(color: BarroTheme.border)),
    ],
  );

  static const _ambar = Color(0xFFB45309);
  static const _ambarSuave = Color(0xFFFFF4E0);

  Widget _pedido(PedidoCorte p) {
    // Estado en una franja propia al final para que nunca se corte.
    final (estadoTexto, estadoIcono, estadoColor, estadoFondo) = p.cancelado
        ? (
            'Pedido cancelado',
            Icons.cancel_outlined,
            BarroTheme.error,
            const Color(0xFFFDE1DC),
          )
        : p.saldo > 0
        ? (
            'Resta por cobrar',
            Icons.hourglass_bottom_rounded,
            _ambar,
            _ambarSuave,
          )
        : (
            'Pagado completo',
            Icons.task_alt_rounded,
            corteVerde,
            corteVerdeSuave,
          );
    final secundario = BarroTheme.type(13, 18, color: BarroTheme.secondary);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: BarroTheme.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0E6E1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const CorteIcono(Icons.receipt_outlined, tamano: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pedido',
                            style: BarroTheme.type(
                              11,
                              15,
                              weight: FontWeight.w600,
                              color: BarroTheme.placeholder,
                            ),
                          ),
                          // El folio completo, aunque ocupe dos renglones.
                          Text(
                            p.folio,
                            style: BarroTheme.type(
                              15,
                              20,
                              weight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final producto in p.productos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${producto.cantidad}× ${producto.nombre}',
                            style: secundario,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatDinero(producto.subtotal),
                          style: secundario,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Valor del pedido',
                        style: BarroTheme.type(13, 18, weight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      formatDinero(p.total),
                      style: BarroTheme.type(15, 20, weight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'EN ESTE TURNO',
                  style: BarroTheme.type(
                    11,
                    15,
                    weight: FontWeight.w700,
                    color: BarroTheme.placeholder,
                  ),
                ),
                const SizedBox(height: 8),
                for (final pago in p.pagos) _pagoPedido(pago),
              ],
            ),
          ),
          Container(
            color: estadoFondo,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(estadoIcono, size: 18, color: estadoColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    estadoTexto,
                    style: BarroTheme.type(
                      13,
                      18,
                      weight: FontWeight.w700,
                      color: estadoColor,
                    ),
                  ),
                ),
                if (!p.cancelado && p.saldo > 0)
                  Text(
                    formatDinero(p.saldo),
                    style: BarroTheme.type(
                      15,
                      20,
                      weight: FontWeight.w800,
                      color: estadoColor,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pagoPedido(PagoPedidoCorte pago) {
    final (texto, icono) = switch (pago.tipoPago) {
      'ANTICIPO' => ('Anticipo', Icons.schedule_rounded),
      'LIQUIDACION' => ('Liquidación', Icons.task_alt_rounded),
      _ => ('Devolución', Icons.undo_rounded),
    };
    final devolucion = pago.tipoPago == 'DEVOLUCION';
    final tarjeta = pago.metodoPago == 'TARJETA';
    final tono = tarjeta ? corteAzul : corteVerde;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0E6E1)),
      ),
      child: Row(
        children: [
          CorteIcono(
            icono,
            tamano: 32,
            color: devolucion ? BarroTheme.error : BarroTheme.primary,
            fondo: devolucion ? const Color(0xFFFDE1DC) : corteSuave,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  texto,
                  style: BarroTheme.type(14, 19, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      tarjeta
                          ? Icons.credit_card_rounded
                          : Icons.payments_outlined,
                      size: 14,
                      color: tono,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        tarjeta ? 'Tarjeta' : 'Efectivo',
                        style: BarroTheme.type(
                          12,
                          16,
                          weight: FontWeight.w600,
                          color: tono,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            devolucion
                ? '-${formatDinero(pago.monto)}'
                : formatDinero(pago.monto),
            style: BarroTheme.type(
              15,
              20,
              weight: FontWeight.w800,
              color: devolucion ? BarroTheme.error : BarroTheme.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metodoBadge(
    String etiqueta,
    IconData ic,
    Color tono,
    Color fondo,
    String valorTexto, {
    Color? valorColor,
  }) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tono.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(ic, size: 15, color: tono),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etiqueta,
                  style: BarroTheme.type(11, 15, color: BarroTheme.secondary),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    valorTexto,
                    style: BarroTheme.type(
                      14,
                      19,
                      weight: FontWeight.w700,
                      color: valorColor ?? BarroTheme.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _movimiento(
    String concepto,
    IconData icono,
    double efectivo,
    double tarjeta, {
    bool negativo = false,
  }) {
    String monto(double v) =>
        negativo && v > 0 ? '-${formatDinero(v)}' : formatDinero(v);
    Color color(double v) =>
        negativo && v > 0 ? BarroTheme.error : BarroTheme.text;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BarroTheme.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0E6E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CorteIcono(
                icono,
                tamano: 28,
                color: negativo ? BarroTheme.error : BarroTheme.primary,
                fondo: negativo ? const Color(0xFFFDE1DC) : corteSuave,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  concepto,
                  style: BarroTheme.type(14, 19, weight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _metodoBadge(
                'Efectivo',
                Icons.payments_outlined,
                corteVerde,
                corteVerdeSuave,
                monto(efectivo),
                valorColor: color(efectivo),
              ),
              const SizedBox(width: 10),
              _metodoBadge(
                'Tarjeta',
                Icons.credit_card_rounded,
                corteAzul,
                corteAzulSuave,
                monto(tarjeta),
                valorColor: color(tarjeta),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
