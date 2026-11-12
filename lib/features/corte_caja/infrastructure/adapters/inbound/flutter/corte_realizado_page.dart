import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import '../../../../domain/corte_caja.dart';
import 'corte_caja_widgets.dart';
import 'detalle_movimientos_page.dart';

/// Pantalla de comprobante de corte realizado (Screen 3 del diseño HU-13).
class CorteRealizadoPage extends StatelessWidget {
  const CorteRealizadoPage({
    required this.corte,
    required this.esPropietario,
    this.negocioNombre = '',
    this.onVolver,
    super.key,
  });

  final CorteCaja corte;
  final bool esPropietario;
  final String negocioNombre;
  final VoidCallback? onVolver;

  @override
  Widget build(BuildContext context) {
    final folio = 'C-${corte.id.toString().padLeft(6, '0')}';
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
                    'Corte realizado',
                    style: BarroTheme.type(30, 38, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tu respaldo contable está listo',
                    style: BarroTheme.type(14, 20, color: BarroTheme.secondary),
                  ),
                  const SizedBox(height: 20),
                  SucursalCorteCard(
                    sucursalNombre: corte.sucursalNombre,
                    fecha: fecha,
                    negocioNombre: negocioNombre.isNotEmpty
                        ? negocioNombre
                        : 'Cerámica La Lola',
                    folioCorte: folio,
                    usuarioNombre: corte.usuarioNombre,
                  ),
                  const SizedBox(height: 16),

                  // Resumen general de movimientos
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
                        _fila(
                          'Ventas directas',
                          formatDinero(corte.totalVentas),
                        ),
                        const SizedBox(height: 10),
                        _fila(
                          'Anticipos de pedidos',
                          formatDinero(corte.totalAnticipos),
                        ),
                        const SizedBox(height: 10),
                        _fila(
                          'Liquidaciones de pedidos',
                          formatDinero(corte.totalLiquidaciones),
                        ),
                        const SizedBox(height: 10),
                        _fila(
                          'Cancelaciones',
                          corte.totalCancelaciones > 0
                              ? '-${formatDinero(corte.totalCancelaciones)}'
                              : '\$0.00',
                          colorValor: corte.totalCancelaciones > 0
                              ? BarroTheme.error
                              : BarroTheme.text,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(color: BarroTheme.border, height: 1),
                        ),
                        _fila(
                          'Total neto del día',
                          formatDinero(corte.totalNetoDia),
                          estiloTitulo: BarroTheme.type(
                            15,
                            20,
                            weight: FontWeight.w700,
                          ),
                          estiloValor: BarroTheme.type(
                            18,
                            24,
                            weight: FontWeight.w700,
                            color: BarroTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tarjetas de métodos de pago lado a lado con totales
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: corteSuave,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: BarroTheme.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.payments_outlined,
                                    size: 16,
                                    color: BarroTheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Efectivo neto',
                                    style: BarroTheme.type(
                                      12,
                                      16,
                                      weight: FontWeight.w600,
                                      color: BarroTheme.secondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatDinero(corte.ventasEfectivo.subtotalNeto),
                                style: BarroTheme.type(
                                  17,
                                  22,
                                  weight: FontWeight.w700,
                                  color: BarroTheme.primary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Total efectivo: ${formatDinero(corte.totalEfectivo)}',
                                style: BarroTheme.type(
                                  11,
                                  15,
                                  weight: FontWeight.w500,
                                  color: BarroTheme.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: BarroTheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.credit_card_rounded,
                                    size: 16,
                                    color: BarroTheme.secondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Tarjeta',
                                    style: BarroTheme.type(
                                      12,
                                      16,
                                      weight: FontWeight.w600,
                                      color: BarroTheme.secondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatDinero(corte.ventasTarjeta.subtotalNeto),
                                style: BarroTheme.type(
                                  17,
                                  22,
                                  weight: FontWeight.w700,
                                  color: BarroTheme.text,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Total tarjeta: ${formatDinero(corte.totalTarjeta)}',
                                style: BarroTheme.type(
                                  11,
                                  15,
                                  weight: FontWeight.w500,
                                  color: BarroTheme.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Fila resumen: Total neto y Total estimado
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: BarroTheme.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Total estimado en caja',
                            style: BarroTheme.type(
                              13,
                              18,
                              weight: FontWeight.w600,
                              color: BarroTheme.secondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatDinero(corte.totalEstimado),
                          style: BarroTheme.type(
                            15,
                            20,
                            weight: FontWeight.w700,
                            color: BarroTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Arqueo contable
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: BarroTheme.border),
                    ),
                    child: Column(
                      children: [
                        _fila(
                          'Fondo Inicial',
                          formatDinero(corte.montoInicial),
                        ),
                        const SizedBox(height: 10),
                        _fila(
                          'Efectivo esperado',
                          formatDinero(corte.efectivoEsperado),
                        ),
                        const SizedBox(height: 10),
                        _fila(
                          'Efectivo contado',
                          formatDinero(
                            corte.totalReal ?? corte.efectivoEsperado,
                          ),
                          colorValor: BarroTheme.primary,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(color: BarroTheme.border, height: 1),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Diferencia',
                              style: BarroTheme.type(
                                14,
                                19,
                                weight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: BadgeDiferencia(
                                diferencia: corte.diferencia ?? 0.0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Botón para ver productos y movimientos del corte
                  if (corte.productos.isNotEmpty ||
                      corte.cancelacionesPedidos.detalles.isNotEmpty) ...[
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => DetalleMovimientosPage(
                            corte: corte,
                            esPropietario: esPropietario,
                            negocioNombre: negocioNombre,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('Ver detalle de productos y pedidos'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BarroTheme.primary,
                        side: const BorderSide(color: BarroTheme.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Botón principal
                  FilledButton(
                    onPressed: onVolver ?? () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: BarroTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Volver a caja',
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

  Widget _fila(
    String titulo,
    String valor, {
    TextStyle? estiloTitulo,
    TextStyle? estiloValor,
    Color? colorValor,
  }) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Expanded(
        child: Text(
          titulo,
          style:
              estiloTitulo ??
              BarroTheme.type(13, 18, color: BarroTheme.secondary),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        valor,
        style:
            estiloValor ??
            BarroTheme.type(
              14,
              19,
              weight: FontWeight.w600,
              color: colorValor ?? BarroTheme.text,
            ),
      ),
    ],
  );
}
