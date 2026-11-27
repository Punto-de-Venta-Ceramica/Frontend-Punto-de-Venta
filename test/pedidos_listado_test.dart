import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'notificaciones_test_utils.dart';
import 'package:http/testing.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/notificaciones/application/contador_notificaciones.dart';
import 'package:punto_de_venta/features/pedidos/application/gestion_pedidos.dart';
import 'package:punto_de_venta/features/pedidos/application/ports/pedidos_gateway.dart';
import 'package:punto_de_venta/features/pedidos/domain/pedido.dart';
import 'package:punto_de_venta/features/pedidos/infrastructure/adapters/inbound/notificaciones_page.dart';
import 'package:punto_de_venta/features/pedidos/infrastructure/adapters/inbound/pedidos_page.dart';
import 'package:punto_de_venta/features/productos/domain/producto.dart';

class _IconoFalso implements IndicadorIcono {
  @override
  Future<void> actualizar(int cantidad) async {}
}

/// 21 pedidos: la primera página trae 20 y la segunda 1.
class _Pedidos extends Fake implements PedidosGateway {
  _Pedidos({this.estadoPedidos = 'ENCARGADO', this.caja = true});
  final String estadoPedidos;
  final bool caja;

  @override
  Future<bool> cajaAbierta(int sucursalId) async => caja;
  final llamadas = <(String?, int)>[];
  final busquedas = <String?>[];
  final consultados = <int>[];
  final cambios = <(int, String)>[];
  final editados = <(int, DatosEdicionPedido)>[];

  @override
  Future<PaginaAvisos> notificaciones({int pagina = 0}) async =>
      const PaginaAvisos(avisos: [], pagina: 0, ultima: true);

  @override
  Future<void> editarDatos(int pedidoId, DatosEdicionPedido datos) async =>
      editados.add((pedidoId, datos));

  @override
  Future<void> cambiarEstado(int pedidoId, String estado) async =>
      cambios.add((pedidoId, estado));

  ResumenPedido _resumen(int id) => ResumenPedido(
    id: id,
    estado: estadoPedidos,
    cliente: 'Cliente $id',
    tipoEntrega: 'LOCAL',
    productos: const [LineaResumen(nombre: 'Taza', cantidad: 2)],
    total: 200,
    pagado: 50,
    saldo: 150,
  );

  @override
  Future<PaginaPedidos> listar(
    int sucursalId, {
    String? estado,
    String? busqueda,
    int pagina = 0,
  }) async {
    llamadas.add((estado, pagina));
    busquedas.add(busqueda);
    // Búsqueda: 2 coincidencias, una por página.
    if (busqueda != null) {
      return PaginaPedidos(
        pedidos: [_resumen(pagina == 0 ? 5 : 15)],
        pagina: pagina,
        ultima: pagina > 0,
        total: 2,
      );
    }
    return pagina == 0
        ? PaginaPedidos(
            pedidos: [for (var i = 1; i <= 20; i++) _resumen(i)],
            pagina: 0,
            ultima: false,
            total: 21,
          )
        : PaginaPedidos(
            pedidos: [_resumen(21)],
            pagina: 1,
            ultima: true,
            total: 21,
          );
  }

  @override
  Future<Pedido> obtener(int pedidoId) async {
    consultados.add(pedidoId);
    return Pedido(
      id: pedidoId,
      folio: 'PED-000$pedidoId',
      estado: estadoPedidos,
      // Tras editar, el detalle recargado muestra el nombre guardado.
      cliente: editados.isEmpty
          ? 'Cliente $pedidoId'
          : editados.last.$2.cliente,
      telefono: '2221234567',
      ciudad: '',
      colonia: '',
      calle: '',
      descripcion: '',
      tipoEntrega: 'LOCAL',
      productos: const [
        DetallePedido(
          nombre: 'Taza',
          cantidad: 2,
          subtotal: 200,
          porcentajeDescuento: 0,
        ),
      ],
      total: 200,
      pagado: 50,
      saldo: 150,
    );
  }
}

