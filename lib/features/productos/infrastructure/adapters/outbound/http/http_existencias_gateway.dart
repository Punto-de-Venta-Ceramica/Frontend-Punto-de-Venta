import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import '../../../../application/ports/outbound/existencias_gateway.dart';
import '../../../../domain/producto.dart';

/// Habla solo con `/api/inventario`.
class HttpExistenciasGateway implements ExistenciasGateway {
  const HttpExistenciasGateway(this._api, {this.alcanceEmpleado});
  final ApiClient _api;

  /// (negocioId, sucursalId) del empleado: consulta las existencias desde el
  /// panel de su sucursal, pues el detalle por producto es del propietario.
  final (int, int)? alcanceEmpleado;

  Future<T> _seguro<T>(Future<T> Function() operacion) async {
    try {
      return await operacion();
    } on ApiException catch (e) {
      throw ProductoFailure(
        e.message,
        fieldErrors: e.fieldErrors,
        sesionExpirada: e.statusCode == 401,
      );
    } on FormatException {
      throw const ProductoFailure(
        'El servidor devolvió datos de inventario no válidos.',
      );
    }
  }

  Map<String, dynamic> _map(Object? data) {
    if (data is! Map<String, dynamic>) throw const FormatException();
    return data;
  }

  int _id(Object? value) {
    if (value is! int || value <= 0) throw const FormatException();
    return value;
  }

  int _existencia(Object? value) {
    if (value is! int) throw const FormatException();
    return value;
  }

  @override
  Future<List<ExistenciaSucursal>> porProducto(int productoId) => _seguro(
    () async {
      final alcance = alcanceEmpleado;
      final data = await _api.requestJson(
        'GET',
        alcance == null
            ? 'api/inventario?productoId=$productoId'
            : 'api/inventario?negocioId=${alcance.$1}&sucursalId=${alcance.$2}',
      );
      if (data is! List) throw const FormatException();
      return [
        for (final item in data)
          if (alcance == null || _map(item)['productoId'] == productoId)
            () {
              final json = _map(item);
              final sucursalNombre = json['sucursalNombre'];
              if (sucursalNombre is! String) throw const FormatException();
              return ExistenciaSucursal(
                inventarioId: _id(json['id']),
                sucursalId: _id(json['sucursalId']),
                sucursalNombre: sucursalNombre,
                existencia: _existencia(json['existencia']),
              );
            }(),
      ];
    },
  );

  @override
  Future<int> ajustar(int inventarioId, int cantidad) => _seguro(() async {
    final json = _map(
      await _api.requestJson(
        'PATCH',
        'api/inventario/$inventarioId/existencia',
        body: {'cantidad': cantidad},
      ),
    );
    return _existencia(json['existencia']);
  });

  @override
  Future<ExistenciaSucursal> asignar(
    int productoId,
    SucursalProducto sucursal,
    int? existencia,
  ) => _seguro(() async {
    final json = _map(
      await _api.requestJson(
        'POST',
        'api/inventario',
        body: {
          'productoId': productoId,
          'sucursalId': sucursal.id,
          'existencia': ?existencia,
        },
      ),
    );
    return ExistenciaSucursal(
      inventarioId: _id(json['id']),
      sucursalId: sucursal.id,
      sucursalNombre: sucursal.nombre,
      existencia: _existencia(json['existencia']),
    );
  });

  @override
  Future<void> quitar(int inventarioId) => _seguro(() async {
    await _api.requestJson('DELETE', 'api/inventario/$inventarioId');
  });
}
