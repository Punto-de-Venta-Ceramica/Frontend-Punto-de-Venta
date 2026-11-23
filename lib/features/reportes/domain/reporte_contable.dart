import 'dart:typed_data';

import 'movimiento_reporte.dart';

enum PeriodoReporte {
  diario('Diario', 'SEMANAL'),
  semanal('Semanal', 'SEMANAL'),
  mensual('Mensual', 'MENSUAL');

  const PeriodoReporte(this.etiqueta, this.codigoConsulta);

  final String etiqueta;
  final String codigoConsulta;

  bool get permiteExportar => this != diario;

  DateTime inicio(DateTime fecha) => switch (this) {
    diario => fecha,
    semanal => fecha.subtract(Duration(days: fecha.weekday - DateTime.monday)),
    mensual => DateTime.utc(fecha.year, fecha.month),
  };

  DateTime mover(DateTime fecha, int pasos) => switch (this) {
    diario => fecha.add(Duration(days: pasos)),
    semanal => fecha.add(Duration(days: pasos * 7)),
    mensual => DateTime.utc(fecha.year, fecha.month + pasos),
  };

  ({DateTime desde, DateTime hasta}) rango(DateTime fecha) {
    final desde = inicio(fecha);
    final hasta = mover(desde, 1).subtract(const Duration(days: 1));
    return (desde: desde, hasta: hasta);
  }
}

DateTime fechaCalendario(DateTime fecha) =>
    DateTime.utc(fecha.year, fecha.month, fecha.day);

String fechaIsoReporte(DateTime fecha) =>
    '${fecha.year.toString().padLeft(4, '0')}-'
    '${fecha.month.toString().padLeft(2, '0')}-'
    '${fecha.day.toString().padLeft(2, '0')}';

class ConsultaReporte {
  ConsultaReporte({
    required this.sucursalId,
    required this.periodo,
    required DateTime fecha,
  }) : fecha = fechaCalendario(fecha);

  final int sucursalId;
  final PeriodoReporte periodo;
  final DateTime fecha;
}

class ReporteContable {
  const ReporteContable({
    required this.desde,
    required this.hasta,
    required this.cobrado,
    required this.devuelto,
    required this.neto,
    required this.efectivo,
    required this.tarjeta,
    required this.hayMovimientos,
    this.movimientos = const [],
  });

  final DateTime desde;
  final DateTime hasta;
  final num cobrado;
  final num devuelto;
  final num neto;
  final num efectivo;
  final num tarjeta;
  final bool hayMovimientos;
  final List<MovimientoReporte> movimientos;
}

class ArchivoReporte {
  const ArchivoReporte({required this.nombre, required this.bytes});

  static const tipoExcel =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  final String nombre;
  final Uint8List bytes;
}

class ReporteFailure implements Exception {
  const ReporteFailure(this.mensaje, {this.sesionExpirada = false});

  final String mensaje;
  final bool sesionExpirada;
}
