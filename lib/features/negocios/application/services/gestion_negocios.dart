import '../ports/inbound/gestion_negocios_use_case.dart';
import '../ports/outbound/negocio_gateway.dart';
import '../../domain/negocio.dart';

class GestionNegocios implements GestionNegociosUseCase {
  const GestionNegocios(this._gateway);
  final NegocioGateway _gateway;

  void _validarId(int id) {
    if (id <= 0) throw const NegocioFailure('Selecciona un negocio válido.');
  }

  void _validar(DatosNegocio datos) {
    final errores = datos.validar();
    if (errores.isNotEmpty) {
      throw NegocioFailure(
        'Revisa los datos del formulario.',
        fieldErrors: errores,
      );
    }
  }

  @override
  Future<List<Negocio>> listar() => _gateway.listar();
  @override
  Future<Negocio> consultar(int id) {
    _validarId(id);
    return _gateway.consultar(id);
  }

  @override
  Future<Negocio> crear(DatosNegocio datos) {
    _validar(datos);
    return _gateway.crear(datos);
  }

  @override
  Future<Negocio> editar(int id, DatosNegocio datos) {
    _validarId(id);
    _validar(datos);
    return _gateway.editar(id, datos);
  }

  @override
  Future<void> eliminar(int id) {
    _validarId(id);
    return _gateway.eliminar(id);
  }
}
