import '../../domain/producto.dart';
import '../ports/inbound/gestion_productos_use_case.dart';
import '../ports/outbound/existencias_gateway.dart';
import '../ports/outbound/producto_gateway.dart';
import '../ports/outbound/productos_en_cache.dart';

/// Combina el catálogo ([ProductoGateway]) con el inventario
/// ([ExistenciasGateway]): cada adaptador habla con un solo módulo del backend.
class GestionProductos implements GestionProductosUseCase {
  const GestionProductos(
    this._gateway,
    this._existencias, {
    ProductosEnCache? cache,
  }) : _cache = cache;
  final ProductoGateway _gateway;
  final ExistenciasGateway _existencias;
  final ProductosEnCache? _cache;

  /// Producto y existencias en paralelo: son endpoints independientes.
  /// Si falla el producto, su error es el que se informa y el de las
  /// existencias se ignora (sería el mismo 401 o 404).
  Future<Producto> _conExistencias(Future<Producto> producto, int id) async {
    final existencias = _existencias.porProducto(id);
    final Producto p;
    try {
      p = await producto;
    } catch (_) {
      existencias.ignore();
      rethrow;
    }
    return p.conExistencias(await existencias);
  }

  @override
  Producto? detalleGuardado(int id) => _cache?.detalleGuardado(id);

  @override
  void descartarCache() => _cache?.descartar();

  void _validarId(int id) {
    if (id <= 0) {
      throw const ProductoFailure('Selecciona un negocio o producto válido.');
    }
  }

  void _validar(DatosProducto datos) {
    final errores = datos.validar();
    if (errores.isNotEmpty) {
      throw ProductoFailure(
        'Revisa los campos señalados.',
        fieldErrors: errores,
      );
    }
  }

  @override
  Future<List<NegocioProducto>> negocios() => _gateway.negocios();
  @override
  Future<List<AreaProducto>> areas(int negocioId) {
    _validarId(negocioId);
    return _gateway.areas(negocioId);
  }

  @override
  Future<List<CategoriaProducto>> categorias(int negocioId) {
    _validarId(negocioId);
    return _gateway.categorias(negocioId);
  }

  @override
  Future<List<SucursalProducto>> sucursales(int negocioId) {
    _validarId(negocioId);
    return _gateway.sucursales(negocioId);
  }

  @override
  Future<PaginaProductos> listar(
    int negocioId, {
    int pagina = 0,
    FiltroProductos filtro = const FiltroProductos(),
  }) {
    _validarId(negocioId);
    return _gateway.listar(negocioId, pagina: pagina, filtro: filtro);
  }

  @override
  Future<Producto> consultar(int id, int negocioId) {
    _validarId(id);
    _validarId(negocioId);
    return _conExistencias(_gateway.consultar(id), id);
  }

  @override
  Future<Producto> crear(int negocioId, DatosProducto datos) async {
    _validarId(negocioId);
    _validar(datos);
    // Las existencias iniciales se crean en el alta; se leen para tener sus ids.
    final producto = await _gateway.crear(datos);
    return producto.conExistencias(await _existencias.porProducto(producto.id));
  }

  @override
  Future<Producto> editar(int id, int negocioId, DatosProducto datos) {
    _validarId(id);
    _validarId(negocioId);
    _validar(datos);
    // Editar no toca existencias, así que se pueden leer al mismo tiempo.
    return _conExistencias(_gateway.editar(id, datos), id);
  }

  @override
  Future<int> ajustarExistencia(int inventarioId, int cantidad) {
    _validarId(inventarioId);
    if (cantidad == 0) {
      throw const ProductoFailure('Indica una cantidad distinta de cero.');
    }
    if (cantidad.abs() > 1000000) {
      throw const ProductoFailure('El ajuste no puede superar 1,000,000.');
    }
    return _existencias.ajustar(inventarioId, cantidad);
  }

  @override
  Future<ExistenciaSucursal> asignarASucursal(
    int productoId,
    SucursalProducto sucursal,
    int? existencia,
  ) {
    _validarId(productoId);
    _validarId(sucursal.id);
    if (existencia != null && (existencia < 0 || existencia > 1000000)) {
      throw const ProductoFailure('Indica una existencia de 0 a 1,000,000.');
    }
    return _existencias.asignar(productoId, sucursal, existencia);
  }

  @override
  Future<void> quitarDeSucursal(int inventarioId) {
    _validarId(inventarioId);
    return _existencias.quitar(inventarioId);
  }

  @override
  Future<void> eliminar(int id) {
    _validarId(id);
    return _gateway.eliminar(id);
  }
}
