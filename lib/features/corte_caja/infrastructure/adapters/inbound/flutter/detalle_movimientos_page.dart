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
                  const SizedBox(height: 20),
                  Text(
                    'Detalle del día',
                    style: BarroTheme.type(30, 38, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sucursal ${corte.sucursalNombre} - ${formatFecha(fecha)}',
                    style: BarroTheme.type(14, 20, color: BarroTheme.secondary),
                  ),
                  const SizedBox(height: 20),

                  // Card 1: Productos vendidos
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: BarroTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Productos vendidos',
                          style: BarroTheme.type(
                            16,
                            22,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (corte.productos.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                'No se registraron productos vendidos en este turno.',
                                textAlign: TextAlign.center,
                                style: BarroTheme.type(
                                  13,
                                  18,
                                  color: BarroTheme.placeholder,
                                ),
                              ),
                            ),
                          )
                        else ...[
                          // Encabezados de tabla de productos
                          Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(
                                  'Concepto',
                                  style: BarroTheme.type(
                                    12,
                                    16,
                                    weight: FontWeight.w700,
                                    color: BarroTheme.secondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Cant',
                                  textAlign: TextAlign.center,
                                  style: BarroTheme.type(
                                    12,
                                    16,
                                    weight: FontWeight.w700,
                                    color: BarroTheme.secondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'P. unit.',
                                  textAlign: TextAlign.right,
                                  style: BarroTheme.type(
                                    12,
                                    16,
                                    weight: FontWeight.w700,
                                    color: BarroTheme.secondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'Importe',
                                  textAlign: TextAlign.right,
                                  style: BarroTheme.type(
                                    12,
                                    16,
                                    weight: FontWeight.w700,
                                    color: BarroTheme.secondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(color: BarroTheme.border, height: 1),
                          ),
                          ...corte.productos.map(
                            (p) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      p.nombre,
                                      style: BarroTheme.type(
                                        13,
                                        18,
                                        weight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '${p.cantidad}',
                                      textAlign: TextAlign.center,
                                      style: BarroTheme.type(13, 18),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      formatDinero(p.precioUnitario),
                                      textAlign: TextAlign.right,
                                      style: BarroTheme.type(
                                        13,
                                        18,
                                        color: BarroTheme.secondary,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      formatDinero(p.subtotal),
                                      textAlign: TextAlign.right,
                                      style: BarroTheme.type(
                                        13,
                                        18,
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(color: BarroTheme.border, height: 1),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total de ventas',
                                style: BarroTheme.type(
                                  14,
                                  19,
                                  weight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                formatDinero(corte.totalVentas),
                                style: BarroTheme.type(
                                  16,
                                  22,
                                  weight: FontWeight.w700,
                                  color: BarroTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          'Ventas directas, los pagos de pedidos se muestran abajo',
                          style: BarroTheme.type(
                            11,
                            15,
                            color: BarroTheme.placeholder,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Card 2: Pagos y cancelaciones
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: BarroTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Pagos y cancelaciones',
                          style: BarroTheme.type(
                            16,
                            22,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                'Concepto',
                                style: BarroTheme.type(
                                  12,
                                  16,
                                  weight: FontWeight.w700,
                                  color: BarroTheme.secondary,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Efectivo',
                                textAlign: TextAlign.right,
                                style: BarroTheme.type(
                                  12,
                                  16,
                                  weight: FontWeight.w700,
                                  color: BarroTheme.secondary,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Tarjeta',
                                textAlign: TextAlign.right,
                                style: BarroTheme.type(
                                  12,
                                  16,
                                  weight: FontWeight.w700,
                                  color: BarroTheme.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(color: BarroTheme.border, height: 1),
                        ),
                        _filaPagos(
                          'Anticipos',
                          formatDinero(corte.ventasEfectivo.anticipos),
                          formatDinero(corte.ventasTarjeta.anticipos),
                        ),
                        const SizedBox(height: 8),
                        _filaPagos(
                          'Liquidaciones',
                          formatDinero(corte.ventasEfectivo.liquidaciones),
                          formatDinero(corte.ventasTarjeta.liquidaciones),
                        ),
                        const SizedBox(height: 8),
                        _filaPagos(
                          'Cancelaciones',
                          corte.ventasEfectivo.cancelaciones > 0
                              ? '-${formatDinero(corte.ventasEfectivo.cancelaciones)}'
                              : '\$0.00',
                          corte.ventasTarjeta.cancelaciones > 0
                              ? '-${formatDinero(corte.ventasTarjeta.cancelaciones)}'
                              : '\$0.00',
                          colorEfectivo: corte.ventasEfectivo.cancelaciones > 0
                              ? BarroTheme.error
                              : null,
                          colorTarjeta: corte.ventasTarjeta.cancelaciones > 0
                              ? BarroTheme.error
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Card 3: Alertas de cancelaciones de pedidos
                  if (corte.cancelacionesPedidos.detalles.isNotEmpty) ...[
                    ...corte.cancelacionesPedidos.detalles.map(
                      (d) => TarjetaCancelacionPedido(detalle: d),
                    ),
                    const SizedBox(height: 6),
                  ],

                  // Botón Volver al resumen
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: BarroTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Volver al resumen',
                      style: BarroTheme.type(
                        15,
                        20,
                        weight: FontWeight.w600,
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

  Widget _filaPagos(
    String concepto,
    String efectivo,
    String tarjeta, {
    Color? colorEfectivo,
    Color? colorTarjeta,
  }) => Row(
    children: [
      Expanded(
        flex: 4,
        child: Text(
          concepto,
          style: BarroTheme.type(13, 18, weight: FontWeight.w500),
        ),
      ),
      Expanded(
        flex: 3,
        child: Text(
          efectivo,
          textAlign: TextAlign.right,
          style: BarroTheme.type(
            13,
            18,
            weight: FontWeight.w600,
            color: colorEfectivo ?? BarroTheme.text,
          ),
        ),
      ),
      Expanded(
        flex: 3,
        child: Text(
          tarjeta,
          textAlign: TextAlign.right,
          style: BarroTheme.type(
            13,
            18,
            weight: FontWeight.w600,
            color: colorTarjeta ?? BarroTheme.text,
          ),
        ),
      ),
    ],
  );
}

