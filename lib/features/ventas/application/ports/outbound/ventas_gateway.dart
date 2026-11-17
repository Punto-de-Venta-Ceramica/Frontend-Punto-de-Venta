import '../../../domain/venta.dart';

abstract interface class VentasGateway {
  Future<PaginaProductosVenta> listarProductos(
    int sucursalId, {
    required String buscar,
    required int pagina,
    required int tamanio,
    FiltroProductosVenta filtros = const FiltroProductosVenta(),
  });

  Future<List<CategoriaFiltroVenta>> cargarCategorias(int sucursalId);

  Future<CotizacionVenta> preparar({
    required int sucursalId,
    required List<SeleccionVenta> productos,
  });

  Future<VentaRegistrada> confirmar({
    required int sucursalId,
    required List<SeleccionVenta> productos,
    required MetodoPagoVenta metodo,
    required String claveOperacion,
    num? montoRecibido,
  });
}
