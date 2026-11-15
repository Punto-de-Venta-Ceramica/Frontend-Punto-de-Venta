import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';

import '../../../../domain/reporte_contable.dart';

const _fondoImporte = Color(0xFFF7E7DF);
final _moneda = NumberFormat.currency(
  locale: 'es_MX',
  symbol: r'$',
  decimalDigits: 2,
);
const _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

class PanelReporte extends StatelessWidget {
  const PanelReporte({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: BarroTheme.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );
}

class FiltroPeriodo extends StatelessWidget {
  const FiltroPeriodo({
    required this.seleccionado,
    required this.desde,
    required this.hasta,
    this.onPeriodo,
    this.onAnterior,
    this.onSiguiente,
    super.key,
  });

  final PeriodoReporte seleccionado;
  final DateTime desde;
  final DateTime hasta;
  final ValueChanged<PeriodoReporte>? onPeriodo;
  final VoidCallback? onAnterior;
  final VoidCallback? onSiguiente;

  String get _textoFecha => switch (seleccionado) {
    PeriodoReporte.diario =>
      '${desde.day} de ${_meses[desde.month - 1]} de ${desde.year}',
    PeriodoReporte.semanal =>
      '${_fechaCorta(desde, conAnio: desde.year != hasta.year)} – ${_fechaCorta(hasta)}',
    PeriodoReporte.mensual => '${_meses[desde.month - 1]} de ${desde.year}',
  };

  static String _fechaCorta(DateTime fecha, {bool conAnio = true}) =>
      '${fecha.day} ${_meses[fecha.month - 1].substring(0, 3)}${conAnio ? ' ${fecha.year}' : ''}';

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final apilar =
              constraints.maxWidth <
              MediaQuery.textScalerOf(context).scale(110);
          return SegmentedButton<PeriodoReporte>(
            direction: apilar ? Axis.vertical : Axis.horizontal,
            expandedInsets: EdgeInsets.zero,
            showSelectedIcon: false,
            style: ButtonStyle(
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 6),
              ),
              minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
              backgroundColor: WidgetStateProperty.resolveWith(
                (estados) =>
                    estados.contains(WidgetState.selected) &&
                        !estados.contains(WidgetState.disabled)
                    ? BarroTheme.primary
                    : null,
              ),
              foregroundColor: WidgetStateProperty.resolveWith(
                (estados) =>
                    estados.contains(WidgetState.selected) &&
                        !estados.contains(WidgetState.disabled)
                    ? Colors.white
                    : null,
              ),
            ),
            segments: [
              for (final periodo in PeriodoReporte.values)
                ButtonSegment(
                  value: periodo,
                  label: Text(periodo.etiqueta, textAlign: TextAlign.center),
                ),
            ],
            selected: {seleccionado},
            onSelectionChanged: onPeriodo == null
                ? null
                : (opciones) => onPeriodo!(opciones.single),
          );
        },
      ),
      Row(
        children: [
          IconButton(
            tooltip: 'Periodo anterior',
            onPressed: onAnterior,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(child: Text(_textoFecha, textAlign: TextAlign.center)),
          IconButton(
            tooltip: 'Periodo siguiente',
            onPressed: onSiguiente,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    ],
  );
}

class ResumenReporte extends StatelessWidget {
  const ResumenReporte({required this.reporte, super.key});

  final ReporteContable reporte;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelReporte(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ingresos netos del periodo',
                style: BarroTheme.type(14, 20, weight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                _moneda.format(reporte.neto),
                style: BarroTheme.type(32, 39, weight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  Text('Cobrado ${_moneda.format(reporte.cobrado)}'),
                  Text('Devuelto ${_moneda.format(reporte.devuelto)}'),
                ],
              ),
              if (!reporte.hayMovimientos) ...[
                const SizedBox(height: 8),
                Text(
                  'Sin movimientos en cortes cerrados para este periodo.',
                  style: BarroTheme.type(13, 19, color: BarroTheme.secondary),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        PanelReporte(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ingresos netos por método de pago',
                style: BarroTheme.type(15, 22, weight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final efectivo = _ImporteMetodo('Efectivo', reporte.efectivo);
                  final tarjeta = _ImporteMetodo('Tarjeta', reporte.tarjeta);
                  if (constraints.maxWidth <
                      MediaQuery.textScalerOf(context).scale(215)) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [efectivo, const SizedBox(height: 10), tarjeta],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: efectivo),
                      const SizedBox(width: 10),
                      Expanded(child: tarjeta),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ImporteMetodo extends StatelessWidget {
  const _ImporteMetodo(this.metodo, this.neto);

  final String metodo;
  final num neto;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _fondoImporte,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          metodo,
          style: BarroTheme.type(13, 19, color: BarroTheme.secondary),
        ),
        const SizedBox(height: 2),
        Text(
          _moneda.format(neto),
          style: BarroTheme.type(17, 23, weight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class SeleccionSucursalPendiente extends StatelessWidget {
  const SeleccionSucursalPendiente({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 26,
            backgroundColor: _fondoImporte,
            foregroundColor: BarroTheme.primary,
            child: Icon(Icons.bar_chart_rounded),
          ),
          const SizedBox(height: 12),
          Text(
            'Selecciona una sucursal para consultar sus ingresos y movimientos.',
            textAlign: TextAlign.center,
            style: BarroTheme.type(14, 22, color: BarroTheme.secondary),
          ),
        ],
      ),
    ),
  );
}

class ErrorReporte extends StatelessWidget {
  const ErrorReporte({
    required this.error,
    required this.onReintentar,
    super.key,
  });

  final String error;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(error, style: BarroTheme.type(14, 21, color: BarroTheme.error)),
        TextButton(onPressed: onReintentar, child: const Text('Reintentar')),
      ],
    ),
  );
}
