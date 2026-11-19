import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';

import '../../../../domain/reporte_contable.dart';

const _fondoImporte = Color(0xFFF7E7DF);

/// Colores por método de pago: verde para efectivo, azul para tarjeta.
const verdeEfectivo = Color(0xFF1F6B45);
const _fondoEfectivo = Color(0xFFE6F2EA);
const _azulTarjeta = Color(0xFF2F5C8F);
const _fondoTarjeta = Color(0xFFE7EEF8);

/// Fondo único de la tarjeta de ingresos netos y su texto café.
const _fondoNeto = Color(0xFFFBEDE6);
const _cafeTexto = Color(0xFF3B1F14);
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

/// Contenedor blanco con borde suave usado en toda la pantalla.
class PanelReporte extends StatelessWidget {
  const PanelReporte({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: BarroTheme.border),
      borderRadius: BorderRadius.circular(18),
    ),
    child: child,
  );
}

/// Cuadro de icono con fondo suave.
class IconoReporte extends StatelessWidget {
  const IconoReporte(
    this.icono, {
    this.color = BarroTheme.primary,
    this.fondo = _fondoImporte,
    this.tamano = 38,
    super.key,
  });

  final IconData icono;
  final Color color;
  final Color fondo;
  final double tamano;

  @override
  Widget build(BuildContext context) => Container(
    width: tamano,
    height: tamano,
    decoration: BoxDecoration(
      color: fondo,
      borderRadius: BorderRadius.circular(tamano * 0.32),
    ),
    child: Icon(icono, size: tamano * 0.52, color: color),
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

  static IconData _icono(PeriodoReporte periodo) => switch (periodo) {
    PeriodoReporte.diario => Icons.today_outlined,
    PeriodoReporte.semanal => Icons.date_range_outlined,
    PeriodoReporte.mensual => Icons.calendar_month_outlined,
  };

  Widget _flecha({
    required String tooltip,
    required IconData icono,
    required VoidCallback? onPressed,
  }) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: BarroTheme.primary,
      disabledBackgroundColor: Colors.transparent,
      disabledForegroundColor: BarroTheme.border,
      side: BorderSide(
        color: onPressed == null ? Colors.transparent : BarroTheme.border,
      ),
    ),
    icon: Icon(icono),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final apilar =
              constraints.maxWidth <
              MediaQuery.textScalerOf(context).scale(110);
          // Con poco espacio horizontal se omiten los iconos de cada segmento.
          final conIconos =
              constraints.maxWidth >=
              MediaQuery.textScalerOf(context).scale(300);
          return SegmentedButton<PeriodoReporte>(
            direction: apilar ? Axis.vertical : Axis.horizontal,
            expandedInsets: EdgeInsets.zero,
            showSelectedIcon: false,
            style: ButtonStyle(
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 6),
              ),
              minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
              side: const WidgetStatePropertyAll(
                BorderSide(color: BarroTheme.border),
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              textStyle: WidgetStatePropertyAll(
                BarroTheme.type(14, 20, weight: FontWeight.w600),
              ),
              backgroundColor: WidgetStateProperty.resolveWith(
                (estados) =>
                    estados.contains(WidgetState.selected) &&
                        !estados.contains(WidgetState.disabled)
                    ? BarroTheme.primary
                    : Colors.white,
              ),
              foregroundColor: WidgetStateProperty.resolveWith(
                (estados) =>
                    estados.contains(WidgetState.selected) &&
                        !estados.contains(WidgetState.disabled)
                    ? Colors.white
                    : BarroTheme.secondary,
              ),
            ),
            segments: [
              for (final periodo in PeriodoReporte.values)
                ButtonSegment(
                  value: periodo,
                  icon: conIconos ? Icon(_icono(periodo), size: 18) : null,
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
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _fondoImporte.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _flecha(
              tooltip: 'Periodo anterior',
              icono: Icons.chevron_left_rounded,
              onPressed: onAnterior,
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.event_outlined,
                    size: 18,
                    color: BarroTheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _textoFecha,
                      textAlign: TextAlign.center,
                      style: BarroTheme.type(14, 20, weight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            _flecha(
              tooltip: 'Periodo siguiente',
              icono: Icons.chevron_right_rounded,
              onPressed: onSiguiente,
            ),
          ],
        ),
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
        _TarjetaNeto(reporte: reporte),
        const SizedBox(height: 16),
        PanelReporte(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const IconoReporte(
                    Icons.account_balance_wallet_outlined,
                    tamano: 42,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ingresos netos por método de pago',
                      style: BarroTheme.type(17, 24, weight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  // Proporción de cada método sobre la suma de los positivos;
                  // sin ingresos positivos no se dibuja la barra.
                  final positivo =
                      (reporte.efectivo > 0 ? reporte.efectivo : 0) +
                      (reporte.tarjeta > 0 ? reporte.tarjeta : 0);
                  double? parte(num valor) =>
                      positivo <= 0 ? null : (valor > 0 ? valor / positivo : 0);
                  final efectivo = _ImporteMetodo(
                    'Efectivo',
                    reporte.efectivo,
                    icono: Icons.payments_outlined,
                    color: verdeEfectivo,
                    fondo: _fondoEfectivo,
                    proporcion: parte(reporte.efectivo),
                  );
                  final tarjeta = _ImporteMetodo(
                    'Tarjeta',
                    reporte.tarjeta,
                    icono: Icons.credit_card_rounded,
                    color: _azulTarjeta,
                    fondo: _fondoTarjeta,
                    proporcion: parte(reporte.tarjeta),
                  );
                  if (constraints.maxWidth <
                      MediaQuery.textScalerOf(context).scale(215)) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [efectivo, const SizedBox(height: 10), tarjeta],
                    );
                  }
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: efectivo),
                        const SizedBox(width: 10),
                        Expanded(child: tarjeta),
                      ],
                    ),
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

/// Tarjeta destacada con el ingreso neto y su desglose.
class _TarjetaNeto extends StatelessWidget {
  const _TarjetaNeto({required this.reporte});

