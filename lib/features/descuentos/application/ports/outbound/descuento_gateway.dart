import '../../../domain/descuento.dart';

abstract interface class DescuentoGateway {
  /// Todos los descuentos del negocio, activos e inactivos.
  Future<List<Descuento>> listar(int negocioId);

  /// Descuentos, activos e inactivos, asignados directamente al producto.
  Future<List<Descuento>> deProducto(int negocioId, int productoId);

  /// Deja los descuentos propios del producto como indican [lineas] y elimina
  /// los ids de [eliminar] en una sola operación: se aplica todo o nada.
  /// Devuelve el descuento guardado de cada línea, en el mismo orden.
  Future<List<Descuento>> guardarDeProducto(
    int negocioId,
    int productoId, {
    required List<DescuentoAGuardar> lineas,
    required Set<int> eliminar,
  });
  Future<Descuento> crear(int negocioId, DatosDescuento datos);
  Future<Descuento> editar(int negocioId, int id, DatosDescuento datos);
  Future<void> eliminar(int negocioId, int id);
  Future<Descuento> cambiarEstado(
    int negocioId,
    int id, {
    required bool activo,
  });

  /// Productos, categorías y áreas del negocio que pueden recibir un descuento.
  Future<CatalogoDescuento> catalogo(int negocioId);

  /// Idempotentes. Devuelven el descuento con sus asignaciones actualizadas.
  Future<Descuento> asignar(
    int negocioId,
    int id,
    DestinoDescuento destino,
    int destinoId,
  );
  Future<Descuento> quitar(
    int negocioId,
    int id,
    DestinoDescuento destino,
    int destinoId,
  );
}
