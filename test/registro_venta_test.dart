import 'dart:convert';
import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as imagen_codec;
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_widgets.dart'
    show ProductoImagen;
import 'package:punto_de_venta/features/ventas/application/services/gestion_ventas.dart';
import 'package:punto_de_venta/features/ventas/domain/venta.dart';
import 'package:punto_de_venta/features/ventas/infrastructure/adapters/inbound/flutter/registrar_venta_page.dart';
import 'package:punto_de_venta/features/ventas/infrastructure/adapters/inbound/flutter/ticket_venta_dialog.dart';
import 'package:punto_de_venta/features/ventas/infrastructure/adapters/inbound/flutter/ventas_widgets.dart';
import 'package:punto_de_venta/features/ventas/infrastructure/adapters/outbound/http/http_ventas_gateway.dart';

void main() {
  testWidgets('Cancelar cierra el modal de ticket', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const TicketVentaDialog(),
            ),
            child: const Text('Abrir venta'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir venta'));
    await tester.pumpAndSettle();
    final dialogo = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialogo.titleTextStyle?.fontSize, 18);
    expect(
      tester
          .getSize(find.widgetWithText(FilledButton, 'Imprimir ticket'))
          .height,
      greaterThanOrEqualTo(52),
    );
    expect(
      tester.getSize(find.widgetWithText(OutlinedButton, 'Ver ticket')).height,
      greaterThanOrEqualTo(52),
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byType(TicketVentaDialog), findsNothing);
  });

  testWidgets('la foto vertical aumenta de alto respetando su proporción', (
    tester,
  ) async {
    final bytes = imagen_codec.encodePng(
      imagen_codec.Image(width: 30, height: 60),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 92),
            child: ProductoImagen(
              size: 72,
              bytes: bytes,
              conservarProporcion: true,
            ),
          ),
        ),
      ),
    );

    final imagen = find.byType(Image);
    final widgetImagen = tester.widget<Image>(imagen);
    await tester.runAsync(
      () => precacheImage(widgetImagen.image, tester.element(imagen)),
    );
    await tester.pump();

    expect(tester.getSize(imagen), const Size(36, 72));
  });

  testWidgets(
    'conserva la elección de descuento al paginar y reintenta el mismo cobro',
    (tester) async {
      tester.view.physicalSize = const Size(416, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final confirmaciones = <http.Request>[];
      final busquedas = <String>[];
      var cotizaciones = 0;
      final api = ApiClient(
        baseUrl: 'https://example.test/',
        client: MockClient((request) async {
          switch (request.url.path) {
            case '/api/ventas/productos':
              expect(request.method, 'GET');
              expect(request.url.queryParameters['sucursalId'], '6');
              expect(request.url.queryParameters['size'], '20');
              final pagina = int.parse(request.url.queryParameters['page']!);
              final buscar = request.url.queryParameters['buscar'];
              if (buscar != null) {
                busquedas.add(buscar);
                expect(buscar, 'Plato & barro');
                expect(pagina, 0);
              }
              final esPrimeraPagina = pagina == 0 && buscar == null;
              return _json({
                'contenido': [
                  if (esPrimeraPagina)
                    {
                      'productoId': 1,
                      'nombre': 'Taza',
                      'precioUnitario': 40,
                      'existencia': 2,
                      'areaNombre': 'Hogar',
                      'categoriaNombre': 'Vajilla',
                      'descuentos': [
                        {
                          'cantidadMinima': 2,
                          'cantidadMaxima': 2,
                          'porcentaje': 10.0,
                        },
                      ],
                    }
                  else
                    {
                      'productoId': 2,
                      'nombre': 'Plato & barro',
                      'precioUnitario': 10,
                      'existencia': 1,
                    },
                ],
                'pagina': pagina,
                'totalElementos': buscar == null ? 21 : 1,
                'ultima': !esPrimeraPagina,
              });
            case '/api/ventas/preparar':
              expect(request.method, 'POST');
              expect(jsonDecode(request.body), _carrito);
              cotizaciones++;
              return _json({
                'detalles': [
                  {
                    'nombreProducto': 'Taza',
                    'cantidad': 2,
                    'precioUnitario': 40,
                    'subtotal': 72,
                  },
                  {
                    'nombreProducto': 'Plato & barro',
                    'cantidad': 1,
                    'precioUnitario': 10,
                    'subtotal': 10,
                  },
                ],
                'descuento': 8,
                'total': 82,
              });
            case '/api/ventas/confirmar':
              expect(request.method, 'POST');
              expect(jsonDecode(request.body), {
                ..._carrito,
                'metodoPago': 'EFECTIVO',
                'montoRecibido': 100,
              });
              confirmaciones.add(request);
              return confirmaciones.length == 1
                  ? _json({}, estado: 503)
                  : _json({
                      'ventaId': 9,
                      'confirmada': true,
                      'total': 82,
                      'cambio': 18,
                    }, estado: 201);
            default:
              fail('Ruta inesperada: ${request.url}');
          }
        }),
      );
      addTearDown(api.close);
      VentaRegistrada? resultado;
      await tester.pumpWidget(
        MaterialApp(
          theme: BarroTheme.data,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  resultado = await Navigator.of(context).push<VentaRegistrada>(
                    MaterialPageRoute(
                      builder: (_) => RegistrarVentaPage(
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
                },
                child: const Text('Iniciar venta'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Iniciar venta'));
      await tester.pumpAndSettle();
      expect(find.text('Área: Hogar'), findsOneWidget);
      expect(find.text('Categoría: Vajilla'), findsOneWidget);
      final tarjeta = find.byType(VentaProductoCard);
      final importe = find.text(r'$0.00');
      final imagen = find.byType(ProductoImagen);
      expect(tester.getSize(imagen).height, 72);
      expect(tester.widget<ProductoImagen>(imagen).conservarProporcion, isTrue);
      expect(
        tester.getTopLeft(imagen).dx - tester.getTopLeft(tarjeta).dx,
        closeTo(17, 1),
      );
      expect(
        tester.getTopRight(find.text('Taza')).dx,
        closeTo(tester.getTopRight(importe).dx, 1),
      );
      expect(
        tester.getTopRight(tarjeta).dx - tester.getTopRight(importe).dx,
        closeTo(17, 1),
      );
      final agregar = find.byWidgetPredicate(
        (widget) =>
            widget is IconButton &&
            widget.tooltip == 'Agregar una pieza de Taza',
      );
      final descuento = find.byType(CheckboxListTile);
      await tester.tap(agregar);
      await tester.pump();
      expect(descuento, findsNothing);
      await tester.ensureVisible(agregar);
      await tester.tap(agregar);
      await tester.pump();
      expect(tester.widget<IconButton>(agregar).onPressed, isNull);
      expect(tester.widget<CheckboxListTile>(descuento).value, isFalse);
      expect(find.text('Aplicar descuento · 10 %'), findsOneWidget);
      expect(find.text(r'$80.00'), findsOneWidget);

      await tester.ensureVisible(descuento);
      final posicionAgregar = tester.getTopLeft(agregar);
      await tester.tap(descuento);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(agregar), posicionAgregar);
      expect(find.text(r'$72.00'), findsOneWidget);
      await tester.tap(descuento);
      await tester.pumpAndSettle();
      expect(find.text(r'$80.00'), findsOneWidget);
      await tester.tap(descuento);
      await tester.pumpAndSettle();

      final quitar = find.byTooltip('Quitar una pieza de Taza');
      await tester.ensureVisible(quitar);
      await tester.tap(quitar);
      await tester.pump();
      expect(descuento, findsNothing);
      await tester.tap(agregar);
      await tester.pump();
      expect(tester.widget<CheckboxListTile>(descuento).value, isFalse);
      await tester.ensureVisible(descuento);
      await tester.tap(descuento);
      await tester.pumpAndSettle();

      final paginaSiguiente = find.byTooltip('Página siguiente');
      await tester.ensureVisible(paginaSiguiente);
      await tester.tap(paginaSiguiente);
      await tester.pumpAndSettle();
      expect(find.text('Taza'), findsNothing);
      await tester.tap(find.byTooltip('Agregar una pieza de Plato & barro'));
      await tester.pump();

      final filtro = find.widgetWithText(FilterChip, 'Seleccionados');
      final buscador = find.byType(TextField);
      final posicionBuscador = tester.getTopLeft(buscador);
      expect(
        tester.getTopRight(filtro).dx,
        closeTo(tester.getTopRight(buscador).dx, 1),
      );
      await tester.tap(filtro);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(buscador), posicionBuscador);
      expect(find.text('Taza'), findsOneWidget);
      expect(tester.widget<CheckboxListTile>(descuento).value, isTrue);
      expect(find.text('Página 2 · 21 productos'), findsNothing);

      await tester.enterText(buscador, 'Plato & barro');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(busquedas, isEmpty);
      expect(find.text('Taza'), findsNothing);

      await tester.tap(filtro);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(buscador), posicionBuscador);
      expect(busquedas, ['Plato & barro']);
      expect(find.text('Página 2 · 21 productos'), findsNothing);
      expect(find.text('Taza'), findsNothing);
      expect(find.text('3 piezas · 2 productos'), findsOneWidget);

      await tester.tap(find.text('Continuar al pago'));
      await tester.pumpAndSettle();
      expect(cotizaciones, 1);
      expect(find.text('Descuento'), findsOneWidget);
      expect(find.text(r'$82.00'), findsOneWidget);
      final metodo = find.byType(DropdownButtonFormField<MetodoPagoVenta>);
      final campoPago = tester.getRect(metodo);
      await tester.tap(metodo);
      await tester.pumpAndSettle();
      final menu = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.role == SemanticsRole.menu,
      );
      expect(tester.getRect(menu).left, closeTo(campoPago.left, 1));
      expect(tester.getRect(menu).width, closeTo(campoPago.width, 1));
      await tester.tap(find.text('Efectivo').last);
      await tester.pumpAndSettle();
      expect(cotizaciones, 1);
      expect(find.text('Descuento'), findsOneWidget);
      expect(find.text(r'$82.00'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '50');
      await tester.tap(find.text('Registrar venta'));
      await tester.pumpAndSettle();
      expect(confirmaciones, isEmpty);
      expect(
        find.text('El efectivo recibido debe cubrir el total.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), '100');
      await tester.tap(find.text('Registrar venta'));
      await tester.pumpAndSettle();
      expect(confirmaciones, hasLength(1));
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      await tester.tap(find.text('Reintentar confirmación'));
      await tester.pumpAndSettle();

      expect(find.text('Ticket'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Imprimir ticket'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Ver ticket'),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.descendant(
          of: find.byType(TicketVentaDialog),
          matching: find.text('Cancelar'),
        ),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byType(TicketVentaDialog), findsNothing);

      expect(confirmaciones, hasLength(2));
      final clave = confirmaciones.first.headers['idempotency-key'];
      expect(clave, isNotEmpty);
      expect(confirmaciones.last.headers['idempotency-key'], clave);
      expect(resultado?.id, 9);
      expect(resultado?.cambio, 18);
      expect(find.text('Iniciar venta'), findsOneWidget);
    },
  );
}

const _carrito = {
  'sucursalId': 6,
  'productos': [
    {'productoId': 1, 'cantidad': 2, 'aplicarDescuento': true},
    {'productoId': 2, 'cantidad': 1, 'aplicarDescuento': false},
  ],
};

http.Response _json(Object data, {int estado = 200}) => http.Response(
  jsonEncode(data),
  estado,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
