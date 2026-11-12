import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import '../../../../application/ports/outbound/corte_caja_gateway.dart';
import '../../../../domain/corte_caja.dart';

class HttpCorteCajaGateway implements CorteCajaGateway {
  const HttpCorteCajaGateway(this._api);

  final ApiClient _api;

  Future<T> _seguro<T>(Future<T> Function() operacion) async {
    try {
      return await operacion();
    } on ApiException catch (e) {
      final esNoAbierto =
          e.statusCode == 404 ||
          e.code == 'CORTE_CAJA_NO_ABIERTO' ||
          e.message.toLowerCase().contains('no hay un corte de caja abierto');
      throw CorteCajaFailure(
        e.message,
        fieldErrors: e.fieldErrors,
        sesionExpirada: e.statusCode == 401,
        noAbierto: esNoAbierto,
      );
    } on FormatException {
      throw const CorteCajaFailure(
        'El servidor devolvió datos del corte de caja no válidos.',
      );
    }
  }

  Map<String, dynamic> _map(Object? data) {
    if (data is! Map<String, dynamic>) throw const FormatException();
    return data;
  }

  List<Object?> _lista(Object? data) {
    if (data is! List) throw const FormatException();
    return data;
  }

  DesgloseMetodoPago _desglose(Object? value) {
    if (value is! Map<String, dynamic>) {
      return const DesgloseMetodoPago(
        totalVentas: 0,
        anticipos: 0,
        liquidaciones: 0,
        cancelaciones: 0,
        subtotalNeto: 0,
        montoInicial: 0,
        totalEsperado: 0,
      );
    }
    return DesgloseMetodoPago(
      totalVentas: (value['totalVentas'] as num?)?.toDouble() ?? 0.0,
      anticipos: (value['anticipos'] as num?)?.toDouble() ?? 0.0,
      liquidaciones: (value['liquidaciones'] as num?)?.toDouble() ?? 0.0,
      cancelaciones: (value['cancelaciones'] as num?)?.toDouble() ?? 0.0,
      subtotalNeto: (value['subtotalNeto'] as num?)?.toDouble() ?? 0.0,
      montoInicial: (value['montoInicial'] as num?)?.toDouble() ?? 0.0,
      totalEsperado: (value['totalEsperado'] as num?)?.toDouble() ?? 0.0,
    );
  }

  SeccionCancelaciones _cancelaciones(Object? value) {
    if (value is! Map<String, dynamic>) {
      return const SeccionCancelaciones(
        totalCancelaciones: 0,
        cancelacionesEfectivo: 0,
        cancelacionesTarjeta: 0,
        detalles: [],
      );
    }
    final detallesRaw = value['detalles'] as List? ?? const [];
    return SeccionCancelaciones(
      totalCancelaciones:
          (value['totalCancelaciones'] as num?)?.toDouble() ?? 0.0,
      cancelacionesEfectivo:
          (value['cancelacionesEfectivo'] as num?)?.toDouble() ?? 0.0,
      cancelacionesTarjeta:
          (value['cancelacionesTarjeta'] as num?)?.toDouble() ?? 0.0,
      detalles: detallesRaw.map((d) {
        final map = d as Map<String, dynamic>;
        return CancelacionPedido(
          pedidoId: (map['pedidoId'] as num).toInt(),
          folio: map['folio'] as String? ?? '',
          monto: (map['monto'] as num).toDouble(),
          metodoPago: map['metodoPago'] as String? ?? 'EFECTIVO',
          tipoPago: map['tipoPago'] as String? ?? 'ANTICIPO',
          fechaHora: map['fechaHora'] != null
              ? DateTime.parse(map['fechaHora'] as String)
              : DateTime.now(),
        );
      }).toList(growable: false),
    );
  }

  List<ProductoVendido> _productos(Object? value) {
    if (value is! List) return const [];
    return value.map((p) {
      final map = p as Map<String, dynamic>;
      return ProductoVendido(
        idProducto: (map['idProducto'] as num).toInt(),
        nombre: map['nombre'] as String? ?? '',
        cantidad: (map['cantidad'] as num).toInt(),
        precioUnitario: (map['precioUnitario'] as num).toDouble(),
        subtotal: (map['subtotal'] as num).toDouble(),
      );
    }).toList(growable: false);
  }

