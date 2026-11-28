import 'package:punto_de_venta/core/infrastructure/cache/cache_en_memoria.dart';

import '../../../../application/ports/outbound/existencias_gateway.dart';
import '../../../../application/ports/outbound/producto_gateway.dart';
import '../../../../application/ports/outbound/productos_en_cache.dart';
import '../../../../domain/producto.dart';

/// Caché en memoria de productos y existencias.
///
/// Envuelve los dos gateways HTTP con decoradores ([productos] y [existencias])
/// que la aplicación usa como si fueran los originales. Los errores nunca se
/// guardan.
class CacheProductos implements ProductosEnCache {
  CacheProductos(
    ProductoGateway productos,
    ExistenciasGateway existencias, {
    Duration vigenciaCatalogos = const Duration(minutes: 30),
    Duration vigenciaListado = const Duration(minutes: 5),
    DateTime Function()? ahora,
  }) : productos = CachedProductoGateway(
         productos,
         vigenciaCatalogos: vigenciaCatalogos,
         vigenciaListado: vigenciaListado,
         ahora: ahora,
       ) {
    this.existencias = CachedExistenciasGateway(
      existencias,
      // Asignar a una sucursal cambia los listados filtrados por sucursal.
      alAsignar: this.productos.descartarListados,
    );
  }

  final CachedProductoGateway productos;
  late final CachedExistenciasGateway existencias;

  @override
  Producto? detalleGuardado(int id) {
    final producto = productos.guardado(id);
    final existenciasGuardadas = existencias.guardadas(id);
    if (producto == null || existenciasGuardadas == null) return null;
    return producto.conExistencias(existenciasGuardadas);
  }

  @override
  void descartar() {
    productos.descartar();
    existencias.descartar();
  }

  /// Tras una venta o un cambio de descuentos: áreas y categorías siguen igual.
  void descartarSalvoCatalogos() {
    productos.descartarSalvoCatalogos();
    existencias.descartar();
  }
}

/// Tope de entradas por mapa: cada búsqueda o producto abierto crea una y sin
/// límite la memoria crecería durante toda la sesión.
const _maximoEntradas = 200;

/// Guarda [valor] como lo más reciente y, si se supera el tope, descarta lo
/// más antiguo (los mapas conservan el orden de inserción).
V _recordar<K, V>(Map<K, V> mapa, K clave, V valor) {
  mapa.remove(clave);
  mapa[clave] = valor;
  if (mapa.length > _maximoEntradas) mapa.remove(mapa.keys.first);
  return valor;
}

/// - Áreas y categorías: casi no cambian ([vigenciaCatalogos]).
/// - Negocios y sucursales: pasan directo al gateway de origen, que usa la
///   caché compartida entre módulos (así, editar un negocio en su módulo se
///   ve también aquí).
/// - Páginas del listado: [vigenciaListado]; cualquier alta, edición o baja las
///   descarta todas (el orden por nombre puede mover productos de página).
/// - Detalle: [consultar] siempre va al servidor; lo guardado solo sirve para
///   mostrarlo al instante mientras llega la versión fresca.
class CachedProductoGateway implements ProductoGateway {
  CachedProductoGateway(
    this._origen, {
    Duration vigenciaCatalogos = const Duration(minutes: 30),
    Duration vigenciaListado = const Duration(minutes: 5),
    DateTime Function()? ahora,
  }) : _areas = CacheEnMemoria(vigencia: vigenciaCatalogos, ahora: ahora),
       _categorias = CacheEnMemoria(vigencia: vigenciaCatalogos, ahora: ahora),
       _paginas = CacheEnMemoria(vigencia: vigenciaListado, ahora: ahora);

  final ProductoGateway _origen;

  final CacheEnMemoria<int, List<AreaProducto>> _areas;
  final CacheEnMemoria<int, List<CategoriaProducto>> _categorias;
  final CacheEnMemoria<String, PaginaProductos> _paginas;
  final _detalles = <int, Producto>{};

  static String _clavePagina(int negocioId, int pagina, FiltroProductos f) =>
      '$negocioId|${f.areaId}|${f.categoriaId}|${f.sucursalId}|'
      '${f.precioMinimo}|${f.precioMaximo}|'
      '${f.buscar.trim().toLowerCase()}|$pagina';

