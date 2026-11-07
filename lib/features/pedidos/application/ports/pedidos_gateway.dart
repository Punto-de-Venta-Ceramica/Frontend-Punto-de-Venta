import '../../domain/pedido.dart';

abstract interface class PedidosGateway {
  Future<List<Pedido>> listar(int sucursalId);
  Future<List<ProductoPedido>> productos(int sucursalId);
  Future<void> registrar(DatosPedido datos);
  Future<void> pagar(int pedidoId, double monto, String metodo);
  Future<void> cambiarEstado(int pedidoId, String estado);
  Future<void> cancelar(int pedidoId);
  Future<List<AvisoPedido>> notificaciones();
  Future<void> marcarLeida(int id);
}
