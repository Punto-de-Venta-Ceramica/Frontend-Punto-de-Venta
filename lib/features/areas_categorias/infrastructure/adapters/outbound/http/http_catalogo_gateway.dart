import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import '../../../../application/ports/outbound/catalogo_gateway.dart';
import '../../../../domain/catalogo.dart';

class HttpCatalogoGateway implements CatalogoGateway {
  const HttpCatalogoGateway(this._api);
  final ApiClient _api;

  Future<T> _seguro<T>(
    Future<T> Function() operacion, {
    String? mensajeConflicto,
  }) async {
    try {
      return await operacion();
    } on ApiException catch (e) {
      throw CatalogoFailure(
        e.statusCode == 409 && mensajeConflicto != null
            ? mensajeConflicto
            : e.message,
        fieldErrors: e.fieldErrors,
        sesionExpirada: e.statusCode == 401,
      );
    } on FormatException {
      throw const CatalogoFailure(
        'El servidor devolvió datos de catálogo no válidos.',
      );
    }
  }

  String _areas(int negocioId) => 'api/negocios/$negocioId/areas';
  String _categorias(int negocioId, int areaId) =>
      '${_areas(negocioId)}/$areaId/categorias';

  Map<String, dynamic> _map(Object? data) {
    if (data is! Map<String, dynamic>) throw const FormatException();
    return data;
  }

  int _id(Object? value) {
    if (value is! int || value <= 0) throw const FormatException();
    return value;
  }

  String _texto(Object? value, {bool opcional = false}) {
    if (opcional && value == null) return '';
    if (value is! String) throw const FormatException();
    return value;
  }

  List<T> _lista<T>(Object? data, T Function(Object?) parse) {
    if (data is! List) throw const FormatException();
    return data.map(parse).toList(growable: false);
  }

  AreaCatalogo _area(Object? data, int negocioId, {int? id}) {
    final json = _map(data);
    final area = AreaCatalogo(
      id: _id(json['id']),
      negocioId: _id(json['negocioId']),
      nombre: _texto(json['nombre']),
      descripcion: _texto(json['descripcion'], opcional: true),
    );
    if (area.negocioId != negocioId || (id != null && area.id != id)) {
      throw const FormatException();
    }
    return area;
  }

  CategoriaCatalogo _categoria(Object? data, int areaId, {int? id}) {
    final json = _map(data);
    final categoria = CategoriaCatalogo(
      id: _id(json['id']),
      areaId: _id(json['areaId']),
      nombre: _texto(json['nombre']),
      descripcion: _texto(json['descripcion'], opcional: true),
    );
    if (categoria.areaId != areaId || (id != null && categoria.id != id)) {
      throw const FormatException();
    }
    return categoria;
  }

  Map<String, dynamic> _body(DatosClasificacion datos) => {
    'nombre': datos.nombre.trim(),
    'descripcion': datos.descripcion.trim().isEmpty
        ? null
        : datos.descripcion.trim(),
  };

  @override
  Future<List<AreaCatalogo>> listarAreas(int negocioId) => _seguro(
    () async => _lista(
      await _api.requestJson('GET', _areas(negocioId)),
      (data) => _area(data, negocioId),
    ),
  );

  @override
  Future<AreaCatalogo> consultarArea(int negocioId, int areaId) => _seguro(
    () async => _area(
      await _api.requestJson('GET', '${_areas(negocioId)}/$areaId'),
      negocioId,
      id: areaId,
    ),
  );

  @override
  Future<AreaCatalogo> crearArea(int negocioId, DatosClasificacion datos) =>
      _seguro(
        () async => _area(
          await _api.requestJson('POST', _areas(negocioId), body: _body(datos)),
          negocioId,
        ),
      );

  @override
  Future<AreaCatalogo> editarArea(
    int negocioId,
    int areaId,
    DatosClasificacion datos,
  ) => _seguro(
    () async => _area(
      await _api.requestJson(
        'PUT',
        '${_areas(negocioId)}/$areaId',
        body: _body(datos),
      ),
      negocioId,
      id: areaId,
    ),
  );

  @override
  Future<List<CategoriaCatalogo>> listarCategorias(int negocioId, int areaId) =>
      _seguro(
        () async => _lista(
          await _api.requestJson('GET', _categorias(negocioId, areaId)),
          (data) => _categoria(data, areaId),
        ),
      );

  @override
  Future<void> eliminarArea(int negocioId, int areaId) => _seguro(
    () async {
      await _api.requestJson('DELETE', '${_areas(negocioId)}/$areaId');
    },
    mensajeConflicto:
        'No se puede eliminar el área porque alguna de sus categorías tiene productos relacionados.',
  );

  @override
  Future<void> eliminarCategoria(
    int negocioId,
    int areaId,
    int categoriaId,
  ) => _seguro(
    () async {
      await _api.requestJson(
        'DELETE',
        '${_categorias(negocioId, areaId)}/$categoriaId',
      );
    },
    mensajeConflicto:
        'No se puede eliminar la categoría porque tiene productos relacionados.',
  );

  @override
  Future<CategoriaCatalogo> crearCategoria(
    int negocioId,
    int areaId,
    DatosClasificacion datos,
  ) => _seguro(
    () async => _categoria(
      await _api.requestJson(
        'POST',
        _categorias(negocioId, areaId),
        body: _body(datos),
      ),
      areaId,
    ),
  );

  @override
  Future<CategoriaCatalogo> editarCategoria(
    int negocioId,
    int areaId,
    int categoriaId,
    DatosClasificacion datos,
  ) => _seguro(
    () async => _categoria(
      await _api.requestJson(
        'PUT',
        '${_categorias(negocioId, areaId)}/$categoriaId',
        body: _body(datos),
      ),
      areaId,
      id: categoriaId,
    ),
  );
}