  Producto _guardar(Producto producto) =>
      _recordar(_detalles, producto.id, producto);

  Producto? guardado(int id) => _detalles[id];

  void descartarListados() => _paginas.limpiar();

  void descartarSalvoCatalogos() {
    _paginas.limpiar();
    _detalles.clear();
  }

  void descartar() {
    _areas.limpiar();
    _categorias.limpiar();
    _paginas.limpiar();
    _detalles.clear();
  }

  @override
  Future<List<NegocioProducto>> negocios() => _origen.negocios();

  @override
  Future<List<AreaProducto>> areas(int negocioId) =>
      _areas.obtener(negocioId, () => _origen.areas(negocioId));

  @override
  Future<List<CategoriaProducto>> categorias(int negocioId) =>
      _categorias.obtener(negocioId, () => _origen.categorias(negocioId));

  @override
  Future<List<SucursalProducto>> sucursales(int negocioId) =>
      _origen.sucursales(negocioId);

  @override
  Future<PaginaProductos> listar(
    int negocioId, {
    int pagina = 0,
    FiltroProductos filtro = const FiltroProductos(),
  }) => _paginas.obtener(
    _clavePagina(negocioId, pagina, filtro),
    () => _origen.listar(negocioId, pagina: pagina, filtro: filtro),
  );

  @override
  Future<Producto> consultar(int id) async =>
      _guardar(await _origen.consultar(id));

  @override
  Future<Producto> crear(DatosProducto datos) async {
    final producto = await _origen.crear(datos);
    descartarListados();
    return _guardar(producto);
  }

  @override
  Future<Producto> editar(int id, DatosProducto datos) async {
    final producto = await _origen.editar(id, datos);
    descartarListados();
    return _guardar(producto);
  }

  @override
  Future<void> eliminar(int id) async {
    await _origen.eliminar(id);
    descartarListados();
    _detalles.remove(id);
  }
}

/// Las existencias cambian por ventas de otros dispositivos: [porProducto]
/// siempre va al servidor y lo guardado solo se usa para mostrar el detalle al
/// instante. Los ajustes propios corrigen lo guardado sin otra petición.
class CachedExistenciasGateway implements ExistenciasGateway {
  CachedExistenciasGateway(this._origen, {void Function()? alAsignar})
    : _alAsignar = alAsignar;

  final ExistenciasGateway _origen;
  final void Function()? _alAsignar;
  final _porProducto = <int, List<ExistenciaSucursal>>{};

  List<ExistenciaSucursal>? guardadas(int productoId) =>
      _porProducto[productoId];

  void descartar() => _porProducto.clear();

  @override
  Future<List<ExistenciaSucursal>> porProducto(int productoId) async =>
      _recordar(
        _porProducto,
        productoId,
        await _origen.porProducto(productoId),
      );

  @override
  Future<int> ajustar(int inventarioId, int cantidad) async =>
      _actualizar(inventarioId, await _origen.ajustar(inventarioId, cantidad));

  @override
  Future<int> agregar(int inventarioId, int cantidad) async =>
      _actualizar(inventarioId, await _origen.agregar(inventarioId, cantidad));

  /// Corrige la existencia guardada de esa sucursal y la devuelve.
  int _actualizar(int inventarioId, int existencia) {
    _porProducto.updateAll(
      (_, filas) => [
        for (final e in filas)
          e.inventarioId == inventarioId ? e.conExistencia(existencia) : e,
      ],
    );
    return existencia;
  }

  @override
  Future<ExistenciaSucursal> asignar(
    int productoId,
    SucursalProducto sucursal,
    int? existencia,
  ) async {
    final asignada = await _origen.asignar(productoId, sucursal, existencia);
    final filas = _porProducto[productoId];
    if (filas != null) _porProducto[productoId] = [...filas, asignada];
    _alAsignar?.call();
    return asignada;
  }

  /// Quitar también cambia qué productos lista cada sucursal.
  @override
  Future<void> quitar(int inventarioId) async {
    await _origen.quitar(inventarioId);
    _porProducto.updateAll(
      (_, filas) => [
        for (final e in filas)
          if (e.inventarioId != inventarioId) e,
      ],
    );
    _alAsignar?.call();
  }
}
