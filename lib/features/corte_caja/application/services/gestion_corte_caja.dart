import '../ports/inbound/gestion_corte_caja_use_case.dart';
import '../ports/outbound/corte_caja_gateway.dart';
import '../../domain/corte_caja.dart';

class GestionCorteCaja implements GestionCorteCajaUseCase {
  const GestionCorteCaja(this._gateway);

  final CorteCajaGateway _gateway;

  @override
  Future<CorteCaja> abrirCorte({
    required int sucursalId,
    required double montoInicial,
  }) {
    if (montoInicial < 0) {
      throw const CorteCajaFailure('El fondo inicial no puede ser negativo.');
    }
    return _gateway.abrirCorte(
      sucursalId: sucursalId,
      montoInicial: montoInicial,
    );
  }

  @override
  Future<CorteCaja?> obtenerCorteActivo(int sucursalId) =>
      _gateway.obtenerCorteActivo(sucursalId);

  @override
  Future<CorteCaja> cerrarCorte({
    required int corteId,
    required double totalReal,
  }) {
    if (totalReal < 0) {
      throw const CorteCajaFailure('El efectivo contado no puede ser negativo.');
    }
    return _gateway.cerrarCorte(corteId: corteId, totalReal: totalReal);
  }

  @override
  Future<CorteCaja> consultarCorte(int corteId) =>
      _gateway.consultarCorte(corteId);

  @override
  Future<List<ResumenCorteCaja>> listarHistorial(
    int sucursalId, {
    int page = 0,
    int size = 20,
  }) =>
      _gateway.listarHistorial(sucursalId, page: page, size: size);
}

