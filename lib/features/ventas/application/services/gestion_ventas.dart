import 'package:punto_de_venta/core/infrastructure/cache/cache_en_memoria.dart';

import '../../domain/venta.dart';
import '../ports/outbound/ventas_gateway.dart';

class GestionVentas {
  GestionVentas(this._gateway);

  final VentasGateway _gateway;

  /// El artículo artesanal no cambia: se pide una vez por sucursal y no en cada venta.
  final _productosLibres = <int, ProductoVenta>{};

  /// Categorías del filtro por sucursal: casi no cambian.
  final _categorias = CacheEnMemoria<int, List<CategoriaFiltroVenta>>(
    vigencia: const Duration(minutes: 30),
  );

  static const productosPorPagina = 20;

  Future<PaginaProductosVenta> listarProductos(
    int sucursalId, {
    required String buscar,
    required int pagina,
    FiltroProductosVenta filtros = const FiltroProductosVenta(),
  }) => _gateway.listarProductos(
    sucursalId,
    buscar: buscar,
    pagina: pagina,
    tamanio: productosPorPagina,
    filtros: filtros,
  );

  Future<List<CategoriaFiltroVenta>> cargarCategorias(int sucursalId) =>
      _categorias.obtener(
        sucursalId,
        () => _gateway.cargarCategorias(sucursalId),
      );

  Future<ProductoVenta> productoLibre(int sucursalId) async =>
      _productosLibres[sucursalId] ??= await _gateway.productoLibre(sucursalId);

  /// Al cerrar sesión, o al cambiar áreas, categorías o sucursales.
  void descartar() {
    _productosLibres.clear();
    _categorias.limpiar();
  }

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
