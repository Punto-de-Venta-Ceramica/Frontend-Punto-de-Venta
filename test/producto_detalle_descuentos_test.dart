import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/outbound/http/http_producto_gateway.dart';

ApiClient _api(Map<String, Object?> producto) => ApiClient(
  baseUrl: 'https://example.test',
  client: MockClient(
    (_) async => http.Response(
      jsonEncode(producto),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    ),
  ),
);

void main() {
  test('el detalle trae todos los escalones de descuento', () async {
    final api = _api({
      'id': 5,
      'nombre': 'Olla',
      'precio': 100,
      'descuentos': [
        {'cantidadMinima': 5, 'cantidadMaxima': 10, 'porcentaje': 5},
        {'cantidadMinima': 11, 'cantidadMaxima': 20, 'porcentaje': 10},
        {'cantidadMinima': 21, 'cantidadMaxima': null, 'porcentaje': 15.5},
      ],
    });
    addTearDown(api.close);

    final p = await HttpProductoGateway(api).consultar(5);

    expect(
      [for (final d in p.descuentos) d.resumen],
      [
        '5 % de 5 a 10 piezas',
        '10 % de 11 a 20 piezas',
        '15.5 % desde 21 piezas',
      ],
    );
  });

  test('sin descuentos la lista queda vacía', () async {
    final api = _api({'id': 5, 'nombre': 'Olla', 'precio': 100});
    addTearDown(api.close);

    final p = await HttpProductoGateway(api).consultar(5);

    expect(p.descuentos, isEmpty);
  });
}
