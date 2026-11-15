import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';

import '../../../../application/ports/outbound/reportes_gateway.dart';
import '../../../../domain/reporte_contable.dart';

class HttpReportesGateway implements ReportesGateway {
  const HttpReportesGateway(this._api);

  final ApiClient _api;

  @override
  Future<ReporteContable> consultar(ConsultaReporte consulta) =>
      _solicitar(() async {
        final reporte = await _api.getJson(_ruta(consulta));
        final dias = [
          for (final semana in _objetos(reporte['semanas']))
            ..._objetos(semana['dias']),
        ];
        if (consulta.periodo == PeriodoReporte.diario) {
          final fecha = fechaIsoReporte(consulta.fecha);
          final dia = dias.where((dia) => dia['fecha'] == fecha).firstOrNull;
          if (dia == null) throw const FormatException();
          return _resumen(
            dia,
            consulta.fecha,
            consulta.fecha,
            _hayMovimientos(dia),
          );
        }
        return _resumen(
          reporte,
          _fecha(reporte['desde']),
          _fecha(reporte['hasta']),
          dias.any(_hayMovimientos),
        );
      });

  @override
  Future<ArchivoReporte> descargar(ConsultaReporte consulta) =>
      _solicitar(() async {
        final bytes = await _api.getBytes(
          _ruta(consulta, excel: true),
          contentType: ArchivoReporte.tipoExcel,
        );
        final rango = consulta.periodo.rango(consulta.fecha);
        return ArchivoReporte(
          nombre:
              'reporte-sucursal-${consulta.sucursalId}-'
              '${fechaIsoReporte(rango.desde)}-${fechaIsoReporte(rango.hasta)}',
          bytes: bytes,
        );
      });

  static String _ruta(ConsultaReporte consulta, {bool excel = false}) => Uri(
    path:
        'api/sucursales/${consulta.sucursalId}/reportes/movimientos${excel ? '/excel' : ''}',
    queryParameters: {
      'periodo': consulta.periodo.codigoConsulta,
      'fecha': fechaIsoReporte(consulta.fecha),
    },
  ).toString();

  static ReporteContable _resumen(
    Map<String, dynamic> datos,
    DateTime desde,
    DateTime hasta,
    bool hayMovimientos,
  ) {
    final resumen = datos['resumen'] as Map<String, dynamic>;
    final general = resumen['general'] as Map<String, dynamic>;
    final efectivo = resumen['efectivo'] as Map<String, dynamic>;
    final tarjeta = resumen['tarjeta'] as Map<String, dynamic>;
    return ReporteContable(
      desde: desde,
      hasta: hasta,
      cobrado: general['cobrado'] as num,
      devuelto: general['devuelto'] as num,
      neto: general['neto'] as num,
      efectivo: efectivo['neto'] as num,
      tarjeta: tarjeta['neto'] as num,
      hayMovimientos: hayMovimientos,
    );
  }

  static Iterable<Map<String, dynamic>> _objetos(Object? lista) =>
      (lista as List).cast<Map<String, dynamic>>();

  static bool _hayMovimientos(Map<String, dynamic> dia) =>
      (dia['efectivo'] as List).isNotEmpty ||
      (dia['tarjeta'] as List).isNotEmpty;

  static DateTime _fecha(Object? fecha) =>
      fechaCalendario(DateTime.parse(fecha as String));

  static Future<T> _solicitar<T>(Future<T> Function() accion) async {
    try {
      return await accion();
    } on ApiException catch (e) {
      throw ReporteFailure(
        e.detail ?? e.message,
        sesionExpirada: e.statusCode == 401,
      );
    } on FormatException {
      throw const ReporteFailure('La API no devolvió un reporte válido.');
    } on TypeError {
      throw const ReporteFailure('La API no devolvió un reporte válido.');
    }
  }
}
