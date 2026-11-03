import '../../../domain/producto.dart';

abstract interface class ProductoGateway {
  Future<List<NegocioProducto>> negocios();
  Future<List<AreaProducto>> areas(int negocioId);
  Future<List<CategoriaProducto>> categorias(int negocioId);
  Future<List<SucursalProducto>> sucursales(int negocioId);
  Future<List<Producto>> listar(int negocioId);
  Future<Producto> consultar(int id, int negocioId);
  Future<Producto> crear(int negocioId, DatosProducto datos);
  Future<Producto> editar(int id, int negocioId, DatosProducto datos);
  Future<void> eliminar(int id);
}
