import '../../../domain/corte_caja.dart';

abstract class CorteCajaGateway {
  /// Abre un nuevo turno de caja para la sucursal indicada.
  Future<CorteCaja> abrirCorte({
    required int sucursalId,
    required double montoInicial,
  });

  /// Obtiene el corte activo de la sucursal. Devuelve null si la caja está cerrada.
  Future<CorteCaja?> obtenerCorteActivo(int sucursalId);

  /// Cierra el corte de caja con el monto real contado en efectivo.
  Future<CorteCaja> cerrarCorte({
    required int corteId,
    required double totalReal,
  });

  /// Consulta el detalle histórico de un corte por su identificador.
  Future<CorteCaja> consultarCorte(int corteId);

  /// Obtiene la lista resumida del historial de cortes de una sucursal con paginación (20 por página por defecto).
  Future<List<ResumenCorteCaja>> listarHistorial(
    int sucursalId, {
    int page = 0,
    int size = 20,
  });
}

