import '../../../domain/empleado.dart';

abstract interface class EmpleadoGateway {
  Future<List<NegocioEmpleado>> negocios();
  Future<List<SucursalEmpleado>> sucursales(int negocioId);
  Future<List<Empleado>> listar(
    int negocioId, {
    bool incluirAsignacion = true,
    int? sucursalId,
  });
  Future<EmpleadoCreado> registrar(NuevoEmpleado datos);

  /// Reemplaza el conjunto de sucursales del empleado (asignar y desasignar).
  Future<Empleado> asignarSucursales({
    required int negocioId,
    required int empleadoId,
    required List<int> sucursalIds,
  });
  Future<void> eliminar(int negocioId, int empleadoId);
}
