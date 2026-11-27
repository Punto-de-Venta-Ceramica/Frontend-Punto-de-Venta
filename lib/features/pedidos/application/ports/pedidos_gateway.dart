import '../../domain/pedido.dart';

abstract interface class PedidosGateway {
  /// Listado paginado (20 por página), sin folio. [estado] null = todos.
  /// [busqueda] (null = sin buscar) coincide por nombre o teléfono del
  /// cliente (parcial) o por folio (exacto); se combina con [estado].
  Future<PaginaPedidos> listar(
    int sucursalId, {
    String? estado,
    String? busqueda,
    int pagina = 0,
  });

  /// Detalle completo del pedido, incluido el folio.
  Future<Pedido> obtener(int pedidoId);
  Future<List<ProductoPedido>> productos(int sucursalId);

  /// Si la sucursal tiene un turno de caja abierto: sin él no se cobran pagos.
  Future<bool> cajaAbierta(int sucursalId);

  /// Devuelve el id del pedido registrado.
  Future<int> registrar(DatosPedido datos);
  Future<void> pagar(int pedidoId, double monto, String metodo);
  Future<void> cambiarEstado(int pedidoId, String estado);
  Future<void> cancelar(int pedidoId);

  /// Descripción, entrega y datos del cliente. Solo el propietario.
  Future<void> editarDatos(int pedidoId, DatosEdicionPedido datos);
  Future<PaginaAvisos> notificaciones({int pagina = 0});
  Future<void> marcarLeida(int id);
}

/// Lo último que se recibió del servidor, para mostrarlo al instante mientras
/// llega la versión fresca. Nunca sustituye a la consulta: los pedidos los
/// cambian varias personas a la vez (pagos, estados, cancelaciones).
abstract interface class PedidosEnMemoria {
  /// Primera página del listado de la sucursal con ese filtro de [estado].
  PaginaPedidos? listadoGuardado(int sucursalId, String? estado);

  /// Último detalle recibido del pedido.
  Pedido? pedidoGuardado(int pedidoId);
}
