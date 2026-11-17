import '../../../../application/ports/outbound/corte_caja_gateway.dart';
import '../../../../domain/corte_caja.dart';

/// Guarda el detalle de los cortes **cerrados** durante toda la sesión: un
/// corte cerrado ya no cambia, así que volver a abrirlo desde el historial no
/// vuelve a pedirlo. Decora el gateway HTTP y la aplicación lo usa como si
/// fuera el original.
///
/// Todo lo demás (corte activo, abrir, cerrar, historial) va siempre al
/// servidor: es dinero en vivo.
class CachedCorteCajaGateway implements CorteCajaGateway {
  CachedCorteCajaGateway(this._origen);

  final CorteCajaGateway _origen;
  final _cerrados = <int, CorteCaja>{};

  /// Tope de cortes guardados; al pasarse se descarta el más antiguo.
  static const _maximoEntradas = 200;

  CorteCaja _recordarSiCerrado(CorteCaja corte) {
    if (corte.cerrado) {
      _cerrados.remove(corte.id);
      _cerrados[corte.id] = corte;
      if (_cerrados.length > _maximoEntradas) {
        _cerrados.remove(_cerrados.keys.first);
      }
    }
    return corte;
  }

  /// Al cerrar sesión: lo guardado pertenece al usuario anterior.
  void descartar() => _cerrados.clear();

  @override
  Future<CorteCaja> consultarCorte(int corteId) async =>
      _cerrados[corteId] ??
      _recordarSiCerrado(await _origen.consultarCorte(corteId));

  @override
  Future<CorteCaja> cerrarCorte({
    required int corteId,
    required double totalReal,
  }) async => _recordarSiCerrado(
    await _origen.cerrarCorte(corteId: corteId, totalReal: totalReal),
  );

  @override
  Future<CorteCaja> abrirCorte({
    required int sucursalId,
    required double montoInicial,
  }) => _origen.abrirCorte(sucursalId: sucursalId, montoInicial: montoInicial);

  @override
  Future<CorteCaja?> obtenerCorteActivo(int sucursalId) =>
      _origen.obtenerCorteActivo(sucursalId);

  @override
  Future<List<ResumenCorteCaja>> listarHistorial(
    int sucursalId, {
    int page = 0,
    int size = 20,
  }) => _origen.listarHistorial(sucursalId, page: page, size: size);
}
