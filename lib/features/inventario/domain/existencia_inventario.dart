class ExistenciaInventario {
  const ExistenciaInventario({
    required this.inventarioId,
    required this.productoNombre,
    required this.existencia,
  });

  final int inventarioId;
  final String productoNombre;
  final int existencia;

  ExistenciaInventario conExistencia(int nueva) => ExistenciaInventario(
    inventarioId: inventarioId,
    productoNombre: productoNombre,
    existencia: nueva,
  );
}

class InventarioFailure implements Exception {
  const InventarioFailure(this.message, {this.sesionExpirada = false});
  final String message;
  final bool sesionExpirada;

  @override
  String toString() => message;
}
