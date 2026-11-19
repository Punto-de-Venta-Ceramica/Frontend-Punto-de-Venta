import '../../domain/catalogo.dart';
import '../ports/inbound/gestion_catalogo_use_case.dart';
import '../ports/outbound/catalogo_gateway.dart';

class GestionCatalogo implements GestionCatalogoUseCase {
  const GestionCatalogo(this._gateway);
  final CatalogoGateway _gateway;

  void _validarIds(List<int> ids) {
    if (ids.any((id) => id <= 0)) {
      throw const CatalogoFailure(
        'Selecciona un negocio, área o categoría válidos.',
      );
    }
  }

  void _validarDatos(DatosClasificacion datos) {
    final errores = datos.validar();
    if (errores.isNotEmpty) {
      throw CatalogoFailure(
        'Revisa los datos del formulario.',
        fieldErrors: errores,
      );
    }
  }

  @override
  Future<List<ResumenAreaCatalogo>> listarAreas(int negocioId) async {
    _validarIds([negocioId]);
    final areas = await _gateway.listarAreas(negocioId);
    // El contrato actual entrega las categorías por área, sin un conteo agregado.
    return Future.wait(
      areas.map((area) async {
        final categorias = await _gateway.listarCategorias(negocioId, area.id);
        return ResumenAreaCatalogo(
          area: area,
          numeroCategorias: categorias.length,
        );
      }),
    );
  }

  @override
  Future<AreaCatalogo> consultarArea(int negocioId, int areaId) {
    _validarIds([negocioId, areaId]);
    return _gateway.consultarArea(negocioId, areaId);
  }

  @override
  Future<AreaCatalogo> crearArea(int negocioId, DatosClasificacion datos) {
    _validarIds([negocioId]);
    _validarDatos(datos);
    return _gateway.crearArea(negocioId, datos);
  }

  @override
  Future<AreaCatalogo> editarArea(
    int negocioId,
    int areaId,
    DatosClasificacion datos,
  ) {
    _validarIds([negocioId, areaId]);
    _validarDatos(datos);
    return _gateway.editarArea(negocioId, areaId, datos);
  }

  @override
  Future<List<CategoriaCatalogo>> listarCategorias(int negocioId, int areaId) {
    _validarIds([negocioId, areaId]);
    return _gateway.listarCategorias(negocioId, areaId);
  }

  @override
  Future<void> eliminarArea(int negocioId, int areaId) {
    _validarIds([negocioId, areaId]);
    return _gateway.eliminarArea(negocioId, areaId);
  }

  @override
  Future<void> eliminarCategoria(int negocioId, int areaId, int categoriaId) {
    _validarIds([negocioId, areaId, categoriaId]);
    return _gateway.eliminarCategoria(negocioId, areaId, categoriaId);
  }

  @override
  Future<CategoriaCatalogo> crearCategoria(
    int negocioId,
    int areaId,
    DatosClasificacion datos,
  ) {
    _validarIds([negocioId, areaId]);
    _validarDatos(datos);
    return _gateway.crearCategoria(negocioId, areaId, datos);
  }

  @override
  Future<CategoriaCatalogo> editarCategoria(
    int negocioId,
    int areaId,
    int categoriaId,
    DatosClasificacion datos,
  ) {
    _validarIds([negocioId, areaId, categoriaId]);
    _validarDatos(datos);
    return _gateway.editarCategoria(negocioId, areaId, categoriaId, datos);
  }
}
