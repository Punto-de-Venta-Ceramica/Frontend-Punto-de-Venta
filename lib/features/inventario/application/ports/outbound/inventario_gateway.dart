import '../../../domain/existencia_inventario.dart';

abstract interface class InventarioGateway {
  /// Productos y existencias de una sucursal.
  Future<List<ExistenciaInventario>> deSucursal(int negocioId, int sucursalId);

  /// Suma (positivo) o resta (negativo) piezas; devuelve la existencia resultante.
  Future<int> ajustar(int inventarioId, int cantidad);
}
