import 'package:punto_de_venta/core/infrastructure/cache/cache_en_memoria.dart';
import '../../../../application/ports/outbound/catalogo_gateway.dart';
import '../../../../domain/catalogo.dart';

/// Caché en memoria de áreas y categorías. Decora el gateway HTTP y la
/// aplicación lo usa como si fuera el original.
///
/// Vigencia: [vigencia] (30 min): solo el propietario las cambia y casi nunca.
/// Ayuda sobre todo en la lista de áreas, que pide las categorías de cada
/// área para contarlas (una petición por área).
///
/// Crear, editar o eliminar desde esta app descarta lo afectado al momento.
class CachedCatalogoGateway implements CatalogoGateway {
  CachedCatalogoGateway(
    this._origen, {
    Duration vigencia = const Duration(minutes: 30),
    DateTime Function()? ahora,
  }) : _areas = CacheEnMemoria(vigencia: vigencia, ahora: ahora),
       _area = CacheEnMemoria(vigencia: vigencia, ahora: ahora),
       _categorias = CacheEnMemoria(vigencia: vigencia, ahora: ahora);

  final CatalogoGateway _origen;

  /// Clave: negocio.
  final CacheEnMemoria<int, List<AreaCatalogo>> _areas;

  /// Clave: (negocio, área).
  final CacheEnMemoria<(int, int), AreaCatalogo> _area;

  /// Clave: (negocio, área).
  final CacheEnMemoria<(int, int), List<CategoriaCatalogo>> _categorias;

  void descartar() {
    _areas.limpiar();
    _area.limpiar();
    _categorias.limpiar();
  }

  void _cambioArea(int negocioId, int areaId) {
    _areas.descartar(negocioId);
    _area.descartar((negocioId, areaId));
  }

  @override
  Future<List<AreaCatalogo>> listarAreas(int negocioId) =>
      _areas.obtener(negocioId, () => _origen.listarAreas(negocioId));

  @override
  Future<AreaCatalogo> consultarArea(int negocioId, int areaId) =>
      _area.obtener((
        negocioId,
        areaId,
      ), () => _origen.consultarArea(negocioId, areaId));

  @override
  Future<AreaCatalogo> crearArea(
    int negocioId,
    DatosClasificacion datos,
  ) async {
    final area = await _origen.crearArea(negocioId, datos);
    _areas.descartar(negocioId);
    return area;
  }

  @override
  Future<AreaCatalogo> editarArea(
    int negocioId,
    int areaId,
    DatosClasificacion datos,
  ) async {
    final area = await _origen.editarArea(negocioId, areaId, datos);
    _cambioArea(negocioId, areaId);
    return area;
  }

  @override
  Future<void> eliminarArea(int negocioId, int areaId) async {
    await _origen.eliminarArea(negocioId, areaId);
    _cambioArea(negocioId, areaId);
    _categorias.descartar((negocioId, areaId));
  }

  @override
  Future<List<CategoriaCatalogo>> listarCategorias(int negocioId, int areaId) =>
      _categorias.obtener((
        negocioId,
        areaId,
      ), () => _origen.listarCategorias(negocioId, areaId));

  @override
  Future<CategoriaCatalogo> crearCategoria(
    int negocioId,
    int areaId,
    DatosClasificacion datos,
  ) async {
    final categoria = await _origen.crearCategoria(negocioId, areaId, datos);
    _categorias.descartar((negocioId, areaId));
    return categoria;
  }

  @override
  Future<CategoriaCatalogo> editarCategoria(
    int negocioId,
    int areaId,
    int categoriaId,
    DatosClasificacion datos,
  ) async {
    final categoria = await _origen.editarCategoria(
      negocioId,
      areaId,
      categoriaId,
      datos,
    );
    _categorias.descartar((negocioId, areaId));
    return categoria;
  }

  @override
  Future<void> eliminarCategoria(
    int negocioId,
    int areaId,
    int categoriaId,
  ) async {
    await _origen.eliminarCategoria(negocioId, areaId, categoriaId);
    _categorias.descartar((negocioId, areaId));
  }
}
