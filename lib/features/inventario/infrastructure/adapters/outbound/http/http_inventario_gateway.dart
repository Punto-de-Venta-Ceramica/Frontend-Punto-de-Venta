import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import '../../../../application/ports/outbound/inventario_gateway.dart';
import '../../../../domain/existencia_inventario.dart';

class HttpInventarioGateway implements InventarioGateway {
  const HttpInventarioGateway(this._api);
  final ApiClient _api;

  Future<T> _seguro<T>(Future<T> Function() operacion) async {
    try {
      return await operacion();
    } on ApiException catch (e) {
      throw InventarioFailure(e.message, sesionExpirada: e.statusCode == 401);
    } on FormatException {
      throw const InventarioFailure(
        'El servidor devolvió datos de inventario no válidos.',
      );
    }
  }

  @override
  Future<List<ExistenciaInventario>> deSucursal(
    int negocioId,
    int sucursalId,
  ) => _seguro(() async {
    final data = await _api.requestJson(
      'GET',
      'api/inventario?negocioId=$negocioId&sucursalId=$sucursalId',
    );
    if (data is! List) throw const FormatException();
    return [
      for (final item in data)
        () {
          if (item is! Map<String, dynamic>) throw const FormatException();
          final id = item['id'];
          final nombre = item['productoNombre'];
          final existencia = item['existencia'];
          if (id is! int || nombre is! String || existencia is! int) {
            throw const FormatException();
          }
          return ExistenciaInventario(
            inventarioId: id,
            productoNombre: nombre,
            existencia: existencia,
          );
        }(),
    ];
  });

  @override
  Future<int> ajustar(int inventarioId, int cantidad) => _seguro(() async {
    final json = await _api.requestJson(
      'PATCH',
      'api/inventario/$inventarioId/existencia',
      body: {'cantidad': cantidad},
    );
    if (json is! Map<String, dynamic> || json['existencia'] is! int) {
      throw const FormatException();
    }
    return json['existencia'] as int;
  });
}
