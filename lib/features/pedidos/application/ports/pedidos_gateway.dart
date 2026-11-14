import '../../domain/pedido.dart';

abstract interface class PedidosGateway {
  /// Listado paginado (20 por página), sin folio. [estado] null = todos.
  Future<PaginaPedidos> listar(
    int sucursalId, {
    String? estado,
    int pagina = 0,
  });

  /// Detalle completo del pedido, incluido el folio.
  Future<Pedido> obtener(int pedidoId);
  Future<List<ProductoPedido>> productos(int sucursalId);

  /// Si la sucursal tiene un turno de caja abierto: sin él no se cobran pagos.
  Future<bool> cajaAbierta(int sucursalId);
  Future<void> registrar(DatosPedido datos);
  Future<void> pagar(int pedidoId, double monto, String metodo);
  Future<void> cambiarEstado(int pedidoId, String estado);
  Future<void> cancelar(int pedidoId);
  Future<List<AvisoPedido>> notificaciones();
  Future<void> marcarLeida(int id);
}
