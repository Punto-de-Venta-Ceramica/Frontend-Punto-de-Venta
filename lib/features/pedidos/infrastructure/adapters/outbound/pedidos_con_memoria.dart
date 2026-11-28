import '../../../application/ports/pedidos_gateway.dart';
import '../../../domain/pedido.dart';

/// Decora el gateway HTTP de pedidos: toda consulta va siempre al servidor y
/// su respuesta se recuerda para mostrarla al instante la próxima vez
/// ([PedidosEnMemoria]), mientras llega la versión fresca.
///
/// No tiene vigencia porque nunca evita una petición: solo hace que la
/// pantalla no se quede vacía mientras carga. Los cambios hechos desde esta
/// app (pagar, cambiar estado, cancelar, editar, registrar) descartan lo
/// guardado, porque ya se sabe que está atrasado.
class PedidosConMemoria implements PedidosGateway, PedidosEnMemoria {
  PedidosConMemoria(this._origen);

  final PedidosGateway _origen;

  /// Clave: (sucursal, estado). Solo la primera página de cada filtro.
  final _listados = <(int, String?), PaginaPedidos>{};
  final _detalles = <int, Pedido>{};

  /// Tope por mapa: cada pedido abierto crea una entrada.
  static const _maximoEntradas = 200;

  static V _recordar<K, V>(Map<K, V> mapa, K clave, V valor) {
    mapa.remove(clave);
    mapa[clave] = valor;
    if (mapa.length > _maximoEntradas) mapa.remove(mapa.keys.first);
    return valor;
  }

  /// Sube con cada cambio. Una consulta que empezó antes de un cambio y
  /// termina después trae datos anteriores a él: no se recuerda.
  int _version = 0;

  /// Un cambio a un pedido mueve los listados (estado, saldo, orden).
  void _cambio(int? pedidoId) {
    _version++;
    _listados.clear();
    if (pedidoId != null) _detalles.remove(pedidoId);
  }

  void descartar() {
    _version++;
    _listados.clear();
    _detalles.clear();
  }

  @override
  PaginaPedidos? listadoGuardado(int sucursalId, String? estado) =>
      _listados[(sucursalId, estado)];

  @override
  Pedido? pedidoGuardado(int pedidoId) => _detalles[pedidoId];

  @override
  Future<PaginaPedidos> listar(
    int sucursalId, {
    String? estado,
    String? busqueda,
    int pagina = 0,
  }) async {
    final version = _version;
    final resultado = await _origen.listar(
      sucursalId,
      estado: estado,
      busqueda: busqueda,
      pagina: pagina,
    );
    // Una búsqueda no es el listado del filtro: no lo sustituye.
    if (pagina == 0 && busqueda == null && version == _version) {
      _recordar(_listados, (sucursalId, estado), resultado);
    }
    return resultado;
  }

  @override
  Future<Pedido> obtener(int pedidoId) async {
    final version = _version;
    final pedido = await _origen.obtener(pedidoId);
    if (version == _version) _recordar(_detalles, pedidoId, pedido);
    return pedido;
  }

  @override
  Future<List<ProductoPedido>> productos(int sucursalId) =>
      _origen.productos(sucursalId);

  @override
  Future<bool> cajaAbierta(int sucursalId) => _origen.cajaAbierta(sucursalId);

  @override
  Future<int> registrar(DatosPedido datos) async {
    final id = await _origen.registrar(datos);
    _cambio(null);
    return id;
  }

  @override
  Future<void> pagar(int pedidoId, double monto, String metodo) async {
    await _origen.pagar(pedidoId, monto, metodo);
    _cambio(pedidoId);
  }

  @override
  Future<void> cambiarEstado(int pedidoId, String estado) async {
    await _origen.cambiarEstado(pedidoId, estado);
    _cambio(pedidoId);
  }

  @override
  Future<void> cancelar(int pedidoId) async {
    await _origen.cancelar(pedidoId);
    _cambio(pedidoId);
  }

  @override
  Future<void> editarDatos(int pedidoId, DatosEdicionPedido datos) async {
    await _origen.editarDatos(pedidoId, datos);
    _cambio(pedidoId);
  }

  @override
  Future<PaginaAvisos> notificaciones({int pagina = 0}) =>
      _origen.notificaciones(pagina: pagina);

  @override
  Future<void> marcarLeida(int id) => _origen.marcarLeida(id);
}
