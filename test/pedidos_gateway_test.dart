import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/features/pedidos/domain/pedido.dart';
import 'package:punto_de_venta/features/pedidos/infrastructure/adapters/outbound/http_pedidos_gateway.dart';

void main() {
  test('identifica errores de pedidos sin mostrar detalles técnicos', () async {
    final casos = <(Map<String, String>, String?, String)>[
      (
        {'codigo': 'CORTE_CAJA_NO_ABIERTO'},
        'CORTE_CAJA_NO_ABIERTO',
        'No hay un corte de caja abierto en esta sucursal. Abre uno antes de registrar un pago.',
      ),
      (
        {
          'detail':
              'Debe haber un corte de caja abierto para la sucursal del pedido.',
        },
        'CORTE_CAJA_NO_ABIERTO',
        'No hay un corte de caja abierto en esta sucursal. Abre uno antes de registrar un pago.',
      ),
      (
        {'codigo': 'PAGO_SUPERA_SALDO'},
        'PAGO_SUPERA_SALDO',
        'El pago supera el saldo calculado por el servidor. Actualiza el pedido y revisa el importe.',
      ),
      (
        {'codigo': 'PRODUCTO_NO_DISPONIBLE'},
        'PRODUCTO_NO_DISPONIBLE',
        'Uno de los productos ya no está disponible. Vuelve a la lista de pedidos e inicia el registro de nuevo.',
      ),
      ({'detail': 'SQL SECRETO'}, null, 'Revisa los datos del formulario.'),
    ];
    for (final (respuesta, codigo, mensaje) in casos) {
      final client = ApiClient(
        baseUrl: 'http://localhost/',
        client: MockClient(
          (_) async => http.Response(jsonEncode(respuesta), 400),
        ),
      );
      await expectLater(
        client.requestJson('POST', 'api/pedidos', body: {}),
        throwsA(
          isA<ApiException>()
              .having((error) => error.code, 'código', codigo)
              .having((error) => error.message, 'mensaje', mensaje),
        ),
      );
      client.close();
    }
  });

  test('envía pedido y anticipo sin incluir un corte de caja', () async {
    final client = ApiClient(
      baseUrl: 'http://localhost/',
      client: MockClient((request) async {
        expect(request.url.path, '/api/pedidos');
        final json = jsonDecode(request.body) as Map<String, dynamic>;
        expect(json['cliente']['calle'], 'Hidalgo 123');
        expect(json['cliente'].containsKey('numero'), isFalse);
        expect(json.containsKey('nombre'), isFalse);
        expect(json['pagoInicial'].containsKey('corteCajaId'), isFalse);
        expect(json['productos'][0]['productoId'], 3);
        expect(json['productos'][1]['productoId'], 4);
        return http.Response('{"id":1}', 201);
      }),
    );
    final gateway = HttpPedidosGateway(client);
    await gateway.registrar(
      const DatosPedido(
        sucursalId: 1,
        descripcion: '',
        cliente: 'Ana',
        telefono: '5512345678',
        ciudad: 'Puebla',
        colonia: 'Centro',
        calle: 'Hidalgo 123',
        productos: [
          LineaPedido(productoId: 3, cantidad: 2),
          LineaPedido(productoId: 4, cantidad: 1),
        ],
        tipoEntrega: 'LOCAL',
        descripcionEnvio: '',
        monto: 25,
        metodo: 'EFECTIVO',
      ),
    );
    client.close();
  });

  test('lee folio y saldos del backend', () async {
    final client = ApiClient(
      baseUrl: 'http://localhost/',
      client: MockClient(
        (request) async => http.Response(
          jsonEncode([
            {
              'id': 1,
              'folio': 'PED-1',
              'estado': 'ENCARGADO',
              'tipoEntrega': 'LOCAL',
              'descripcion': null,
              'cliente': {
                'nombre': 'Ana',
                'telefono': '123',
                'ciudad': 'Puebla',
                'colonia': 'Centro',
                'calle': 'Hidalgo 123',
              },
              'productos': [
                {
                  'nombre': 'Taza',
                  'cantidad': 2,
                  'subtotal': 200,
                  'porcentajeDescuento': 10,
                },
              ],
              'total': 200,
              'totalPagado': 50,
              'saldoPendiente': 150,
            },
          ]),
          200,
        ),
      ),
    );
    final pedidos = await HttpPedidosGateway(client).listar(1);
    expect(pedidos.single.folio, 'PED-1');
    expect(pedidos.single.saldo, 150);
    expect(pedidos.single.productos.single.cantidad, 2);
    expect(pedidos.single.productos.single.porcentajeDescuento, 10);
    client.close();
  });
}
