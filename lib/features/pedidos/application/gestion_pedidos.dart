import '../domain/pedido.dart';
import 'ports/pedidos_gateway.dart';

class GestionPedidos {
  const GestionPedidos(this._gateway);
  final PedidosGateway _gateway;
  Future<List<Pedido>> listar(int sucursal) => _gateway.listar(sucursal);
  Future<List<ProductoPedido>> productos(int sucursal) =>
      _gateway.productos(sucursal);
  Future<void> registrar(DatosPedido datos) => _gateway.registrar(datos);
  Future<void> pagar(int id, double monto, String metodo) =>
      _gateway.pagar(id, monto, metodo);
  Future<void> cambiarEstado(int id, String estado) =>
      _gateway.cambiarEstado(id, estado);
  Future<void> cancelar(int id) => _gateway.cancelar(id);
  Future<List<AvisoPedido>> notificaciones() => _gateway.notificaciones();
  Future<void> marcarLeida(int id) => _gateway.marcarLeida(id);
}
