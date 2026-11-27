import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/ventas/application/services/gestion_ventas.dart';
import 'package:punto_de_venta/features/ventas/domain/venta.dart';
import 'package:punto_de_venta/features/ventas/infrastructure/adapters/inbound/flutter/cobro_libre_widgets.dart';
import 'package:punto_de_venta/features/ventas/infrastructure/adapters/inbound/flutter/registrar_venta_page.dart';
import 'package:punto_de_venta/features/ventas/infrastructure/adapters/inbound/flutter/ventas_widgets.dart';
import 'package:punto_de_venta/features/ventas/infrastructure/adapters/outbound/http/http_ventas_gateway.dart';

void main() {
  const varios = ProductoVenta(
    id: 77,
    nombre: 'Artículo artesanal',
    precio: 0,
    existencia: 0,
    precioVariable: true,
    descuentos: [
      RangoDescuentoVenta(cantidadMinima: 1, porcentaje: 50),
    ],
  );

  group('SeleccionVenta de cobro libre', () {
    test('usa el precio capturado, no el del producto, y nunca descuenta', () {
      const linea = SeleccionVenta(
        producto: varios,
        cantidad: 5,
        aplicarDescuento: true,
        precioLibre: 10.5,
        nombreLibre: 'Servilletas',
      );

      expect(linea.importe, 52.5);
      expect(linea.nombre, 'Servilletas');
      expect(linea.porcentajeDisponible, isNull);
      expect(linea.aplicarDescuento, isFalse);
    });

    test('al actualizar la cantidad conserva precio y nombre', () {
      const linea = SeleccionVenta(
        producto: varios,
        cantidad: 1,
        precioLibre: 12,
        nombreLibre: 'Bolsas',
      );

      final nueva = linea.actualizar(varios, 3);

      expect(nueva.precioLibre, 12);
      expect(nueva.nombreLibre, 'Bolsas');
      expect(nueva.importe, 36);
    });

    test('sin nombre propio se llama como el producto', () {
      const linea = SeleccionVenta(
        producto: varios,
        cantidad: 1,
        precioLibre: 1,
      );
      expect(linea.nombre, 'Artículo artesanal');
    });

    test('un producto normal calcula igual que antes', () {
      const taza = ProductoVenta(
        id: 1,
        nombre: 'Taza',
        precio: 40,
        existencia: 5,
        descuentos: [
          RangoDescuentoVenta(cantidadMinima: 2, porcentaje: 10),
        ],
      );
      const linea = SeleccionVenta(
        producto: taza,
        cantidad: 2,
        aplicarDescuento: true,
      );

      expect(linea.importe, 72);
      expect(linea.nombre, 'Taza');
      expect(linea.esLibre, isFalse);
    });
  });

  testWidgets('cobra un producto sin registrar con precio y nombre propios', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(416, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cuerposPreparar = <Object?>[];
    var consultasProductoLibre = 0;
    final api = ApiClient(
      baseUrl: 'https://example.test/',
      client: MockClient((request) async {
        switch (request.url.path) {
          case '/api/ventas/productos':
            return _json({
              'contenido': [
                {
                  'productoId': 1,
                  'nombre': 'Taza',
                  'precioUnitario': 40,
                  'existencia': 2,
                },
              ],
              'pagina': 0,
              'totalElementos': 1,
              'ultima': true,
            });
          case '/api/ventas/producto-libre':
            expect(request.method, 'GET');
            expect(request.url.queryParameters['sucursalId'], '6');
            consultasProductoLibre++;
            return _json({'productoId': 77, 'nombre': 'Artículo artesanal'});
          case '/api/ventas/preparar':
            cuerposPreparar.add(jsonDecode(request.body));
            return _json({
              'detalles': [
                {
                  'nombreProducto': 'Servilletas',
                  'cantidad': 5,
                  'precioUnitario': 10,
                  'subtotal': 50,
                },
              ],
              'descuento': 0,
              'total': 50,
            });
          default:
            fail('Ruta inesperada: ${request.url}');
        }
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: BarroTheme.data,
        home: RegistrarVentaPage(
          contexto: const VentaContexto(
            negocio: 'Cerámica',
            sucursal: 'Centro',
            rol: 'Empleado',
          ),
          gestion: GestionVentas(HttpVentasGateway(api)),
          sucursalId: 6,
          onSesionExpirada: () => fail('Sesión expirada'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final continuar = find.widgetWithText(FilledButton, 'Continuar al pago');
    // La tarjeta solo dice «Cobro libre», en negrita y sin el nombre del producto.
    final invitacion = find.descendant(
      of: find.byType(TarjetaCobroLibre),
      matching: find.text('Cobro libre'),
    );
    expect(invitacion, findsOneWidget);
    expect(tester.widget<Text>(invitacion).style?.fontWeight, FontWeight.w700);
    expect(find.textContaining('Artículo artesanal'), findsNothing);
    expect(tester.widget<FilledButton>(continuar).onPressed, isNull);

    // La hoja pide el precio, la cantidad y una descripción opcional.
    final hoja = find.byType(BottomSheet);
    final campos = find.descendant(of: hoja, matching: find.byType(TextField));
    await tester.tap(invitacion);
    await tester.pumpAndSettle();
    expect(consultasProductoLibre, 1);
    // La nota va debajo del campo, no dentro de él.
    const nota =
        'Nota: Si dejas el nombre vacío, se registrará como «Artículo artesanal».';
    expect(find.text(nota), findsOneWidget);
    expect(
      tester.widget<TextField>(campos.at(2)).decoration?.hintText,
      'Ej. Servilletas',
    );
    expect(find.text('Escribe el precio para ver el total'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Agregar al cobro'),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(campos.at(0), '10');
    await tester.enterText(campos.at(1), '5');
    await tester.enterText(campos.at(2), 'Servilletas');
    await tester.pump();
    expect(find.text(r'5 × $10.00 c/u'), findsOneWidget);
    expect(find.text(r'$50.00'), findsOneWidget);
    await tester.ensureVisible(find.text('Agregar al cobro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar al cobro'));
    await tester.pumpAndSettle();

    // La línea queda resumida y se puede corregir o quitar.
    expect(find.text('Servilletas'), findsOneWidget);
    expect(find.text(r'Cobro libre · 5 × $10.00 c/u'), findsOneWidget);
    expect(find.text('5 piezas · 1 productos'), findsOneWidget);
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(consultasProductoLibre, 1, reason: 'el producto se pide una vez');
    expect(
      tester.widget<TextField>(campos.at(0)).controller?.text,
      '10',
    );
    await tester.ensureVisible(find.text('Quitar de la venta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitar de la venta'));
    await tester.pumpAndSettle();
    expect(invitacion, findsOneWidget);
    expect(tester.widget<FilledButton>(continuar).onPressed, isNull);

    await tester.tap(invitacion);
    await tester.pumpAndSettle();
    await tester.enterText(campos.at(0), '10');
    await tester.enterText(campos.at(1), '5');
    await tester.enterText(campos.at(2), '  Servilletas ');
    await tester.pump();
    await tester.ensureVisible(find.text('Agregar al cobro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar al cobro'));
    await tester.pumpAndSettle();

    await tester.tap(continuar);
    await tester.pumpAndSettle();

    expect(cuerposPreparar, [
      {
        'sucursalId': 6,
        'productos': [
          {
            'productoId': 77,
            'cantidad': 5,
            'aplicarDescuento': false,
            'precioUnitario': 10,
            'nombre': 'Servilletas',
          },
        ],
      },
    ]);
    expect(find.text('Servilletas'), findsOneWidget);
    expect(find.text(r'$10.00 c/u'), findsOneWidget);
    expect(find.text(r'$50.00'), findsWidgets);
  });
}

http.Response _json(Object data, {int estado = 200}) => http.Response(
  jsonEncode(data),
  estado,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
