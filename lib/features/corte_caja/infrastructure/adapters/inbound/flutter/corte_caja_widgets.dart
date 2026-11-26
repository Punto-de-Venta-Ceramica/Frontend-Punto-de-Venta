import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/core/infrastructure/widgets/barro_header.dart';
import '../../../../domain/corte_caja.dart';

const Color corteSuave = Color(0xFFF7E7DF);
const Color corteCardBg = Colors.white;

/// Terracota oscuro para degradados de tarjetas destacadas.
const Color corteOscuro = Color(0xFF8E3521);

/// Paleta de apoyo para efectivo (verde) y tarjeta (azul).
const Color corteVerde = Color(0xFF28704F);
const Color corteVerdeSuave = Color(0xFFE8F5EE);
const Color corteAzul = Color(0xFF2F5C8F);
const Color corteAzulSuave = Color(0xFFEAF1FA);

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
  // El servidor envía instantes en UTC: se muestran en la hora del dispositivo.
  final local = fecha.toLocal();
  final base = formatFecha(local);
  final hora = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '$base $hora:$min';
}

/// Cabecera superior con logo de BarroControl y chip de rol.
class CorteCabecera extends StatelessWidget {
  const CorteCabecera({required this.esPropietario, super.key});

  final bool esPropietario;

  @override
  Widget build(BuildContext context) => const BarroHeader();
}

