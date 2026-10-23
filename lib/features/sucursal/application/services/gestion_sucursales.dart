import '../../domain/sucursal.dart';
import '../ports/inbound/gestion_sucursales_use_case.dart';
import '../ports/outbound/sucursal_gateway.dart';

class GestionSucursales implements GestionSucursalesUseCase {
  const GestionSucursales(this._gateway);
  final SucursalGateway _gateway;
  void _validarId(int id) {
    if (id <= 0) {
      throw const SucursalFailure('Selecciona un negocio o sucursal válido.');
    }
  }

  void _validar(DatosSucursal datos, {required bool registro}) {
    final errores = datos.validar(registro: registro);
    if (errores.isNotEmpty) {
      throw SucursalFailure(
        'Revisa los campos señalados.',
        fieldErrors: errores,
      );
    }
  }

  @override
  Future<List<NegocioSucursal>> negocios() => _gateway.negocios();
  @override
  Future<List<Sucursal>> listar(int negocioId) {
    _validarId(negocioId);
    return _gateway.listar(negocioId);
  }

  @override
  Future<Sucursal> crear(int negocioId, DatosSucursal datos) {
    _validarId(negocioId);
    _validar(datos, registro: true);
    return _gateway.crear(negocioId, datos);
  }

  @override
  Future<Sucursal> editar(int id, DatosSucursal datos) {
    _validarId(id);
    _validar(datos, registro: false);
    return _gateway.editar(id, datos);
  }

  @override
  Future<void> eliminar(int id) {
    _validarId(id);
    return _gateway.eliminar(id);
  }
}
