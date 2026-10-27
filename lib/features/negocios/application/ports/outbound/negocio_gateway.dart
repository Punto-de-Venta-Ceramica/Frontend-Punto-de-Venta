import '../../../domain/negocio.dart';

abstract interface class NegocioGateway {
  Future<List<Negocio>> listar();
  Future<Negocio> consultar(int id);
  Future<Negocio> crear(DatosNegocio datos);
  Future<Negocio> editar(int id, DatosNegocio datos);
  Future<void> eliminar(int id);
}