/// Cuadro de icono con fondo suave.
class CorteIcono extends StatelessWidget {
  const CorteIcono(
    this.icono, {
    this.color = BarroTheme.primary,
    this.fondo = corteSuave,
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

/// Título de pantalla con icono destacado, subtítulo y acción opcional.
class CorteTitulo extends StatelessWidget {
  const CorteTitulo({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    this.accion,
    this.subtituloIcono,
    super.key,
  });

  final IconData icono;
  final String titulo;
  final String subtitulo;
  final IconData? subtituloIcono;
  final Widget? accion;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [BarroTheme.primary, corteOscuro],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: BarroTheme.primary.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icono, color: Colors.white, size: 26),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: BarroTheme.type(26, 33, weight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                if (subtituloIcono != null) ...[
                  Icon(subtituloIcono, size: 15, color: BarroTheme.secondary),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(
                    subtitulo,
                    style: BarroTheme.type(14, 20, color: BarroTheme.secondary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      if (accion != null) ...[const SizedBox(width: 8), accion!],
    ],
  );
}

/// Tarjeta blanca con encabezado de icono, usada para agrupar información.
class CorteSeccion extends StatelessWidget {
  const CorteSeccion({
    required this.icono,
    required this.titulo,
    required this.child,
    this.subtitulo,
    this.trailing,
    super.key,
  });

  final IconData icono;
  final String titulo;
  final String? subtitulo;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: BarroTheme.border),
      boxShadow: [
        BoxShadow(
          color: BarroTheme.text.withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            CorteIcono(icono),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: BarroTheme.type(16, 22, weight: FontWeight.w700),
                  ),
                  if (subtitulo != null)
                    Text(
                      subtitulo!,
                      style: BarroTheme.type(
                        12,
                        17,
                        color: BarroTheme.secondary,
                      ),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

/// Pastilla pequeña con icono y texto.
class CortePastilla extends StatelessWidget {
  const CortePastilla({
    required this.icono,
    required this.texto,
    this.color = BarroTheme.secondary,
    this.fondo = BarroTheme.background,
    super.key,
  });

  final IconData icono;
  final String texto;
  final Color color;
  final Color fondo;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: fondo,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 14, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            texto,
            overflow: TextOverflow.ellipsis,
            style: BarroTheme.type(
              12,
              16,
              weight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    ),
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
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: BarroTheme.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CorteIcono(Icons.storefront_outlined, tamano: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (negocioNombre != null && negocioNombre!.isNotEmpty)
                    Text(
                      negocioNombre!,
                      style: BarroTheme.type(15, 20, weight: FontWeight.w700),
                    ),
                  if (sucursalNombre.isNotEmpty)
                    Text(
                      textoSucursal(sucursalNombre),
                      style: BarroTheme.type(
                        13,
                        18,
                        weight: FontWeight.w500,
                        color: BarroTheme.secondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: BarroTheme.border),
        if (folioCorte != null)
          _DatoCorte(
            icono: Icons.confirmation_number_outlined,
            etiqueta: 'Folio del corte',
            valor: folioCorte!,
          ),
        if (usuarioNombre != null && usuarioNombre!.isNotEmpty)
          _DatoCorte(
            icono: Icons.person_outline_rounded,
            etiqueta: 'Responsable',
            valor: usuarioNombre!,
          ),
        _DatoCorte(
          icono: Icons.event_outlined,
          etiqueta: 'Fecha corte',
          valor: formatFechaHora(fecha),
        ),
      ],
    ),
  );
}

/// Fila "icono · etiqueta ........ valor" de la tarjeta del corte.
class _DatoCorte extends StatelessWidget {
  const _DatoCorte({
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Row(
      children: [
        Icon(icono, size: 18, color: BarroTheme.secondary),
        const SizedBox(width: 8),
        Text(
          etiqueta,
          style: BarroTheme.type(
            13,
            18,
            weight: FontWeight.w500,
            color: BarroTheme.secondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            valor,
            textAlign: TextAlign.end,
            style: BarroTheme.type(14, 20, weight: FontWeight.w700),
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
        ? corteVerde
        : esSobrante
        ? const Color(0xFF1B65A4)
        : BarroTheme.error;

    final colorFondo = sinDiferencia
        ? const Color(0xFFEAF5EE)
        : esSobrante
        ? const Color(0xFFEAF2FB)
        : const Color(0xFFFDECE8);

    final icono = sinDiferencia
        ? Icons.check_circle_rounded
        : esSobrante
        ? Icons.arrow_circle_up_rounded
        : Icons.warning_rounded;

    final texto = sinDiferencia
        ? 'Sin diferencia - \$0.00'
        : esSobrante
        ? 'Sobrante: +${formatDinero(diferencia)}'
        : 'Faltante: ${formatDinero(diferencia)}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(20),
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
      color: const Color(0xFFFFF5F3),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: BarroTheme.error.withValues(alpha: 0.25)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CorteIcono(
          Icons.event_busy_rounded,
          color: BarroTheme.error,
          fondo: Color(0xFFFDE1DC),
          tamano: 40,
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
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  CortePastilla(
                    icono: Icons.payments_outlined,
                    texto: 'Anticipo ${formatDinero(detalle.monto)}',
                    fondo: Colors.white,
                  ),
                  CortePastilla(
                    icono: Icons.account_balance_wallet_outlined,
                    texto: detalle.metodoPago,
                    fondo: Colors.white,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.remove_circle_outline_rounded,
                    size: 15,
                    color: BarroTheme.error,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'Descontado automáticamente del corte',
                      style: BarroTheme.type(
                        12,
                        16,
                        weight: FontWeight.w600,
                        color: BarroTheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// "Sucursal Centro"; si el nombre ya empieza con "Sucursal" no se repite.
String textoSucursal(String nombre) =>
    nombre.toLowerCase().startsWith('sucursal') ? nombre : 'Sucursal $nombre';

/// Acceso destacado al historial de cortes (solo propietario).
class CorteBotonHistorial extends StatelessWidget {
  const CorteBotonHistorial({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: BarroTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const CorteIcono(Icons.history_rounded, tamano: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Historial de cortes',
                      style: BarroTheme.type(15, 21, weight: FontWeight.w700),
                    ),
                    Text(
                      'Consulta los cortes anteriores',
                      style: BarroTheme.type(
                        12,
                        17,
                        color: BarroTheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: BarroTheme.placeholder,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Inicio de la información de la caja: de cuándo es el turno y quién lo lleva.
/// Sin [corte] (caja cerrada) muestra la fecha de hoy. Si el turno abierto es
/// de un día anterior, lo avisa para que no quede olvidado.
class CorteTurnoInfo extends StatelessWidget {
  const CorteTurnoInfo({
    required this.responsable,
    this.corte,
    this.ahora,
    super.key,
  });

  final CorteCaja? corte;
  final String responsable;

  /// Solo para pruebas; por defecto, la hora actual.
  final DateTime? ahora;

  @override
  Widget build(BuildContext context) {
    final hoy = ahora ?? DateTime.now();
    final turno = corte;
    String texto;
    IconData icono = Icons.schedule_rounded;
    String? aviso;
    if (turno == null) {
      texto = 'Hoy, ${formatFecha(hoy)}';
      icono = Icons.event_outlined;
    } else if (turno.cerrado) {
      texto =
          'Turno cerrado: ${formatFechaHora(turno.fechaHoraCierre ?? turno.fechaHoraApertura)}';
    } else {
      texto = 'Turno abierto: ${formatFechaHora(turno.fechaHoraApertura)}';
      final apertura = turno.fechaHoraApertura.toLocal();
      final dias = DateTime(hoy.year, hoy.month, hoy.day)
          .difference(DateTime(apertura.year, apertura.month, apertura.day))
          .inDays;
      if (dias >= 1) {
        aviso = dias == 1
            ? 'Este turno sigue abierto desde ayer. Revisa si debes cerrarlo.'
            : 'Este turno sigue abierto desde hace $dias días. Revisa si debes cerrarlo.';
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'TURNO ACTUAL',
              style: BarroTheme.type(
                12,
                16,
                weight: FontWeight.w700,
                color: BarroTheme.placeholder,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(child: Divider(height: 1, color: BarroTheme.border)),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            CortePastilla(icono: icono, texto: texto, fondo: corteSuave),
            if (responsable.isNotEmpty)
              CortePastilla(
                icono: Icons.person_outline_rounded,
                texto: 'Responsable: $responsable',
                fondo: corteSuave,
              ),
          ],
        ),
        if (aviso != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6E5),
              border: Border.all(color: const Color(0xFFF2D59B)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 20,
                  color: Color(0xFF9A6200),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    aviso,
                    style: BarroTheme.type(
                      13,
                      19,
                      color: const Color(0xFF6B4500),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
