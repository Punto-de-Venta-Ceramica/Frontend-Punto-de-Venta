import '../../domain/empleado.dart';
import '../ports/inbound/gestion_empleados_use_case.dart';
import '../ports/outbound/empleado_gateway.dart';

class GestionEmpleados implements GestionEmpleadosUseCase {
  const GestionEmpleados(this._gateway);

  final EmpleadoGateway _gateway;

  void _validarId(int id, String tipo) {
    if (id <= 0) {
      throw EmpleadoFailure('Selecciona un $tipo válido.');
    }
  }

  @override
  Future<List<NegocioEmpleado>> negocios() => _gateway.negocios();

  @override
  Future<List<SucursalEmpleado>> sucursales(int negocioId) {
    _validarId(negocioId, 'negocio');
    return _gateway.sucursales(negocioId);
  }

  @override
  Future<List<Empleado>> listar(
    int negocioId, {
    bool incluirAsignacion = true,
  }) {
    _validarId(negocioId, 'negocio');
    return _gateway.listar(negocioId, incluirAsignacion: incluirAsignacion);
  }

  @override
  Future<EmpleadoCreado> registrar(NuevoEmpleado datos) {
    _validarId(datos.negocioId, 'negocio');
    final errores = datos.validar();
    if (errores.isNotEmpty) {
      throw EmpleadoFailure(
        'Revisa los campos señalados.',
        fieldErrors: errores,
      );
    }
    return _gateway.registrar(datos);
  }

  @override
  Future<Empleado> asignarSucursal({
    required int negocioId,
    required int empleadoId,
    required int? sucursalId,
  }) {
    _validarId(negocioId, 'negocio');
    _validarId(empleadoId, 'empleado');
    if (sucursalId != null && sucursalId <= 0) {
      throw const EmpleadoFailure('La sucursal seleccionada no es válida.');
    }
    return _gateway.asignarSucursal(
      negocioId: negocioId,
      empleadoId: empleadoId,
      sucursalId: sucursalId,
    );
  }

  @override
  Future<void> eliminar(int negocioId, int empleadoId) {
    _validarId(negocioId, 'negocio');
    _validarId(empleadoId, 'empleado');
    return _gateway.eliminar(negocioId, empleadoId);
  }
}
