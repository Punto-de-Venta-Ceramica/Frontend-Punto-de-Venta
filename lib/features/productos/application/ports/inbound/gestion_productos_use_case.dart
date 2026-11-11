import '../../../domain/producto.dart';

abstract interface class GestionProductosUseCase {
  Future<List<NegocioProducto>> negocios();
  Future<List<AreaProducto>> areas(int negocioId);
  Future<List<CategoriaProducto>> categorias(int negocioId);
  Future<List<SucursalProducto>> sucursales(int negocioId);

  /// Listado paginado (20 por página) con lo mínimo para las tarjetas.
  Future<PaginaProductos> listar(
    int negocioId, {
    int pagina = 0,
    FiltroProductos filtro = const FiltroProductos(),
  });
  Future<Producto> consultar(int id, int negocioId);

  /// Último detalle conocido para mostrarlo al instante mientras [consultar]
  /// trae la versión fresca; null si no hay nada guardado.
  Producto? detalleGuardado(int id);

  /// Olvida lo guardado localmente (p. ej. al deslizar para actualizar).
  void descartarCache();
  Future<Producto> crear(int negocioId, DatosProducto datos);
  Future<Producto> editar(int id, int negocioId, DatosProducto datos);
  Future<void> eliminar(int id);

  /// Suma (cantidad positiva) o resta (negativa) piezas en una sucursal.
  /// Devuelve la existencia resultante.
  Future<int> ajustarExistencia(int inventarioId, int cantidad);

  /// Asigna un producto ya registrado a otra sucursal con su existencia inicial.
  Future<ExistenciaSucursal> asignarASucursal(
    int productoId,
    SucursalProducto sucursal,
    int existencia,
  );
}
