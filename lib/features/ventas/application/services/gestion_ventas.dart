import '../../domain/venta.dart';
import '../ports/outbound/ventas_gateway.dart';

class GestionVentas {
  const GestionVentas(this._gateway);

  final VentasGateway _gateway;

  static const productosPorPagina = 20;

  Future<PaginaProductosVenta> listarProductos(
    int sucursalId, {
    required String buscar,
    required int pagina,
  }) => _gateway.listarProductos(
    sucursalId,
    buscar: buscar,
    pagina: pagina,
    tamanio: productosPorPagina,
  );

  Future<CotizacionVenta> preparar({
    required int sucursalId,
    required List<SeleccionVenta> productos,
  }) => _gateway.preparar(sucursalId: sucursalId, productos: productos);

  Future<VentaRegistrada> confirmar({
    required int sucursalId,
    required List<SeleccionVenta> productos,
    required MetodoPagoVenta metodo,
    required String claveOperacion,
    num? montoRecibido,
  }) => _gateway.confirmar(
    sucursalId: sucursalId,
    productos: productos,
    metodo: metodo,
    claveOperacion: claveOperacion,
    montoRecibido: montoRecibido,
  );
}
