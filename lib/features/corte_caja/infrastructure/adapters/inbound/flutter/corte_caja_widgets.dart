import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import '../../../../domain/corte_caja.dart';

const Color corteSuave = Color(0xFFF7E7DF);
const Color corteCardBg = Colors.white;

/// Formatea un valor numérico como moneda con 2 decimales y comas de miles.
String formatDinero(double monto) {
  final esNegativo = monto < 0;
  final positivo = monto.abs();
  final partes = positivo.toStringAsFixed(2).split('.');
  final entero = partes[0];
  final decimales = partes[1];

  final regExp = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  final formateado = entero.replaceAllMapped(regExp, (m) => '${m[1]},');
  return '${esNegativo ? '-' : ''}\$$formateado.$decimales';
}

/// Formatea una fecha en formato legible en español (ej. "01 oct 2026").
String formatFecha(DateTime fecha) {
  const meses = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = meses[fecha.month - 1];
  final anio = fecha.year;
  return '$dia $mes $anio';
}

/// Formatea fecha y hora corta (ej. "01 oct 2026 14:30").
String formatFechaHora(DateTime fecha) {
  final base = formatFecha(fecha);
  final hora = fecha.hour.toString().padLeft(2, '0');
  final min = fecha.minute.toString().padLeft(2, '0');
  return '$base $hora:$min';
}

/// Cabecera superior con logo de BarroControl y chip de rol.
class CorteCabecera extends StatelessWidget {
  const CorteCabecera({required this.esPropietario, super.key});

  final bool esPropietario;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SvgPicture.asset(
        'assets/icons/brand.svg',
        width: 36,
        height: 36,
        semanticsLabel: 'Logo de BarroControl',
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          'BarroControl',
          style: BarroTheme.type(21, 28, weight: FontWeight.w700),
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: corteSuave,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          esPropietario ? 'Propietario' : 'Empleado',
          style: BarroTheme.type(
            12,
            17,
            weight: FontWeight.w600,
            color: BarroTheme.primary,
          ),
        ),
      ),
    ],
  );
}

/// Tarjeta informativa de la sucursal, fecha y responsable.
class SucursalCorteCard extends StatelessWidget {
  const SucursalCorteCard({
    required this.sucursalNombre,
    required this.fecha,
    this.negocioNombre,
    this.folioCorte,
    this.usuarioNombre,
    super.key,
  });

  final String sucursalNombre;
  final DateTime fecha;
  final String? negocioNombre;
  final String? folioCorte;
  final String? usuarioNombre;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: BarroTheme.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: corteSuave,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.storefront_outlined,
            color: BarroTheme.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (negocioNombre != null && negocioNombre!.isNotEmpty)
                Text(
                  negocioNombre!,
                  style: BarroTheme.type(15, 20, weight: FontWeight.w700),
                ),
              Text(
                'Sucursal $sucursalNombre - ${formatFecha(fecha)}',
                style: BarroTheme.type(
                  13,
                  18,
                  weight: FontWeight.w500,
                  color: BarroTheme.secondary,
                ),
              ),
              if (folioCorte != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Corte $folioCorte - ${formatFecha(fecha)}',
                  style: BarroTheme.type(
                    12,
                    16,
                    color: BarroTheme.placeholder,
                  ),
                ),
              ],
              if (usuarioNombre != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Realiza: $usuarioNombre · Sesión actual',
                  style: BarroTheme.type(
                    12,
                    16,
                    color: BarroTheme.placeholder,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

/// Badge que muestra en tiempo real la diferencia calculada en el arqueo de efectivo.
class BadgeDiferencia extends StatelessWidget {
  const BadgeDiferencia({required this.diferencia, super.key});

  final double diferencia;

  @override
  Widget build(BuildContext context) {
    final sinDiferencia = diferencia.abs() < 0.009;
    final esSobrante = diferencia > 0.009;

    final colorTexto = sinDiferencia
        ? const Color(0xFF28704F)
        : esSobrante
        ? const Color(0xFF1B65A4)
        : BarroTheme.error;

    final colorFondo = sinDiferencia
        ? const Color(0xFFEAF5EE)
        : esSobrante
        ? const Color(0xFFEAF2FB)
        : const Color(0xFFFDECE8);

    final icono = sinDiferencia
        ? Icons.check_circle_outline
        : esSobrante
        ? Icons.arrow_upward_rounded
        : Icons.warning_amber_rounded;

    final texto = sinDiferencia
        ? 'Sin diferencia - \$0.00'
        : esSobrante
        ? 'Sobrante: +${formatDinero(diferencia)}'
        : 'Faltante: ${formatDinero(diferencia)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorTexto.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 18, color: colorTexto),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              texto,
              style: BarroTheme.type(
                13,
                18,
                weight: FontWeight.w700,
                color: colorTexto,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Alerta visual para pedidos cancelados cuyo anticipo fue descontado.
class TarjetaCancelacionPedido extends StatelessWidget {
  const TarjetaCancelacionPedido({required this.detalle, super.key});

  final CancelacionPedido detalle;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFDECE8),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: BarroTheme.error.withValues(alpha: 0.3)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: BarroTheme.error,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.priority_high_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pedido ${detalle.folio} cancelado',
                style: BarroTheme.type(
                  14,
                  19,
                  weight: FontWeight.w700,
                  color: BarroTheme.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Anticipo previo: ${formatDinero(detalle.monto)} · ${detalle.metodoPago}',
                style: BarroTheme.type(
                  13,
                  18,
                  color: BarroTheme.secondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Descontado automáticamente del corte',
                style: BarroTheme.type(
                  12,
                  16,
                  weight: FontWeight.w500,
                  color: BarroTheme.error,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

