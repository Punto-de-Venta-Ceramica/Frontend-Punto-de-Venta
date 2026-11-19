import '../../../domain/catalogo.dart';

abstract interface class GestionCatalogoUseCase {
  Future<List<ResumenAreaCatalogo>> listarAreas(int negocioId);
  Future<AreaCatalogo> consultarArea(int negocioId, int areaId);
  Future<AreaCatalogo> crearArea(int negocioId, DatosClasificacion datos);
  Future<AreaCatalogo> editarArea(
    int negocioId,
    int areaId,
    DatosClasificacion datos,
  );
  Future<void> eliminarArea(int negocioId, int areaId);
  Future<List<CategoriaCatalogo>> listarCategorias(int negocioId, int areaId);
  Future<CategoriaCatalogo> crearCategoria(
    int negocioId,
    int areaId,
    DatosClasificacion datos,
  );
  Future<CategoriaCatalogo> editarCategoria(
    int negocioId,
    int areaId,
    int categoriaId,
    DatosClasificacion datos,
  );
  Future<void> eliminarCategoria(int negocioId, int areaId, int categoriaId);
}