Widget _app(_Pedidos gateway, {bool esPropietario = false}) => MaterialApp(
  theme: BarroTheme.data,
  home: PedidosPage(
    gestion: GestionPedidos(gateway),
    sucursalId: 7,
    negocio: NegocioProducto(id: 1, nombre: 'Barro'),
    esPropietario: esPropietario,
    contador: ContadorNotificaciones(
      ApiClient(
        baseUrl: 'http://localhost/',
        client: MockClient(
          (_) async => throw StateError('No se esperaba una solicitud'),
        ),
      ),
      _IconoFalso(),
    ),
  ),
);

void _pantallaAlta(WidgetTester tester) {
  // Alta para que la lista construya las 20 tarjetas y el botón de cargar más.
  tester.view.physicalSize = const Size(800, 9000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgetsConNotificaciones(
    'el empleado abre filtrado por entregado, sin folio, de 20 en 20',
    (tester) async {
      _pantallaAlta(tester);
      final gateway = _Pedidos(estadoPedidos: 'ENTREGADO');
      await tester.pumpWidget(_app(gateway));
      await tester.pumpAndSettle();

      expect(gateway.llamadas, [('ENTREGADO', 0)]);
      expect(find.text('Cliente 1'), findsOneWidget);
      expect(find.textContaining('PED-'), findsNothing);
      expect(find.text('Mostrando 20 de 21'), findsOneWidget);

      await tester.ensureVisible(find.text('Cargar más pedidos'));
      await tester.tap(find.text('Cargar más pedidos'));
      await tester.pumpAndSettle();
      expect(gateway.llamadas.last, ('ENTREGADO', 1));
      expect(find.text('Cliente 21'), findsOneWidget);
      expect(find.text('Mostrando 21 de 21'), findsOneWidget);
      expect(find.text('Cargar más pedidos'), findsNothing);

      await tester.ensureVisible(find.text('Todos'));
      await tester.tap(find.text('Todos'));
      await tester.pumpAndSettle();
      expect(gateway.llamadas.last, (null, 0));
      expect(find.text('Mostrando 20 de 21'), findsOneWidget);
    },
  );

  testWidgetsConNotificaciones(
    'la búsqueda va al servidor en todos los estados y el conteo cuadra',
    (tester) async {
      _pantallaAlta(tester);
      final gateway = _Pedidos(estadoPedidos: 'ENTREGADO');
      await tester.pumpWidget(_app(gateway));
      await tester.pumpAndSettle();
      expect(
        find.text('Buscar por cliente, teléfono o folio...'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField).first, '  ana ');
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        gateway.llamadas,
        hasLength(1),
        reason: 'espera a que se deje de escribir',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(gateway.llamadas.last, (null, 0), reason: 'sin filtro de estado');
      expect(gateway.busquedas.last, 'ana');
      expect(find.text('Buscando en todos los estados'), findsOneWidget);
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Entregado'),
      );
      expect(chip.selected, isFalse);
      expect(chip.onSelected, isNull);
      expect(find.text('Cliente 5'), findsOneWidget);
      expect(find.text('Cliente 1'), findsNothing);
      expect(find.text('Mostrando 1 de 2'), findsOneWidget);

      // La siguiente página sigue la misma búsqueda.
      await tester.ensureVisible(find.text('Cargar más pedidos'));
      await tester.tap(find.text('Cargar más pedidos'));
      await tester.pumpAndSettle();
      expect(gateway.llamadas.last, (null, 1));
      expect(gateway.busquedas.last, 'ana');
      expect(find.text('Cliente 15'), findsOneWidget);
      expect(find.text('Mostrando 2 de 2'), findsOneWidget);

      // Al borrar vuelve el filtro que se tenía.
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close_rounded), findsNothing);
      expect(
        FocusManager.instance.primaryFocus?.context?.widget,
        isNot(isA<EditableText>()),
      );
      expect(gateway.llamadas.last, ('ENTREGADO', 0));
      expect(gateway.busquedas.last, isNull);
      expect(find.text('Buscando en todos los estados'), findsNothing);
      expect(find.text('Mostrando 20 de 21'), findsOneWidget);

      // Elegir un filtro cierra el teclado del buscador.
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.ensureVisible(find.text('Todos'));
      await tester.tap(find.text('Todos'));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
      expect(gateway.llamadas.last, (null, 0));
    },
  );

  testWidgetsConNotificaciones(
    'abre el detalle en pantalla completa con el folio',
    (tester) async {
      _pantallaAlta(tester);
      final gateway = _Pedidos();
      await tester.pumpWidget(_app(gateway));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ver detalle').first);
      await tester.pumpAndSettle();

      expect(gateway.consultados, [1]);
      expect(find.text('Detalle del pedido'), findsOneWidget);
      expect(find.text('Folio: PED-0001'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('pedido-producto-imagen-0')),
        findsOneWidget,
      );
      expect(find.text('Registrar pago'), findsOneWidget);
      expect(find.text('Cancelar pedido'), findsNothing);
      // En curso y con pagos: solo el comprobante de pago, no el ticket final.
      expect(find.text('Comprobante de pago'), findsOneWidget);
      expect(find.text('Ticket'), findsNothing);
      expect(find.text('Ver ticket'), findsNothing);
    },
  );

  testWidgetsConNotificaciones(
    'con la caja cerrada el detalle no deja registrar pagos',
    (tester) async {
      _pantallaAlta(tester);
      final gateway = _Pedidos(caja: false);
      await tester.pumpWidget(_app(gateway, esPropietario: true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ver detalle').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Caja cerrada'), findsOneWidget);
      final pagar = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Registrar pago'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(pagar.onPressed, isNull);
      // Tiene $50 pagados: cancelarlo exige devolverlos desde una caja abierta.
      final cancelar = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Cancelar pedido'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(cancelar.onPressed, isNull);
    },
  );

  testWidgetsConNotificaciones(
    'un pedido terminado solo ofrece imprimir el ticket',
    (tester) async {
      _pantallaAlta(tester);
      final gateway = _Pedidos(estadoPedidos: 'TERMINADO');
      // El propietario es quien vería editar, cobrar y cancelar.
      await tester.pumpWidget(_app(gateway, esPropietario: true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ver detalle').first);
      await tester.pumpAndSettle();

      expect(find.text('Imprimir ticket'), findsOneWidget);
      expect(find.text('Ver ticket'), findsNothing);
      expect(find.text('Editar datos del pedido'), findsNothing);
      expect(find.text('Registrar pago'), findsNothing);
      expect(find.text('Cancelar pedido'), findsNothing);
    },
  );

  testWidgetsConNotificaciones('el propietario abre en encargado', (
    tester,
  ) async {
    _pantallaAlta(tester);
    final gateway = _Pedidos();
    await tester.pumpWidget(_app(gateway, esPropietario: true));
    await tester.pumpAndSettle();

    expect(gateway.llamadas, [('ENCARGADO', 0)]);
    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Encargado'),
    );
    expect(chip.selected, isTrue);
  });

  testWidgetsConNotificaciones(
    'el propietario filtra entregados y termina con confirmación',
    (tester) async {
      _pantallaAlta(tester);
      final gateway = _Pedidos(estadoPedidos: 'ENTREGADO');
      await tester.pumpWidget(_app(gateway, esPropietario: true));
      await tester.pumpAndSettle();
      final entregado = find.widgetWithText(ChoiceChip, 'Entregado');
      await tester.ensureVisible(entregado);
      await tester.pumpAndSettle();
      await tester.tap(entregado);
      await tester.pumpAndSettle();
      expect(gateway.llamadas, [('ENCARGADO', 0), ('ENTREGADO', 0)]);

      await tester.tap(find.text('Terminar pedido').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('¿Estás seguro de terminar'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(gateway.cambios, isEmpty);

      await tester.tap(find.text('Terminar pedido').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, terminar'));
      await tester.pumpAndSettle();
      expect(gateway.cambios, [(1, 'TERMINADO')]);
    },
  );

  testWidgetsConNotificaciones(
    'una sola campana: la de la cabecera, también en el detalle',
    (tester) async {
      _pantallaAlta(tester);
      await tester.pumpWidget(_app(_Pedidos()));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Notificaciones'), findsOneWidget);

      await tester.tap(find.text('Ver detalle').first);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Notificaciones'), findsOneWidget);
      await tester.tap(find.byTooltip('Notificaciones'));
      await tester.pumpAndSettle();
      expect(find.byType(NotificacionesPage), findsOneWidget);
    },
  );

  testWidgetsConNotificaciones(
    'el estado se cambia en el detalle, no en el listado',
    (tester) async {
      _pantallaAlta(tester);
      final gateway = _Pedidos();
      await tester.pumpWidget(_app(gateway, esPropietario: true));
      await tester.pumpAndSettle();
      expect(find.text('Estado del pedido'), findsNothing);
      expect(find.text('Tipo de entrega:'), findsWidgets);

      await tester.tap(find.text('Ver detalle').first);
      await tester.pumpAndSettle();
      expect(find.text('Tipo de entrega:'), findsOneWidget);
      expect(find.text('Estado del pedido'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('estado-ENCARGADO')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('En producción').last);
      await tester.pumpAndSettle();
      expect(gateway.cambios, [(1, 'PRODUCCION')]);
      expect(find.text('Estado actualizado a en producción.'), findsOneWidget);
    },
  );

  testWidgetsConNotificaciones(
    'solo el propietario ve "Editar datos del pedido"',
    (tester) async {
      _pantallaAlta(tester);
      await tester.pumpWidget(_app(_Pedidos()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver detalle').first);
      await tester.pumpAndSettle();
      expect(find.text('Editar datos del pedido'), findsNothing);
    },
  );

  testWidgetsConNotificaciones(
    'el propietario edita los datos del cliente y se recarga',
    (tester) async {
      _pantallaAlta(tester);
      final gateway = _Pedidos();
      await tester.pumpWidget(_app(gateway, esPropietario: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver detalle').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Editar datos del pedido'));
      await tester.pumpAndSettle();
      expect(find.text('Editar pedido'), findsOneWidget);
      // Precargado con los datos actuales.
      expect(find.text('2221234567'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('editar-cliente.nombre')),
        'Ana   López',
      );
      await tester.enterText(
        find.byKey(const ValueKey('editar-cliente.telefono')),
        '5512345678',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(gateway.editados, hasLength(1));
      final (id, datos) = gateway.editados.single;
      expect(id, 1);
      expect(datos.cliente, 'Ana López');
      expect(datos.telefono, '5512345678');
      expect(datos.tipoEntrega, 'LOCAL');
      // De vuelta en el detalle, ya recargado.
      expect(find.text('Detalle del pedido'), findsOneWidget);
      expect(find.text('Datos del pedido actualizados.'), findsOneWidget);
      expect(
        find.textContaining('Ana López', findRichText: true),
        findsOneWidget,
      );
    },
  );

  test('reglas del selector de estado', () {
    bool puede(String a, String b, bool propietario) =>
        EstadosPedido.puedeCambiar(a, b, esPropietario: propietario);
    expect(puede('ENCARGADO', 'PRODUCCION', true), isTrue);
    expect(puede('ENCARGADO', 'PRODUCCION', false), isFalse);
    expect(puede('ENCARGADO', 'ENTREGADO', true), isFalse);
    expect(puede('PRODUCCION', 'ENTREGADO', true), isTrue);
    expect(puede('PRODUCCION', 'ENTREGADO', false), isFalse);
    expect(puede('ENTREGADO', 'ENCARGADO', true), isFalse);
  });
}
