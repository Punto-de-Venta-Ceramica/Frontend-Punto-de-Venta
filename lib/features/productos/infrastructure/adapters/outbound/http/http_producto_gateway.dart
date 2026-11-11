import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import '../../../../application/ports/outbound/producto_gateway.dart';
import '../../../../domain/producto.dart';

/// Habla solo con el catálogo; las existencias van por [HttpExistenciasGateway].
class HttpProductoGateway implements ProductoGateway {
  const HttpProductoGateway(this._api);
  final ApiClient _api;

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
        'El servidor devolvió datos de producto no válidos.',
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

  String _texto(Object? value) {
    if (value is! String) throw const FormatException();
    return value;
  }

  String? _textoOpcional(Object? value) => value == null ? null : _texto(value);

  double _numero(Object? value) {
    if (value is! num) throw const FormatException();
    return value.toDouble();
  }

  List<T> _lista<T>(Object? data, T Function(Object?) parse) {
    if (data is! List) throw const FormatException();
    return data.map(parse).toList(growable: false);
  }

  Producto _producto(Object? data) {
    final json = _map(data);
    final d = json['descuento'];
    return Producto(
      id: _id(json['id']),
      nombre: _texto(json['nombre']),
      precio: _numero(json['precio']),
      categoriaId: json['categoriaId'] == null
          ? null
          : _id(json['categoriaId']),
      categoriaNombre: _textoOpcional(json['categoriaNombre']),
      areaId: json['areaId'] == null ? null : _id(json['areaId']),
      areaNombre: _textoOpcional(json['areaNombre']),
      imagenUrl: _textoOpcional(json['imagenUrl']),
      imagenPublicId: _textoOpcional(json['imagenPublicId']),
      descuento: d == null
          ? null
          : DescuentoProducto(
              cantidadMinima: _map(d)['cantidadMinima'] is int
                  ? _map(d)['cantidadMinima'] as int
                  : throw const FormatException(),
              porcentaje: _numero(_map(d)['porcentaje']),
            ),
    );
  }

  Map<String, dynamic>? _descuento(DatosProducto datos) => datos.tieneDescuento
      ? {
          'cantidadMinima': datos.cantidadMinimaNumero,
          'porcentaje': datos.porcentajeNumero,
        }
      : null;

  @override
  Future<List<NegocioProducto>> negocios() => _seguro(
    () async => _lista(await _api.requestJson('GET', 'api/negocios'), (data) {
      final json = _map(data);
      return NegocioProducto(
        id: _id(json['id']),
        nombre: _texto(json['nombre']),
      );
    }),
  );

  @override
  Future<List<AreaProducto>> areas(int negocioId) =>
      _seguro(() => _areas(negocioId));

  Future<List<AreaProducto>> _areas(int negocioId) async => _lista(
    await _api.requestJson('GET', 'api/negocios/$negocioId/areas'),
    (data) {
      final json = _map(data);
      return AreaProducto(id: _id(json['id']), nombre: _texto(json['nombre']));
    },
  );

  /// El backend lista las categorías por área, así que se consolidan todas.
  @override
  Future<List<CategoriaProducto>> categorias(int negocioId) =>
      _seguro(() async {
        final areas = await _areas(negocioId);
        final porArea = await Future.wait([
          for (final area in areas)
            _api
                .requestJson(
                  'GET',
                  'api/negocios/$negocioId/areas/${area.id}/categorias',
                )
                .then(
                  (data) => _lista(data, (item) {
                    final json = _map(item);
                    return CategoriaProducto(
                      id: _id(json['id']),
                      areaId: _id(json['areaId']),
                      nombre: _texto(json['nombre']),
                    );
                  }),
                ),
        ]);
        return [for (final categorias in porArea) ...categorias];
      });

  @override
  Future<List<SucursalProducto>> sucursales(int negocioId) => _seguro(
    () async => _lista(
      await _api.requestJson(
        'POST',
        'api/sucursales/consultar',
        body: {'negocioId': negocioId},
      ),
      (data) {
        final json = _map(data);
        return SucursalProducto(
          id: _id(json['id']),
          nombre: _texto(json['nombre']),
        );
      },
    ),
  );

  @override
  Future<PaginaProductos> listar(
    int negocioId, {
    int pagina = 0,
    FiltroProductos filtro = const FiltroProductos(),
  }) => _seguro(() async {
    final consulta = <String>[
      'negocioId=$negocioId',
      'page=$pagina',
      if (filtro.areaId != null) 'areaId=${filtro.areaId}',
      if (filtro.categoriaId != null) 'categoriaId=${filtro.categoriaId}',
      if (filtro.sucursalId != null) 'sucursalId=${filtro.sucursalId}',
      if (filtro.buscar.trim().isNotEmpty)
        'buscar=${Uri.encodeQueryComponent(filtro.buscar.trim())}',
    ].join('&');
    final json = _map(await _api.requestJson('GET', 'api/productos?$consulta'));
    final total = json['totalElementos'];
    final numeroPagina = json['pagina'];
    final ultima = json['ultima'];
    if (total is! int || numeroPagina is! int || ultima is! bool) {
      throw const FormatException();
    }
    return PaginaProductos(
      productos: _lista(json['contenido'], _producto),
      pagina: numeroPagina,
      ultima: ultima,
      total: total,
    );
  });

  @override
  Future<Producto> consultar(int id) => _seguro(
    () async => _producto(await _api.requestJson('GET', 'api/productos/$id')),
  );

  @override
  Future<Producto> crear(DatosProducto datos) => _seguro(() async {
    return _producto(
      await _api.requestJson(
        'POST',
        'api/productos',
        body: {
          'nombre': datos.nombre.trim(),
          'precio': datos.precioNumero,
          'categoriaId': datos.categoriaId,
          'imagenUrl': datos.imagenUrl,
          'imagenPublicId': datos.imagenPublicId,
          'descuento': _descuento(datos),
          'existencias': [
            for (final e in datos.existencias)
              {'sucursalId': e.sucursalId, 'existencia': e.existencia},
          ],
        },
      ),
    );
  });

  @override
  Future<Producto> editar(int id, DatosProducto datos) => _seguro(() async {
    return _producto(
      await _api.requestJson(
        'PUT',
        'api/productos/$id',
        body: {
          'nombre': datos.nombre.trim(),
          'precio': datos.precioNumero,
          'categoriaId': datos.categoriaId,
          'imagenUrl': datos.imagenUrl,
          'imagenPublicId': datos.imagenPublicId,
          'descuento': _descuento(datos),
        },
      ),
    );
  });

  @override
  Future<void> eliminar(int id) => _seguro(() async {
    await _api.requestJson('DELETE', 'api/productos/$id');
  });
}
