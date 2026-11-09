import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import '../../../application/ports/pedidos_gateway.dart';
import '../../../domain/pedido.dart';

class HttpPedidosGateway implements PedidosGateway {
  const HttpPedidosGateway(this._api);
  final ApiClient _api;

  @override
  Future<List<AvisoPedido>> notificaciones() async =>
      _lista(await _api.requestJson('GET', 'api/notificaciones'))
          .map(
            (j) => AvisoPedido(
              id: j['id'] as int,
              titulo: j['titulo'] as String,
              mensaje: j['mensaje'] as String,
              leida: j['leida'] as bool,
            ),
          )
          .toList();

  @override
  Future<void> marcarLeida(int id) async {
    await _api.requestJson('PATCH', 'api/notificaciones/$id/leida');
  }

  List<Map<String, dynamic>> _lista(Object? value) {
    if (value is! List) {
      throw const ApiException('La respuesta de pedidos no es válida.');
    }
    return value
        .map((item) {
          if (item is! Map<String, dynamic>) {
            throw const ApiException('La respuesta de pedidos no es válida.');
          }
          return item;
        })
        .toList(growable: false);
  }

  @override
  Future<List<Pedido>> listar(int sucursalId) async =>
      _lista(
        await _api.requestJson('GET', 'api/pedidos?sucursalId=$sucursalId'),
      ).map((j) {
        final cliente = j['cliente'] as Map<String, dynamic>;
        return Pedido(
          id: j['id'] as int,
          folio: j['folio'] as String,
          estado: j['estado'] as String,
          cliente: cliente['nombre'] as String,
          telefono: cliente['telefono'] as String? ?? '',
          ciudad: cliente['ciudad'] as String? ?? '',
          colonia: cliente['colonia'] as String? ?? '',
          calle: cliente['calle'] as String? ?? '',
          descripcion: j['descripcion'] as String? ?? '',
          tipoEntrega: j['tipoEntrega'] as String,
          productos: _lista(j['productos'])
              .map(
                (p) => DetallePedido(
                  nombre: p['nombre'] as String,
                  cantidad: p['cantidad'] as int,
                  subtotal: (p['subtotal'] as num).toDouble(),
                  porcentajeDescuento: (p['porcentajeDescuento'] as num)
                      .toDouble(),
                ),
              )
              .toList(),
          total: (j['total'] as num).toDouble(),
          pagado: (j['totalPagado'] as num).toDouble(),
          saldo: (j['saldoPendiente'] as num).toDouble(),
        );
      }).toList();

  @override
  Future<List<ProductoPedido>> productos(int sucursalId) async =>
      _lista(
            await _api.requestJson(
              'GET',
              'api/pedidos/opciones/productos?sucursalId=$sucursalId',
            ),
          )
          .map(
            (j) => ProductoPedido(
              id: j['id'] as int,
              nombre: j['nombre'] as String,
              precio: (j['precio'] as num).toDouble(),
              cantidadMinima: j['cantidadMinima'] as int?,
              cantidadMaxima: j['cantidadMaxima'] as int?,
              porcentajeDescuento: (j['porcentajeDescuento'] as num?)
                  ?.toDouble(),
            ),
          )
          .toList();

  @override
  Future<void> registrar(DatosPedido d) async {
    await _api.requestJson(
      'POST',
      'api/pedidos',
      body: {
        'sucursalId': d.sucursalId,
        'descripcion': d.descripcion.trim(),
        'cliente': {
          'nombre': d.cliente.trim(),
          'telefono': d.telefono.trim(),
          if (d.ciudad.trim().isNotEmpty) 'ciudad': d.ciudad.trim(),
          if (d.colonia.trim().isNotEmpty) 'colonia': d.colonia.trim(),
          if (d.calle.trim().isNotEmpty) 'calle': d.calle.trim(),
        },
        'productos': [
          for (final producto in d.productos)
            {'productoId': producto.productoId, 'cantidad': producto.cantidad},
        ],
        'tipoEntrega': d.tipoEntrega,
        'descripcionEnvio': d.descripcionEnvio.trim(),
        'pagoInicial': {
          'monto': d.monto,
          'metodoPago': d.metodo,
        },
      },
    );
  }

  @override
  Future<void> pagar(int id, double monto, String metodo) async =>
      _api.requestJson(
        'POST',
        'api/pedidos/$id/pagos',
        body: {'monto': monto, 'metodoPago': metodo},
      );
  @override
  Future<void> cambiarEstado(int id, String estado) async => _api.requestJson(
    'PATCH',
    'api/pedidos/$id/estado',
    body: {'estado': estado},
  );
  @override
  Future<void> cancelar(int id) async =>
      _api.requestJson('POST', 'api/pedidos/$id/cancelar');
}
