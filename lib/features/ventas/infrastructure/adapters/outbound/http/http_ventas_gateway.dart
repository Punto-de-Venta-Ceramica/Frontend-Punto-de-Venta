import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';

import '../../../../application/ports/outbound/ventas_gateway.dart';
import '../../../../domain/venta.dart';

class HttpVentasGateway implements VentasGateway {
  const HttpVentasGateway(this._api);

  final ApiClient _api;

  @override
  Future<PaginaProductosVenta> listarProductos(
    int sucursalId, {
    required String buscar,
    required int pagina,
    required int tamanio,
    FiltroProductosVenta filtros = const FiltroProductosVenta(),
  }) => _solicitar(() async {
    final ruta = Uri(
      path: 'api/ventas/productos',
      queryParameters: {
        'sucursalId': '$sucursalId',
        'page': '$pagina',
        'size': '$tamanio',
        if (buscar.isNotEmpty) 'buscar': buscar,
        if (filtros.areaId case final id?) 'areaId': '$id',
        if (filtros.categoriaId case final id?) 'categoriaId': '$id',
        if (filtros.precioMinimo case final precio?) 'precioMinimo': '$precio',
        if (filtros.precioMaximo case final precio?) 'precioMaximo': '$precio',
      },
    );
    final respuesta = await _api.getJson(ruta.toString());
    return PaginaProductosVenta(
      productos: [
        for (final producto in _lista(respuesta['contenido']))
          ProductoVenta(
            id: producto['productoId'] as int,
            nombre: producto['nombre'] as String,
            precio: producto['precioUnitario'] as num,
            existencia: producto['existencia'] as int,
            imagenUrl: producto['imagenUrl'] as String?,
            areaId: producto['areaId'] as int?,
            areaNombre: producto['areaNombre'] as String?,
            categoriaId: producto['categoriaId'] as int?,
            categoriaNombre: producto['categoriaNombre'] as String?,
            descuentos: [
              for (final rango in _lista(producto['descuentos'] ?? const []))
                RangoDescuentoVenta(
                  cantidadMinima: rango['cantidadMinima'] as int,
                  cantidadMaxima: rango['cantidadMaxima'] as int?,
                  porcentaje: rango['porcentaje'] as num,
                ),
            ],
          ),
      ],
      pagina: respuesta['pagina'] as int,
      totalElementos: respuesta['totalElementos'] as int,
      ultima: respuesta['ultima'] as bool,
    );
  });

  @override
  Future<List<CategoriaFiltroVenta>> cargarCategorias(int sucursalId) =>
      _solicitar(() async {
        final ruta = Uri(
          path: 'api/productos/opciones/categorias',
          queryParameters: {'sucursalId': '$sucursalId'},
        );
        final respuesta = await _api.requestJson('GET', ruta.toString());
        return [
          for (final categoria in _lista(respuesta))
            CategoriaFiltroVenta(
              id: categoria['id'] as int,
              nombre: categoria['nombre'] as String,
              areaId: categoria['areaId'] as int,
              area: categoria['area'] as String,
            ),
        ];
      });

  @override
  Future<CotizacionVenta> preparar({
    required int sucursalId,
    required List<SeleccionVenta> productos,
  }) => _solicitar(() async {
    final respuesta = await _api.postJson(
      'api/ventas/preparar',
      _cuerpo(sucursalId, productos),
    );
    return CotizacionVenta(
      detalles: [
        for (final detalle in _lista(respuesta['detalles']))
          DetalleVenta(
            nombre: detalle['nombreProducto'] as String,
            cantidad: detalle['cantidad'] as int,
            precioUnitario: detalle['precioUnitario'] as num,
            subtotal: detalle['subtotal'] as num,
          ),
      ],
      descuento: respuesta['descuento'] as num,
      total: respuesta['total'] as num,
    );
  });

  @override
  Future<VentaRegistrada> confirmar({
    required int sucursalId,
    required List<SeleccionVenta> productos,
    required MetodoPagoVenta metodo,
    required String claveOperacion,
    num? montoRecibido,
  }) => _solicitar(() async {
    final respuesta =
        await _api.requestJson(
              'POST',
              'api/ventas/confirmar',
              headers: {'Idempotency-Key': claveOperacion},
              body: {
                ..._cuerpo(sucursalId, productos),
                'metodoPago': metodo.codigo,
                if (metodo == MetodoPagoVenta.efectivo)
                  'montoRecibido': montoRecibido,
              },
            )
            as Map<String, dynamic>;
    if (respuesta['confirmada'] != true) throw const FormatException();
    return VentaRegistrada(
      id: respuesta['ventaId'] as int,
      folio: respuesta['folio'] as String,
      total: respuesta['total'] as num,
      cambio: respuesta['cambio'] as num?,
      negocioEslogan: respuesta['negocioEslogan'] as String?,
    );
  });

  Map<String, dynamic> _cuerpo(
    int sucursalId,
    List<SeleccionVenta> productos,
  ) => {
    'sucursalId': sucursalId,
    'productos': [
      for (final seleccion in productos)
        {
          'productoId': seleccion.producto.id,
          'cantidad': seleccion.cantidad,
          'aplicarDescuento': seleccion.aplicarDescuento,
        },
    ],
  };

  List<Map<String, dynamic>> _lista(Object? respuesta) =>
      (respuesta as List<dynamic>).cast<Map<String, dynamic>>();

  Future<T> _solicitar<T>(Future<T> Function() accion) async {
    try {
      return await accion();
    } on ApiException catch (error) {
      throw VentaFailure(
        error.detail ?? error.message,
        estado: error.statusCode,
        errorMonto: error.fieldErrors['montoRecibido'],
      );
    } on FormatException {
      throw const VentaFailure('La respuesta de ventas no es válida.');
    } on TypeError {
      throw const VentaFailure('La respuesta de ventas no es válida.');
    }
  }
}
