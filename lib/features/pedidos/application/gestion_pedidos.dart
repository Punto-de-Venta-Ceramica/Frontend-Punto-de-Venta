import '../domain/pedido.dart';
import 'ports/pedidos_gateway.dart';

class GestionPedidos {
  const GestionPedidos(this._gateway);
  final PedidosGateway _gateway;
  Future<PaginaPedidos> listar(
    int sucursal, {
    String? estado,
    int pagina = 0,
  }) => _gateway.listar(sucursal, estado: estado, pagina: pagina);
  Future<Pedido> obtener(int id) => _gateway.obtener(id);
  Future<List<ProductoPedido>> productos(int sucursal) =>
      _gateway.productos(sucursal);

  /// Si no se puede consultar, se asume abierta: el servidor valida el corte
  /// de todos modos al cobrar y responde con el aviso de caja cerrada.
  Future<bool> cajaAbierta(int sucursal) async {
    try {
      return await _gateway.cajaAbierta(sucursal);
    } catch (_) {
      return true;
    }
  }

  Future<void> registrar(DatosPedido datos) => _gateway.registrar(datos);
  Future<void> pagar(int id, double monto, String metodo) =>
      _gateway.pagar(id, monto, metodo);
  Future<void> cambiarEstado(int id, String estado) =>
      _gateway.cambiarEstado(id, estado);
  Future<void> cancelar(int id) => _gateway.cancelar(id);
  Future<void> editarDatos(int id, DatosEdicionPedido datos) =>
      _gateway.editarDatos(id, datos);
  Future<List<AvisoPedido>> notificaciones() => _gateway.notificaciones();
  Future<void> marcarLeida(int id) => _gateway.marcarLeida(id);
}
