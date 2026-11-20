import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/features/productos/application/services/gestion_productos.dart';
import 'package:punto_de_venta/features/productos/domain/producto.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/productos_page.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/outbound/http/http_existencias_gateway.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/outbound/http/http_producto_gateway.dart';

void main() {
  testWidgets('sucursal sin productos muestra el registro del primero', (
    tester,
  ) async {
    final rutas = <String>[];
    final api = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((req) async {
        rutas.add('${req.method} ${req.url}');
        final cuerpo = req.url.path == '/api/productos'
            ? {
                'contenido': [],
                'pagina': 0,
                'totalElementos': 0,
                'ultima': true,
              }
            : [];
        return http.Response(
          jsonEncode(cuerpo),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(api.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ProductosPage(
          gestion: GestionProductos(
            HttpProductoGateway(api),
            HttpExistenciasGateway(api),
          ),
          negocioInicial: const NegocioProducto(id: 2, nombre: 'Prueba'),
          sucursal: const SucursalProducto(id: 2, nombre: 'Lindavista'),
          onSesionExpirada: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    debugPrint(rutas.join('\n'));
    expect(find.text('Registrar mi primer producto'), findsOneWidget);
  });
}
