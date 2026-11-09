import '../../../domain/descuento.dart';

abstract interface class GestionDescuentosUseCase {
  /// Todos los descuentos del negocio, activos e inactivos.
  Future<List<Descuento>> listar(int negocioId);
  Future<Descuento> crear(int negocioId, DatosDescuento datos);
  Future<Descuento> editar(int negocioId, int id, DatosDescuento datos);
  Future<void> eliminar(int negocioId, int id);
  Future<Descuento> cambiarEstado(int negocioId, int id, {required bool activo});

  /// Productos, categorías y áreas del negocio que pueden recibir un descuento.
  Future<CatalogoDescuento> catalogo(int negocioId);

  /// Descuentos asignados directamente al producto.
  Future<DescuentosDeProducto> delProducto(int negocioId, int productoId);

  /// Deja los descuentos propios del producto como indican [lineas]: crea y
  /// asigna los nuevos, actualiza los modificados (datos y estado) y elimina los
  /// ids de [eliminar]. Es progresivo: actualiza [lineas] y quita de [eliminar]
  /// lo que ya hizo, así un reintento tras un fallo parcial continúa donde quedó.
  Future<void> guardarDeProducto(
    int negocioId,
    int productoId,
    String nombreProducto,
    List<LineaDescuento> lineas,
    Set<int> eliminar,
  );

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
