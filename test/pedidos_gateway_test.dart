import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/features/pedidos/domain/pedido.dart';
import 'package:punto_de_venta/features/pedidos/infrastructure/adapters/outbound/http_pedidos_gateway.dart';

void main() {
  test('muestra el mensaje del servidor cuando trae su código', () async {
    final casos = <(int, Map<String, String>, String)>[
      (
        409,
        {
          'codigo': 'TRANSICION_ESTADO_INVALIDA',
          'detail':
              'El pedido está en Encargado; solo puede pasar a En producción o cancelarse.',
        },
        'El pedido está en Encargado; solo puede pasar a En producción o cancelarse.',
      ),
      (
        400,
        {
          'codigo': 'CORTE_CAJA_NO_ABIERTO',
          'detail':
              'No hay un corte de caja abierto en esta sucursal. Abre uno antes de cancelar un pedido con pagos, para descontar la devolución.',
        },
        'No hay un corte de caja abierto en esta sucursal. Abre uno antes de cancelar un pedido con pagos, para descontar la devolución.',
      ),
    ];
    for (final (estado, respuesta, mensaje) in casos) {
      final client = ApiClient(
        baseUrl: 'http://localhost/',
        // En UTF-8, como el servidor: los mensajes llevan acentos.
        client: MockClient(
          (_) async =>
              http.Response.bytes(utf8.encode(jsonEncode(respuesta)), estado),
        ),
      );
      await expectLater(
        client.requestJson('PATCH', 'api/pedidos/3/estado', body: {}),
        throwsA(
          isA<ApiException>().having((e) => e.message, 'mensaje', mensaje),
        ),
      );
      client.close();
    }
  });

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
        // Fin del día elegido, en hora local, enviado como instante UTC.
        expect(
          DateTime.parse(json['fechaEntrega'] as String).toLocal(),
          DateTime(2026, 12, 24, 23, 59, 59),
        );
        return http.Response('{"id":1}', 201);
      }),
    );
    final gateway = HttpPedidosGateway(client);
    await gateway.registrar(
      DatosPedido(
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
        fechaEntrega: DateTime(2026, 12, 24),
      ),
    );
    client.close();
  });

  test(
    'edita los datos del pedido con PUT y omite la dirección vacía',
    () async {
      late http.Request enviado;
      final client = ApiClient(
        baseUrl: 'http://localhost/',
        client: MockClient((request) async {
          enviado = request;
          return http.Response('', 204);
        }),
      );
      await HttpPedidosGateway(client).editarDatos(
        9,
        const DatosEdicionPedido(
          descripcion: ' Tazas azules ',
          tipoEntrega: 'DOMICILIO',
          descripcionEnvio: 'Por la tarde',
          cliente: 'Ana López',
          telefono: '5512345678',
          calle: 'Hidalgo 123',
        ),
      );
      expect(enviado.method, 'PUT');
      expect(enviado.url.path, '/api/pedidos/9/datos');
      final json = jsonDecode(enviado.body) as Map<String, dynamic>;
      expect(json['descripcion'], 'Tazas azules');
      expect(json['tipoEntrega'], 'DOMICILIO');
      expect(json['descripcionEnvio'], 'Por la tarde');
      expect(json['cliente'], {
        'nombre': 'Ana López',
        'telefono': '5512345678',
        'calle': 'Hidalgo 123',
      });
      client.close();
    },
  );

  test('lista una página sin folio y envía estado y página', () async {
    Uri? url;
    final client = ApiClient(
      baseUrl: 'http://localhost/',
      client: MockClient((request) async {
        url = request.url;
        return http.Response(
          jsonEncode({
            'contenido': [
              {
                'id': 1,
                'sucursalId': 1,
                'tipoEntrega': 'LOCAL',
                'estado': 'ENCARGADO',
                'fechaCreacion': '2026-11-14T20:00:00Z',
                'cliente': 'Ana',
                'productos': [
                  {'nombre': 'Taza', 'cantidad': 2},
                ],
                'total': 200,
                'totalPagado': 50,
                'saldoPendiente': 150,
                'pagado': false,
              },
            ],
            'pagina': 1,
            'totalElementos': 21,
            'ultima': true,
          }),
          200,
        );
      }),
    );
    final pagina = await HttpPedidosGateway(
      client,
    ).listar(1, estado: 'ENCARGADO', busqueda: 'José & 55', pagina: 1);
    expect(url?.path, '/api/pedidos');
    expect(url?.queryParameters, {
      'sucursalId': '1',
      'page': '1',
      'estado': 'ENCARGADO',
      'q': 'José & 55',
    });
    expect(pagina.total, 21);
    expect(pagina.pagina, 1);
    expect(pagina.ultima, isTrue);
    expect(pagina.pedidos.single.cliente, 'Ana');
    expect(pagina.pedidos.single.saldo, 150);
    expect(pagina.pedidos.single.productos.single.cantidad, 2);
    client.close();
  });

  test('sin estado no envía el filtro', () async {
    Uri? url;
    final client = ApiClient(
      baseUrl: 'http://localhost/',
      client: MockClient((request) async {
        url = request.url;
        return http.Response(
          jsonEncode({
            'contenido': [],
            'pagina': 0,
            'totalElementos': 0,
            'ultima': true,
          }),
          200,
        );
      }),
    );
    await HttpPedidosGateway(client).listar(3);
    expect(url?.queryParameters, {'sucursalId': '3', 'page': '0'});
    client.close();
  });

  test('lee el folio y los saldos del detalle', () async {
    Uri? url;
    final client = ApiClient(
      baseUrl: 'http://localhost/',
      client: MockClient((request) async {
        url = request.url;
        return http.Response(
          jsonEncode({
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
          }),
          200,
        );
      }),
    );
    final pedido = await HttpPedidosGateway(client).obtener(1);
    expect(url?.path, '/api/pedidos/1');
    expect(pedido.folio, 'PED-1');
    expect(pedido.saldo, 150);
    expect(pedido.productos.single.cantidad, 2);
    expect(pedido.productos.single.porcentajeDescuento, 10);
    client.close();
  });
}
