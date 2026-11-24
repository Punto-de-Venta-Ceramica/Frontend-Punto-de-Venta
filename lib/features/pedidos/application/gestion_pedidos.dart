import '../domain/pedido.dart';
import 'ports/pedidos_gateway.dart';

class GestionPedidos {
  const GestionPedidos(this._gateway, {PedidosEnMemoria? memoria})
    : _memoria = memoria;
  final PedidosGateway _gateway;
  final PedidosEnMemoria? _memoria;

  Future<PaginaPedidos> listar(
    int sucursal, {
    String? estado,
    int pagina = 0,
  }) => _gateway.listar(sucursal, estado: estado, pagina: pagina);
  Future<Pedido> obtener(int id) => _gateway.obtener(id);

  /// Primera página guardada de ese filtro, para mostrarla mientras se
  /// consulta la fresca con [listar].
  PaginaPedidos? listadoGuardado(int sucursal, {String? estado}) =>
      _memoria?.listadoGuardado(sucursal, estado);

  /// Último detalle guardado, para mostrarlo mientras se consulta el fresco
  /// con [obtener].
  Pedido? pedidoGuardado(int id) => _memoria?.pedidoGuardado(id);

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

  Future<int> registrar(DatosPedido datos) => _gateway.registrar(datos);
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
