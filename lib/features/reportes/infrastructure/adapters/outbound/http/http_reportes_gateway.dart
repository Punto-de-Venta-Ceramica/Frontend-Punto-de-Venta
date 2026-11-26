import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';

import '../../../../application/ports/outbound/reportes_gateway.dart';
import '../../../../domain/reporte_contable.dart';
import '../../../../domain/movimiento_reporte.dart';

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
            movimientos: _movimientos(dia),
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
      if (consulta.periodo == PeriodoReporte.diario && !excel)
        'incluirAbiertos': 'true',
    },
  ).toString();

  static ReporteContable _resumen(
    Map<String, dynamic> datos,
    DateTime desde,
    DateTime hasta,
    bool hayMovimientos, {
    List<MovimientoReporte> movimientos = const [],
  }) {
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
      movimientos: movimientos,
    );
  }

  static List<MovimientoReporte> _movimientos(Map<String, dynamic> dia) {
    final movimientos = [
      for (final dato in [
        ..._objetos(dia['efectivo']),
        ..._objetos(dia['tarjeta']),
      ])
        MovimientoReporte(
          id: dato['id'] as int,
          fechaHora: DateTime.parse(dato['fechaHora'] as String),
          horaLocal: _hora(dato),
          tipo: switch (dato['tipo']) {
            'VENTA' => TipoMovimientoReporte.venta,
            'ANTICIPO' => TipoMovimientoReporte.anticipo,
            'LIQUIDACION' => TipoMovimientoReporte.liquidacion,
            'DEVOLUCION' => TipoMovimientoReporte.devolucion,
            _ => throw const FormatException(),
          },
          medioPago: switch (dato['medioPago']) {
            'EFECTIVO' => MedioPagoReporte.efectivo,
            'TARJETA' => MedioPagoReporte.tarjeta,
            _ => throw const FormatException(),
          },
          referencia: dato['referencia'] as String,
          importe: dato['importe'] as num,
          vendedor: _nombreUsuario(dato['vendedor']),
          creadorPedido: _nombreUsuario(dato['creadorPedido']),
          productos: [
            for (final producto in _objetos(dato['productos']))
              ProductoMovimientoReporte(
                id: producto['id'] as int,
                nombre: producto['nombre'] as String,
                cantidad: producto['cantidad'] as int,
              ),
          ],
        ),
    ];
    movimientos.sort((a, b) {
      final fecha = b.fechaHora.compareTo(a.fechaHora);
      if (fecha != 0) return fecha;
      final id = b.id.compareTo(a.id);
      return id != 0 ? id : a.tipo.index.compareTo(b.tipo.index);
    });
    return List.unmodifiable(movimientos);
  }

  static String? _nombreUsuario(Object? usuario) =>
      (usuario as Map<String, dynamic>?)?['nombre'] as String?;

  static String _hora(Map<String, dynamic> movimiento) {
    if (movimiento['horaLocal'] case final String hora) return hora;
    final fecha = DateTime.parse(movimiento['fechaHora'] as String).toLocal();
    return '${fecha.hour.toString().padLeft(2, '0')}:'
        '${fecha.minute.toString().padLeft(2, '0')}';
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