  final ReporteContable reporte;

  Widget _dato({
    required IconData icono,
    required Color color,
    required String etiqueta,
    required num valor,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.75),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white),
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icono, size: 22, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                etiqueta,
                style: BarroTheme.type(12, 16, color: BarroTheme.secondary),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _moneda.format(valor),
                  style: BarroTheme.type(
                    17,
                    23,
                    weight: FontWeight.w800,
                    color: _cafeTexto,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _fondoNeto,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFF1D6C9)),
      boxShadow: [
        BoxShadow(
          color: BarroTheme.primary.withValues(alpha: 0.10),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFF6D9CB),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.insert_chart_outlined_rounded,
                size: 32,
                color: BarroTheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ingresos netos del periodo',
                    style: BarroTheme.type(
                      14,
                      20,
                      weight: FontWeight.w600,
                      color: BarroTheme.secondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _moneda.format(reporte.neto),
                      style: BarroTheme.type(
                        34,
                        41,
                        weight: FontWeight.w800,
                        color: _cafeTexto,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final cobrado = _dato(
              icono: Icons.check_rounded,
              color: const Color(0xFF2E5E3F),
              etiqueta: 'Cobrado',
              valor: reporte.cobrado,
            );
            final devuelto = _dato(
              icono: Icons.undo_rounded,
              color: BarroTheme.primary,
              etiqueta: 'Devuelto',
              valor: reporte.devuelto,
            );
            if (constraints.maxWidth <
                MediaQuery.textScalerOf(context).scale(260)) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [cobrado, const SizedBox(height: 10), devuelto],
              );
            }
            return Row(
              children: [
                Expanded(child: cobrado),
                const SizedBox(width: 10),
                Expanded(child: devuelto),
              ],
            );
          },
        ),
        if (!reporte.hayMovimientos) ...[
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: BarroTheme.secondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sin movimientos en cortes cerrados para este periodo.',
                  style: BarroTheme.type(13, 19, color: BarroTheme.secondary),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _ImporteMetodo extends StatelessWidget {
  const _ImporteMetodo(
    this.metodo,
    this.neto, {
    required this.icono,
    required this.color,
    required this.fondo,
    this.proporcion,
  });

  final String metodo;
  final num neto;
  final IconData icono;
  final Color color;
  final Color fondo;

  /// Entre 0 y 1; nulo si no hay ingresos para comparar.
  final double? proporcion;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: fondo,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconoReporte(icono, color: color, fondo: Colors.white, tamano: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                metodo,
                style: BarroTheme.type(
                  15,
                  21,
                  weight: FontWeight.w600,
                  color: BarroTheme.text,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            _moneda.format(neto),
            style: BarroTheme.type(22, 28, weight: FontWeight.w800),
          ),
        ),
        if (proporcion case final double p) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: p.clamp(0, 1).toDouble(),
              minHeight: 7,
              color: color,
              backgroundColor: Colors.white,
              semanticsLabel: 'Proporción de $metodo',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(p * 100).round()} % del total',
            style: BarroTheme.type(11, 16, color: BarroTheme.secondary),
          ),
        ],
      ],
    ),
  );
}

class SeleccionSucursalPendiente extends StatelessWidget {
  const SeleccionSucursalPendiente({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: _fondoImporte,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF0D3C6), width: 6),
            ),
            child: const Icon(
              Icons.insights_rounded,
              size: 32,
              color: BarroTheme.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Elige una sucursal',
            style: BarroTheme.type(16, 22, weight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
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
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0EE),
        border: Border.all(color: const Color(0xFFF6C9C4)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 20,
                color: BarroTheme.error,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  error,
                  style: BarroTheme.type(14, 21, color: BarroTheme.error),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
            ),
          ),
        ],
      ),
    ),
  );
}
