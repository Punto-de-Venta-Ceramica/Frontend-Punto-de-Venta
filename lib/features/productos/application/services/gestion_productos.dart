import '../../domain/producto.dart';
import '../ports/inbound/gestion_productos_use_case.dart';
import '../ports/outbound/producto_gateway.dart';

class GestionProductos implements GestionProductosUseCase {
  const GestionProductos(this._gateway);
  final ProductoGateway _gateway;

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
  Future<List<Producto>> listar(int negocioId) {
    _validarId(negocioId);
    return _gateway.listar(negocioId);
  }

  @override
  Future<Producto> consultar(int id, int negocioId) {
    _validarId(id);
    _validarId(negocioId);
    return _gateway.consultar(id, negocioId);
  }

  @override
  Future<Producto> crear(int negocioId, DatosProducto datos) {
    _validarId(negocioId);
    _validar(datos);
    return _gateway.crear(negocioId, datos);
  }

  @override
  Future<Producto> editar(int id, int negocioId, DatosProducto datos) {
    _validarId(id);
    _validarId(negocioId);
    _validar(datos);
    return _gateway.editar(id, negocioId, datos);
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
    return _gateway.ajustarExistencia(inventarioId, cantidad);
  }

  @override
  Future<ExistenciaSucursal> asignarASucursal(
    int productoId,
    SucursalProducto sucursal,
    int existencia,
  ) {
    _validarId(productoId);
    _validarId(sucursal.id);
    if (existencia < 0 || existencia > 1000000) {
      throw const ProductoFailure('Indica una existencia de 0 a 1,000,000.');
    }
    return _gateway.asignarASucursal(productoId, sucursal, existencia);
  }

  @override
  Future<void> eliminar(int id) {
    _validarId(id);
    return _gateway.eliminar(id);
  }
}
