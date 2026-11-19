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
    final cancelaciones = corte.cancelacionesPedidos.detalles;

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
                          valor: '${corte.productos.length}',
                          etiqueta: corte.productos.length == 1
                              ? 'Producto'
                              : 'Productos',
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

                  // Card 1: Productos vendidos
                  CorteSeccion(
                    icono: Icons.shopping_bag_outlined,
                    titulo: 'Productos vendidos',
                    subtitulo:
                        'Ventas directas, los pagos de pedidos se muestran abajo',
                    child: corte.productos.isEmpty
                        ? _vacio()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final p in corte.productos) _producto(p),
                              const SizedBox(height: 6),
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

                  // Card 2: Pagos y cancelaciones
                  CorteSeccion(
                    icono: Icons.swap_vert_rounded,
                    titulo: 'Pagos y cancelaciones',
                    subtitulo: 'Movimientos de pedidos del turno',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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

  Widget _producto(ProductoVendido p) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: BarroTheme.background,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFF0E6E1)),
    ),
    child: Row(
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 42),
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: corteSuave,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${_numero(p.cantidad)}×',
            style: BarroTheme.type(
              14,
              19,
              weight: FontWeight.w800,
              color: BarroTheme.primary,
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

    Widget metodo(String etiqueta, IconData ic, Color tono, double v) =>
        Expanded(
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
                      style: BarroTheme.type(
                        11,
                        15,
                        color: BarroTheme.secondary,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        monto(v),
                        style: BarroTheme.type(
                          14,
                          19,
                          weight: FontWeight.w700,
                          color: color(v),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

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
              metodo('Efectivo', Icons.payments_outlined, corteVerde, efectivo),
              const SizedBox(width: 10),
              metodo('Tarjeta', Icons.credit_card_rounded, corteAzul, tarjeta),
            ],
          ),
        ],
      ),
    );
  }
}
