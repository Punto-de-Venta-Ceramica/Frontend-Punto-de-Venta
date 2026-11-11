import '../../../domain/producto.dart';

/// Existencias de los productos por sucursal (módulo de inventario del backend).
abstract interface class ExistenciasGateway {
  /// Existencia del producto en cada sucursal donde está asignado.
  Future<List<ExistenciaSucursal>> porProducto(int productoId);

  /// Suma (cantidad positiva) o resta (negativa) piezas en una sucursal.
  /// Devuelve la existencia resultante.
  Future<int> ajustar(int inventarioId, int cantidad);

  /// Asigna un producto ya registrado a otra sucursal con su existencia inicial.
  Future<ExistenciaSucursal> asignar(
    int productoId,
    SucursalProducto sucursal,
    int existencia,
  );
}
