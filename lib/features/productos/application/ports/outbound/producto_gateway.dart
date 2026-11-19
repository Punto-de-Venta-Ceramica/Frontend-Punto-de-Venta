import '../../../domain/producto.dart';

/// Catálogo de productos (`/api/productos` y su clasificación).
abstract interface class ProductoGateway {
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

  /// Producto con clasificación y descuento, sin existencias (son de inventario).
  Future<Producto> consultar(int id);
  Future<Producto> crear(DatosProducto datos);
  Future<Producto> editar(int id, DatosProducto datos);
  Future<void> eliminar(int id);
}
