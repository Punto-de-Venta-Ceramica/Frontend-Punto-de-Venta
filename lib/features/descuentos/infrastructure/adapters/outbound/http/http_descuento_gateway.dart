import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import '../../../../application/ports/outbound/descuento_gateway.dart';
import '../../../../domain/descuento.dart';

class HttpDescuentoGateway implements DescuentoGateway {
  const HttpDescuentoGateway(this._api);
  final ApiClient _api;

  Future<T> _seguro<T>(Future<T> Function() operacion) async {
    try {
      return await operacion();
    } on ApiException catch (e) {
      throw DescuentoFailure(
        e.message,
        fieldErrors: e.fieldErrors,
        sesionExpirada: e.statusCode == 401,
      );
    } on FormatException {
      throw const DescuentoFailure(
        'El servidor devolvió datos de descuento no válidos.',
      );
    }
  }

  Map<String, dynamic> _map(Object? data) {
    if (data is! Map<String, dynamic>) throw const FormatException();
    return data;
  }

  int _entero(Object? value) {
    if (value is! int || value <= 0) throw const FormatException();
    return value;
  }

  List<int> _ids(Object? value) {
    if (value is! List) throw const FormatException();
    return value.map(_entero).toList(growable: false);
  }

  Descuento _descuento(Object? data) {
    final json = _map(data);
    final nombre = json['nombre'];
    final porcentaje = json['porcentaje'];
    final activo = json['activo'];
    final maximo = json['cantidadMaxima'];
    if (nombre is! String ||
        porcentaje is! num ||
        activo is! bool ||
        (maximo != null && (maximo is! int || maximo <= 0))) {
      throw const FormatException();
    }
    return Descuento(
      id: _entero(json['id']),
      nombre: nombre,
      cantidadMinima: _entero(json['cantidadMinima']),
      cantidadMaxima: maximo as int?,
      porcentaje: porcentaje.toDouble(),
      activo: activo,
      productoIds: _ids(json['productoIds']),
      categoriaIds: _ids(json['categoriaIds']),
      areaIds: _ids(json['areaIds']),
    );
  }

  String _ruta(int negocioId, [int? id, String? resto]) =>
      'api/negocios/$negocioId/descuentos${id == null ? '' : '/$id'}${resto == null ? '' : '/$resto'}';

  Map<String, dynamic> _cuerpo(DatosDescuento datos) => {
    'nombre': datos.nombre.trim(),
    'cantidadMinima': datos.cantidadMinimaNumero,
    'cantidadMaxima': datos.cantidadMaximaNumero,
    'porcentaje': datos.porcentajeNumero,
  };

  List<Object?> _lista(Object? data) {
    if (data is! List) throw const FormatException();
    return data;
  }

  String _texto(Object? value) {
    if (value is! String) throw const FormatException();
    return value;
  }

  @override
  Future<List<Descuento>> listar(int negocioId) => _seguro(() async {
    final data = await _api.requestJson('GET', _ruta(negocioId));
    return _lista(data).map(_descuento).toList(growable: false);
  });

  @override
  Future<Descuento> crear(int negocioId, DatosDescuento datos) => _seguro(
    () async => _descuento(
      await _api.requestJson('POST', _ruta(negocioId), body: _cuerpo(datos)),
    ),
  );

  @override
  Future<Descuento> editar(int negocioId, int id, DatosDescuento datos) =>
      _seguro(
        () async => _descuento(
          await _api.requestJson(
            'PUT',
            _ruta(negocioId, id),
            body: _cuerpo(datos),
          ),
        ),
      );

  @override
  Future<void> eliminar(int negocioId, int id) => _seguro(() async {
    await _api.requestJson('DELETE', _ruta(negocioId, id));
  });

  @override
  Future<Descuento> cambiarEstado(
    int negocioId,
    int id, {
    required bool activo,
  }) => _seguro(
    () async => _descuento(
      await _api.requestJson(
        'PATCH',
        _ruta(negocioId, id, activo ? 'activar' : 'desactivar'),
      ),
    ),
  );

  @override
  Future<Descuento> asignar(
    int negocioId,
    int id,
    DestinoDescuento destino,
    int destinoId,
  ) => _seguro(
    () async => _descuento(
      await _api.requestJson(
        'PUT',
        _ruta(negocioId, id, '${destino.segmento}/$destinoId'),
      ),
    ),
  );

  @override
  Future<Descuento> quitar(
    int negocioId,
    int id,
    DestinoDescuento destino,
    int destinoId,
  ) => _seguro(
    () async => _descuento(
      await _api.requestJson(
        'DELETE',
        _ruta(negocioId, id, '${destino.segmento}/$destinoId'),
      ),
    ),
  );

  /// El backend lista las categorías por área, así que se consolidan todas.
  @override
  Future<CatalogoDescuento> catalogo(int negocioId) => _seguro(() async {
    final productosJson = _lista(
      await _api.requestJson(
        'GET',
        'api/productos/catalogo?negocioId=$negocioId',
      ),
    );
    final areasJson = _lista(
      await _api.requestJson('GET', 'api/negocios/$negocioId/areas'),
    );
    final areas = [
      for (final a in areasJson)
        ElementoCatalogo(
          id: _entero(_map(a)['id']),
          nombre: _texto(_map(a)['nombre']),
        ),
    ];
    final categoriasPorArea = await Future.wait([
      for (final area in areas)
        _api
            .requestJson(
              'GET',
              'api/negocios/$negocioId/areas/${area.id}/categorias',
            )
            .then(
              (data) => [
                for (final c in _lista(data))
                  ElementoCatalogo(
                    id: _entero(_map(c)['id']),
                    nombre: _texto(_map(c)['nombre']),
                    contexto: area.nombre,
                  ),
              ],
            ),
    ]);
    final categorias = [for (final lista in categoriasPorArea) ...lista];
    final nombreCategoria = {for (final c in categorias) c.id: c.nombre};
    return CatalogoDescuento(
      productos: [
        for (final p in productosJson)
          ElementoCatalogo(
            id: _entero(_map(p)['id']),
            nombre: _texto(_map(p)['nombre']),
            contexto: nombreCategoria[_map(p)['categoriaId']] ?? '',
          ),
      ],
      categorias: categorias,
      areas: areas,
    );
  });
}