  CorteCaja _corte(Object? data) {
    final j = _map(data);
    return CorteCaja(
      id: (j['id'] as num).toInt(),
      cajaId: (j['cajaId'] as num).toInt(),
      sucursalId: (j['sucursalId'] as num).toInt(),
      sucursalNombre: j['sucursalNombre'] as String? ?? '',
      usuarioId: (j['usuarioId'] as num).toInt(),
      usuarioNombre: j['usuarioNombre'] as String? ?? '',
      fechaHoraApertura: DateTime.parse(j['fechaHoraApertura'] as String),
      fechaHoraCierre: j['fechaHoraCierre'] != null
          ? DateTime.parse(j['fechaHoraCierre'] as String)
          : null,
      cerrado: j['cerrado'] as bool? ?? false,
      montoInicial: (j['montoInicial'] as num).toDouble(),
      totalVentas: (j['totalVentas'] as num).toDouble(),
      totalAnticipos: (j['totalAnticipos'] as num).toDouble(),
      totalLiquidaciones: (j['totalLiquidaciones'] as num).toDouble(),
      totalCancelaciones: (j['totalCancelaciones'] as num).toDouble(),
      ventasEfectivo: _desglose(j['ventasEfectivo']),
      ventasTarjeta: _desglose(j['ventasTarjeta']),
      cancelacionesPedidos: _cancelaciones(j['cancelacionesPedidos']),
      totalEfectivo: (j['totalEfectivo'] as num).toDouble(),
      totalTarjeta: (j['totalTarjeta'] as num).toDouble(),
      totalEstimado: (j['totalEstimado'] as num).toDouble(),
      totalReal: j['totalReal'] != null
          ? (j['totalReal'] as num).toDouble()
          : null,
      diferencia: j['diferencia'] != null
          ? (j['diferencia'] as num).toDouble()
          : null,
      productos: _productos(j['productos']),
    );
  }

  ResumenCorteCaja _resumen(Map<String, dynamic> j) => ResumenCorteCaja(
    id: (j['id'] as num).toInt(),
    cajaId: (j['cajaId'] as num).toInt(),
    sucursalId: (j['sucursalId'] as num).toInt(),
    sucursalNombre: j['sucursalNombre'] as String? ?? '',
    usuarioId: (j['usuarioId'] as num).toInt(),
    usuarioNombre: j['usuarioNombre'] as String? ?? '',
    fechaHoraApertura: DateTime.parse(j['fechaHoraApertura'] as String),
    fechaHoraCierre: j['fechaHoraCierre'] != null
        ? DateTime.parse(j['fechaHoraCierre'] as String)
        : null,
    cerrado: j['cerrado'] as bool? ?? false,
    montoInicial: (j['montoInicial'] as num).toDouble(),
    totalVentas: (j['totalVentas'] as num).toDouble(),
    totalEstimado: (j['totalEstimado'] as num).toDouble(),
    totalReal: j['totalReal'] != null
        ? (j['totalReal'] as num).toDouble()
        : null,
    diferencia: j['diferencia'] != null
        ? (j['diferencia'] as num).toDouble()
        : null,
  );

  @override
  Future<CorteCaja> abrirCorte({
    required int sucursalId,
    required double montoInicial,
  }) => _seguro(() async {
    final response = await _api.requestJson(
      'POST',
      'api/cortes-caja/abrir',
      body: {'sucursalId': sucursalId, 'montoInicial': montoInicial},
    );
    return _corte(response);
  });

  @override
  Future<CorteCaja?> obtenerCorteActivo(int sucursalId) async {
    try {
      final response = await _api.requestJson(
        'GET',
        'api/cortes-caja/activo?sucursalId=$sucursalId',
      );
      return _corte(response);
    } on ApiException catch (e) {
      if (e.statusCode == 404 ||
          e.code == 'CORTE_CAJA_NO_ABIERTO' ||
          e.message.toLowerCase().contains('no hay un corte de caja abierto') ||
          e.message.toLowerCase().contains('no existe')) {
        return null;
      }
      throw CorteCajaFailure(
        e.message,
        fieldErrors: e.fieldErrors,
        sesionExpirada: e.statusCode == 401,
      );
    } on FormatException {
      throw const CorteCajaFailure(
        'El servidor devolvió datos del corte activo no válidos.',
      );
    }
  }

  @override
  Future<CorteCaja> cerrarCorte({
    required int corteId,
    required double totalReal,
  }) => _seguro(() async {
    final response = await _api.requestJson(
      'POST',
      'api/cortes-caja/$corteId/cerrar',
      body: {'totalReal': totalReal},
    );
    return _corte(response);
  });

  @override
  Future<CorteCaja> consultarCorte(int corteId) => _seguro(() async {
    final response = await _api.requestJson('GET', 'api/cortes-caja/$corteId');
    return _corte(response);
  });

  @override
  Future<List<ResumenCorteCaja>> listarHistorial(
    int sucursalId, {
    int page = 0,
    int size = 20,
  }) =>
      _seguro(() async {
        final response = await _api.requestJson(
          'GET',
          'api/cortes-caja?sucursalId=$sucursalId&page=$page&size=$size',
        );
        final dynamic rawList =
            response is Map<String, dynamic> && response['content'] is List
                ? response['content']
                : response;
        return _lista(rawList)
            .map((item) => _resumen(_map(item)))
            .toList(growable: false);
      });
}

