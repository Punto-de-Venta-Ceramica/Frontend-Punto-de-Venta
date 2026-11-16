import '../../../domain/producto.dart';

/// Existencias de los productos por sucursal (módulo de inventario del backend).
abstract interface class ExistenciasGateway {
  /// Existencia del producto en cada sucursal donde está asignado.
  Future<List<ExistenciaSucursal>> porProducto(int productoId);

  /// Suma (cantidad positiva) o resta (negativa) piezas en una sucursal.
  /// Devuelve la existencia resultante.
  Future<int> ajustar(int inventarioId, int cantidad);

  /// Entrada de piezas (solo suma); es lo que puede hacer el empleado.
  /// Devuelve la existencia resultante.
  Future<int> agregar(int inventarioId, int cantidad);

  /// Asigna un producto ya registrado a otra sucursal. Sin [existencia]
  /// (null) empieza en 0, también si se había quitado antes de ahí.
  Future<ExistenciaSucursal> asignar(
    int productoId,
    SucursalProducto sucursal,
    int? existencia,
  );

  /// Quita el producto de una sucursal; su existencia queda en 0.
  Future<void> quitar(int inventarioId);
}
