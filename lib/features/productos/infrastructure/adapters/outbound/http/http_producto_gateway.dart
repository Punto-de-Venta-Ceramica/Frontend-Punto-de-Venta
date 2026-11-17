import 'package:punto_de_venta/core/infrastructure/cache/consultas_compartidas.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import '../../../../application/ports/outbound/producto_gateway.dart';
import '../../../../domain/producto.dart';

/// Habla solo con el catálogo; las existencias van por [HttpExistenciasGateway].
class HttpProductoGateway implements ProductoGateway {
  const HttpProductoGateway(
    this._api, {
    this.sucursalEmpleado,
    ConsultasCompartidas? compartidas,
  }) : _compartidas = compartidas;
  final ApiClient _api;

  /// Caché de negocios y sucursales que comparten los módulos.
  final ConsultasCompartidas? _compartidas;

  /// Sucursal del empleado: el backend solo le permite consultar el catálogo
  /// de una sucursal a la que está asignado.
  final int? sucursalEmpleado;

  String get _alcance =>
      sucursalEmpleado == null ? '' : '?sucursalId=$sucursalEmpleado';

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
      // El listado no trae descuentos; el detalle trae la lista de escalones.
      descuentos: json['descuentos'] == null
          ? const []
          : _lista(json['descuentos'], _descuentoProducto),
    );
  }

  DescuentoProducto _descuentoProducto(Object? data) {
    final json = _map(data);
    final minimo = json['cantidadMinima'];
    final maximo = json['cantidadMaxima'];
    if (minimo is! int || (maximo != null && maximo is! int)) {
      throw const FormatException();
    }
    return DescuentoProducto(
      cantidadMinima: minimo,
      cantidadMaxima: maximo as int?,
      porcentaje: _numero(json['porcentaje']),
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
    () async => _lista(
      await (_compartidas?.negocios() ??
          _api.requestJson('GET', 'api/negocios')),
      (data) {
        final json = _map(data);
        return NegocioProducto(
          id: _id(json['id']),
          nombre: _texto(json['nombre']),
        );
      },
    ),
  );

  @override
  Future<List<AreaProducto>> areas(int negocioId) => _seguro(
    () async => _lista(
      await _api.requestJson('GET', 'api/negocios/$negocioId/areas$_alcance'),
      (data) {
        final json = _map(data);
        return AreaProducto(
          id: _id(json['id']),
          nombre: _texto(json['nombre']),
        );
      },
    ),
  );

  /// Todas las categorías del negocio en una sola petición.
  @override
  Future<List<CategoriaProducto>> categorias(int negocioId) => _seguro(
    () async => _lista(
      await _api.requestJson(
        'GET',
        'api/negocios/$negocioId/categorias$_alcance',
      ),
      (data) {
        final json = _map(data);
        return CategoriaProducto(
          id: _id(json['id']),
          areaId: _id(json['areaId']),
          nombre: _texto(json['nombre']),
        );
      },
    ),
  );

  @override
  Future<List<SucursalProducto>> sucursales(int negocioId) => _seguro(
    () async => _lista(
      await (_compartidas?.sucursales(negocioId) ??
          _api.requestJson(
            'POST',
            'api/sucursales/consultar',
            body: {'negocioId': negocioId},
          )),
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
      if (filtro.precioMinimo != null) 'precioMinimo=${filtro.precioMinimo}',
      if (filtro.precioMaximo != null) 'precioMaximo=${filtro.precioMaximo}',
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
    () async =>
        _producto(await _api.requestJson('GET', 'api/productos/$id$_alcance')),
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
