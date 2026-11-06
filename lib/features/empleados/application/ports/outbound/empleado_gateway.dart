import '../../../domain/empleado.dart';

abstract interface class EmpleadoGateway {
  Future<List<NegocioEmpleado>> negocios();
  Future<List<SucursalEmpleado>> sucursales(int negocioId);
  Future<List<Empleado>> listar(int negocioId, {bool incluirAsignacion = true});
  Future<EmpleadoCreado> registrar(NuevoEmpleado datos);
  Future<Empleado> asignarSucursal({
    required int negocioId,
    required int empleadoId,
    required int? sucursalId,
  });
  Future<void> eliminar(int negocioId, int empleadoId);
}
