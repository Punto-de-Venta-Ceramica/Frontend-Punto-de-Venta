import '../../../domain/corte_caja.dart';

abstract class GestionCorteCajaUseCase {
  Future<CorteCaja> abrirCorte({
    required int sucursalId,
    required double montoInicial,
  });

  Future<CorteCaja?> obtenerCorteActivo(int sucursalId);

  Future<CorteCaja> cerrarCorte({
    required int corteId,
    required double totalReal,
  });

  Future<CorteCaja> consultarCorte(int corteId);

  Future<List<ResumenCorteCaja>> listarHistorial(
    int sucursalId, {
    int page = 0,
    int size = 20,
  });
}
