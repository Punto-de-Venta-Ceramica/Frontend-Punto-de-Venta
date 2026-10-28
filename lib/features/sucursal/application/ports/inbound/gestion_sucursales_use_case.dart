import '../../../domain/sucursal.dart';

abstract interface class GestionSucursalesUseCase {
  Future<List<NegocioSucursal>> negocios();
  Future<List<Sucursal>> listar(int negocioId);
  Future<Sucursal> crear(int negocioId, DatosSucursal datos);
  Future<Sucursal> editar(int id, DatosSucursal datos);
  Future<void> eliminar(int id);
}
