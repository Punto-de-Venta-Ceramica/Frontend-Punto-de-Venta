import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:material_ui/material_ui.dart'
    as mui
    show DefaultMaterialLocalizations, GlobalMaterialLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/pedidos/application/gestion_pedidos.dart';
import 'package:punto_de_venta/features/pedidos/application/ports/pedidos_gateway.dart';
import 'package:punto_de_venta/features/pedidos/domain/pedido.dart';
import 'package:punto_de_venta/features/pedidos/infrastructure/adapters/inbound/pedido_input_formatters.dart';
import 'package:punto_de_venta/features/pedidos/infrastructure/adapters/inbound/registrar_pedido_page.dart';
import 'package:punto_de_venta/features/productos/domain/producto.dart';
import 'package:punto_de_venta/features/sucursal/infrastructure/adapters/inbound/flutter/sucursal_widgets.dart';

class _Gateway implements PedidosGateway {
  _Gateway({this.caja = true});
  final bool caja;
  DatosPedido? recibido;
  ApiException? errorAlRegistrar;
  @override
  Future<bool> cajaAbierta(int sucursalId) async => caja;
  @override
  Future<PaginaAvisos> notificaciones({int pagina = 0}) async =>
      const PaginaAvisos(avisos: [], pagina: 0, ultima: true);
  @override
  Future<void> marcarLeida(int id) async {}
  @override
  Future<List<ProductoPedido>> productos(int id) async => [
    const ProductoPedido(
      id: 3,
      nombre: 'Taza',
      precio: 100,
      descuentos: [EscalonDescuento(cantidadMinima: 2, porcentaje: 10)],
      areaId: 1,
      area: 'Cocina',
      categoriaId: 10,
      categoria: 'Tazas',
    ),
    const ProductoPedido(
      id: 4,
      nombre: 'Plato',
      precio: 50,
      areaId: 1,
      area: 'Cocina',
      categoriaId: 11,
      categoria: 'Platos',
    ),
    const ProductoPedido(
      id: 5,
      nombre: 'Ánfora',
      precio: 80,
      areaId: 2,
      area: 'Decoración',
      categoriaId: 20,
      categoria: 'Jarrones',
    ),
  ];
  @override
  Future<int> registrar(DatosPedido datos) async {
    if (errorAlRegistrar != null) throw errorAlRegistrar!;
    recibido = datos;
    return 1;
  }

  @override
  Future<PaginaPedidos> listar(
    int id, {
    String? estado,
    String? busqueda,
    int pagina = 0,
  }) async =>
      const PaginaPedidos(pedidos: [], pagina: 0, ultima: true, total: 0);
  @override
  Future<Pedido> obtener(int id) async => throw UnimplementedError();
  @override
  Future<void> pagar(int id, double monto, String metodo) async {}
  @override
  Future<void> cambiarEstado(int id, String estado) async {}
  @override
  Future<void> cancelar(int id) async {}
  @override
  Future<void> editarDatos(int id, DatosEdicionPedido datos) async {}
}

void main() {
  testWidgets('captura el pedido en tres pasos sin pedir un corte de caja', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(416, 858);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _Gateway();
    await tester.pumpWidget(
      MaterialApp(
        theme: BarroTheme.data,
        localizationsDelegates: const [
          mui.DefaultMaterialLocalizations.delegate,
        ],
        home: RegistrarPedidoPage(
          gestion: GestionPedidos(gateway),
          sucursalId: 1,
          negocio: const NegocioProducto(id: 1, nombre: 'Cerámica'),
          esPropietario: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('BarroControl')).dy, lessThan(100));
    Finder enNavegacion(String texto) => find.descendant(
      of: find.byType(SucursalNavegacion),
      matching: find.text(texto),
    );
    for (final rotulo in [
      'Inicio',
      'Pedidos',
      'Caja',
      'Productos',
      'Reportes',
    ]) {
      expect(enNavegacion(rotulo), findsOneWidget);
    }
    // La pestaña activa se distingue por su rótulo en negritas.
    expect(
      tester.widget<Text>(enNavegacion('Pedidos')).style?.fontWeight,
      FontWeight.w700,
    );
    await tester.enterText(
      find.byType(TextFormField).first,
      '  Pedido   de 5 piezas  ',
    );
    await tester.ensureVisible(find.text('Selecciona un producto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selecciona un producto'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Ánfora')).dy,
      lessThan(tester.getTopLeft(find.text('Plato')).dy),
    );
    await tester.tap(find.text('Taza').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), ' 2x ');
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller!
          .text,
      '2',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Agregar producto'));
    await tester.tap(find.text('Agregar producto'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aplica descuento de mayoreo'), findsOneWidget);
    expect(find.text('Selecciona un producto'), findsOneWidget);
    expect(find.byKey(const ValueKey('pedido-cantidad')), findsNothing);
    expect(find.byKey(const ValueKey('pedido-linea-3')), findsOneWidget);
    await tester.ensureVisible(find.text('Selecciona un producto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selecciona un producto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plato').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), '1');
    await tester.pumpAndSettle();
    await elegirFechaEntrega(tester);
    await tester.ensureVisible(find.text('Continuar'));
    // Espera a que termine el desplazamiento por el foco del campo.
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), '  An4a   María  ');
    await tester.enterText(campos.at(1), '123');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continuar'));
    // Espera a que termine el desplazamiento por el foco del campo.
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(
      find.text('El teléfono debe contener exactamente 10 dígitos.'),
      findsOneWidget,
    );
    await tester.ensureVisible(campos.at(1));
    await tester.enterText(campos.at(1), '55a1234 567899');
    expect(
      tester.widget<TextFormField>(campos.at(1)).controller!.text,
      '5512345678',
    );
    await tester.enterText(campos.at(2), '  Puebla  ');
    await tester.enterText(campos.at(3), '  5   de  Mayo  ');
    await tester.enterText(campos.at(4), '  Calle   12  #34  ');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continuar'));
    // Espera a que termine el desplazamiento por el foco del campo.
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    final total = find.byKey(const ValueKey('pedido-total-estimado'));
    final saldo = find.byKey(const ValueKey('pedido-saldo-estimado'));
    expect(tester.widget<Text>(total).data, r'$230.00');
    expect(tester.widget<Text>(saldo).data, r'$230.00');
    final avisoAnticipo = find.textContaining(
      'La función de corte de caja aún está en desarrollo',
    );
    expect(avisoAnticipo, findsNothing);
    await tester.enterText(find.byType(TextFormField).first, '5a0 ');
    await tester.pump();
    // El corte de caja ya existe: capturar un anticipo no muestra el aviso.
    expect(avisoAnticipo, findsNothing);
    expect(tester.widget<Text>(saldo).data, r'$180.00');
    await tester.enterText(find.byType(TextFormField).first, '10,50');
    await tester.pump();
    expect(tester.widget<Text>(saldo).data, r'$219.50');
    await tester.enterText(find.byType(TextFormField).first, '230');
    await tester.pump();
    expect(tester.widget<Text>(saldo).data, r'$0.00');
    await tester.enterText(find.byType(TextFormField).first, '231');
    await tester.pump();
    expect(tester.widget<Text>(saldo).data, '—');
    expect(find.text('El anticipo supera el total estimado.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '0');
    await tester.pump();
    expect(avisoAnticipo, findsNothing);
    await tester.enterText(find.byType(TextFormField).first, '50');
    await tester.pump();
    await tester.ensureVisible(find.text('Registrar pedido').last);
    // Espera a que termine el desplazamiento por el foco del campo.
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar pedido').last);
    await tester.pumpAndSettle();
    // Con anticipo se ofrece imprimir el comprobante antes de salir.
    expect(find.text('Pedido registrado'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('comprobante-listo')));
    await tester.pumpAndSettle();
    expect(find.text('Pedido registrado'), findsNothing);
    expect(gateway.recibido?.descripcion, 'Pedido de 5 piezas');
    expect(gateway.recibido?.cliente, 'Ana María');
    expect(gateway.recibido?.telefono, '5512345678');
    expect(gateway.recibido?.ciudad, 'Puebla');
    expect(gateway.recibido?.colonia, '5 de Mayo');
    expect(gateway.recibido?.calle, 'Calle 12 #34');
    expect(gateway.recibido?.productos.map((p) => p.productoId), [3, 4]);
  });

  testWidgets('ordena, filtra y selecciona productos en el modal', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BarroTheme.data,
        localizationsDelegates: const [
          mui.DefaultMaterialLocalizations.delegate,
        ],
        home: RegistrarPedidoPage(
          gestion: GestionPedidos(_Gateway()),
          sucursalId: 1,
          negocio: const NegocioProducto(id: 1, nombre: 'Cerámica'),
          esPropietario: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Con las leyendas el selector queda bajo la barra inferior en 800×600.
    await tester.ensureVisible(find.text('Selecciona un producto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selecciona un producto'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Plato')).dy,
      lessThan(tester.getTopLeft(find.text('Taza')).dy),
    );
    final buscador = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byKey(const ValueKey('pedido-buscar-producto')),
    );
    await tester.enterText(buscador, 'anfora');
    await tester.pumpAndSettle();
    expect(find.text('Ánfora'), findsOneWidget);
    expect(find.text('Plato'), findsNothing);
    await tester.enterText(buscador, 'TAZ');
    await tester.pumpAndSettle();
    expect(find.text('Plato'), findsNothing);
    expect(find.text('Taza'), findsOneWidget);
    await tester.enterText(buscador, 'inexistente');
    await tester.pumpAndSettle();
    expect(find.text('No se encontraron productos.'), findsOneWidget);
    await tester.enterText(buscador, 'taz');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Taza'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('pedido-producto-seleccionado')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Quitar selección de producto'));
    await tester.pumpAndSettle();
    expect(find.text('Selecciona un producto'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('pedido-producto-seleccionado')),
      findsNothing,
    );
  });

  testWidgets('filtra el modal por área y categoría', (tester) async {
    tester.view.physicalSize = const Size(416, 858);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: BarroTheme.data,
        localizationsDelegates: const [
          mui.DefaultMaterialLocalizations.delegate,
        ],
        home: RegistrarPedidoPage(
          gestion: GestionPedidos(_Gateway()),
          sucursalId: 1,
          negocio: const NegocioProducto(id: 1, nombre: 'Cerámica'),
          esPropietario: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Selecciona un producto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selecciona un producto'));
    await tester.pumpAndSettle();
    expect(find.text('3 productos'), findsOneWidget);
    expect(find.text('Cocina · Tazas'), findsOneWidget);

    await tester.tap(find.text('Todas las áreas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cocina').last, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('2 productos'), findsOneWidget);
    expect(find.text('Ánfora'), findsNothing);

    await tester.tap(find.text('Todas las categorías'));
    await tester.pumpAndSettle();
    // Solo se ofrecen las categorías del área elegida.
    expect(find.text('Jarrones'), findsNothing);
    await tester.tap(find.text('Platos').last, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('1 producto'), findsOneWidget);
    expect(find.text('Plato'), findsOneWidget);
    expect(find.text('Taza'), findsNothing);

    await tester.tap(find.text('Limpiar filtros'));
    await tester.pumpAndSettle();
    expect(find.text('3 productos'), findsOneWidget);
    await tester.tap(find.text('Taza'));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Agregar producto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar producto'));
    await tester.pumpAndSettle();

    // Ajusta la cantidad desde el renglón y recalcula el total con mayoreo.
    await tester.ensureVisible(find.byTooltip('Sumar una pieza de Taza'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sumar una pieza de Taza'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('pedido-linea-cantidad-3')))
          .data,
      '2',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('pedido-total-lineas')))
          .data,
      '\$180.00',
    );

    // Un producto ya agregado aparece marcado y no se puede volver a elegir.
    await tester.ensureVisible(find.text('Selecciona un producto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selecciona un producto'));
    await tester.pumpAndSettle();
    expect(find.text('En el pedido · 2 piezas'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pedido-opcion-producto-3')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets(
    'en español: el calendario y el selector de productos funcionan',
    (tester) async {
      tester.view.physicalSize = const Size(416, 858);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // Misma configuración de idioma que la app (main.dart).
      await tester.pumpWidget(
        MaterialApp(
          theme: BarroTheme.data,
          localizationsDelegates: const [
            ...GlobalMaterialLocalizations.delegates,
            mui.GlobalMaterialLocalizations.delegate,
          ],
          supportedLocales: const [Locale('es', 'MX')],
          locale: const Locale('es', 'MX'),
          home: RegistrarPedidoPage(
            gestion: GestionPedidos(_Gateway()),
            sucursalId: 1,
            negocio: const NegocioProducto(id: 1, nombre: 'Cerámica'),
            esPropietario: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // El selector de productos (dropdown_search) se dibuja sin errores.
      await tester.ensureVisible(find.text('Selecciona un producto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Selecciona un producto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Taza'));
      await tester.pumpAndSettle();

      final campo = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              'pedido-fecha-entrega',
            ),
      );
      await tester.ensureVisible(campo);
      await tester.pumpAndSettle();
      await tester.tap(campo);
      await tester.pumpAndSettle();
      const meses = [
        'enero',
        'febrero',
        'marzo',
        'abril',
        'mayo',
        'junio',
        'julio',
        'agosto',
        'septiembre',
        'octubre',
        'noviembre',
        'diciembre',
      ];
      final mes = meses[DateTime.now().month - 1];
      expect(find.textContaining(mes), findsWidgets);
      expect(find.text('Aceptar'), findsOneWidget);
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('regresa a pasos anteriores sin perder lo capturado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(416, 858);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: BarroTheme.data,
        localizationsDelegates: const [
          mui.DefaultMaterialLocalizations.delegate,
        ],
        home: RegistrarPedidoPage(
          gestion: GestionPedidos(_Gateway()),
          sucursalId: 1,
          negocio: const NegocioProducto(id: 1, nombre: 'Cerámica'),
          esPropietario: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Selecciona un producto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selecciona un producto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Taza'));
    await tester.pumpAndSettle();
    await elegirFechaEntrega(tester);
    await tester.ensureVisible(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'Ana');
    await tester.enterText(campos.at(1), '5512345678');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Resumen del pedido'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);

    // Tocar el paso 2 del indicador vuelve a los datos del cliente.
    await tester.ensureVisible(find.byKey(const ValueKey('pedido-paso-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pedido-paso-1')));
    await tester.pumpAndSettle();
    expect(find.text('Datos de contacto'), findsOneWidget);
    expect(tester.widget<TextFormField>(campos.at(0)).controller!.text, 'Ana');

    // El botón atrás del sistema retrocede un paso en vez de salir.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pedido-linea-3')), findsOneWidget);
    expect(find.byType(RegistrarPedidoPage), findsOneWidget);
  });

  testWidgets('con la caja cerrada registra el pedido sin anticipo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(416, 858);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _Gateway(caja: false);
    await tester.pumpWidget(
      MaterialApp(
        theme: BarroTheme.data,
        localizationsDelegates: const [
          mui.DefaultMaterialLocalizations.delegate,
        ],
        home: RegistrarPedidoPage(
          gestion: GestionPedidos(gateway),
          sucursalId: 1,
          negocio: const NegocioProducto(id: 1, nombre: 'Cerámica'),
          esPropietario: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Selecciona un producto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selecciona un producto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Taza'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), '1');
    await tester.pumpAndSettle();
    await elegirFechaEntrega(tester);
    await tester.ensureVisible(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'Ana');
    await tester.enterText(campos.at(1), '5512345678');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Caja cerrada'), findsOneWidget);
    expect(find.text('Tipo de pago *'), findsNothing);
    final anticipo = tester.widget<TextFormField>(
      find.byType(TextFormField).last,
    );
    expect(anticipo.enabled, isFalse);
    expect(anticipo.controller!.text, '0');

    await tester.ensureVisible(find.text('Registrar pedido').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar pedido').last);
    await tester.pumpAndSettle();
    expect(gateway.recibido?.monto, 0);
  });

  testWidgets('permite no aplicar el descuento vigente de un producto', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(416, 858);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _Gateway();
    await tester.pumpWidget(
      MaterialApp(
        theme: BarroTheme.data,
        localizationsDelegates: const [
          mui.DefaultMaterialLocalizations.delegate,
        ],
        home: RegistrarPedidoPage(
          gestion: GestionPedidos(gateway),
          sucursalId: 1,
          negocio: const NegocioProducto(id: 1, nombre: 'Cerámica'),
          esPropietario: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Selecciona un producto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selecciona un producto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Taza'));
    await tester.pumpAndSettle();
    // 2 tazas: aplica el 10 % de mayoreo.
    await tester.enterText(find.byType(TextFormField).at(1), '2');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Agregar producto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar producto'));
    await tester.pumpAndSettle();

    final interruptor = find.byKey(const ValueKey('aplicar-descuento-3'));
    expect(tester.widget<Switch>(interruptor).value, isTrue);
    await tester.ensureVisible(interruptor);
    await tester.pumpAndSettle();
    await tester.tap(interruptor);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(interruptor).value, isFalse);
    expect(find.textContaining('sin aplicar'), findsOneWidget);

    await tester.pumpAndSettle();
    await elegirFechaEntrega(tester);
    await tester.ensureVisible(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'Ana');
    await tester.enterText(campos.at(1), '5512345678');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    // Precio de lista: 2 × $100.
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('pedido-total-estimado')))
          .data,
      r'$200.00',
    );
    await tester.ensureVisible(find.text('Registrar pedido').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar pedido').last);
    await tester.pumpAndSettle();
    expect(gateway.recibido?.productos.single.aplicarDescuento, isFalse);
  });

  group('barra inferior al registrar', () {
    Future<List<String>> abrir(WidgetTester tester) async {
      tester.view.physicalSize = const Size(416, 858);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final destinos = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: BarroTheme.data,
          localizationsDelegates: const [
            mui.DefaultMaterialLocalizations.delegate,
          ],
          home: const Scaffold(body: Text('Listado')),
        ),
      );
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(
            MaterialPageRoute<void>(
              builder: (_) => RegistrarPedidoPage(
                gestion: GestionPedidos(_Gateway()),
                sucursalId: 1,
                negocio: const NegocioProducto(id: 1, nombre: 'Cerámica'),
                esPropietario: true,
                onInicio: () => destinos.add('inicio'),
                onCaja: () => destinos.add('caja'),
              ),
            ),
          );
      await tester.pumpAndSettle();
      return destinos;
    }

    testWidgets('sin datos capturados, Inicio sale directo', (tester) async {
      final destinos = await abrir(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(SucursalNavegacion),
          matching: find.text('Inicio'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Listado'), findsOneWidget);
      expect(destinos, ['inicio']);
      expect(find.textContaining('aún no está disponible'), findsNothing);
    });

    testWidgets('con datos capturados, pide confirmación antes de salir', (
      tester,
    ) async {
      final destinos = await abrir(tester);
      await tester.enterText(find.byType(TextFormField).first, 'Tazas');
      // Espera a que termine el desplazamiento por el foco del campo.
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(SucursalNavegacion),
          matching: find.text('Caja'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('¿Salir sin registrar el pedido?'), findsOneWidget);

      await tester.tap(find.text('Seguir capturando'));
      await tester.pumpAndSettle();
      expect(find.byType(RegistrarPedidoPage), findsOneWidget);
      expect(destinos, isEmpty);

      await tester.tap(
        find.descendant(
          of: find.byType(SucursalNavegacion),
          matching: find.text('Caja'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salir sin guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Listado'), findsOneWidget);
      expect(destinos, ['caja']);
    });
  });

  testWidgets('permite registrar sin dirección del cliente', (tester) async {
    tester.view.physicalSize = const Size(416, 858);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _Gateway();
    await tester.pumpWidget(
      MaterialApp(
        theme: BarroTheme.data,
        localizationsDelegates: const [
          mui.DefaultMaterialLocalizations.delegate,
        ],
        home: RegistrarPedidoPage(
          gestion: GestionPedidos(gateway),
          sucursalId: 1,
          negocio: const NegocioProducto(id: 1, nombre: 'Cerámica'),
          esPropietario: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Selecciona un producto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selecciona un producto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Taza'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), '1');
    await tester.pumpAndSettle();
    await elegirFechaEntrega(tester);
    await tester.ensureVisible(find.text('Continuar'));
    // Espera a que termine el desplazamiento por el foco del campo.
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'Ana');
    await tester.enterText(campos.at(1), '5512345678');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continuar'));
    // Espera a que termine el desplazamiento por el foco del campo.
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Registrar pedido').last);
    // Espera a que termine el desplazamiento por el foco del campo.
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar pedido').last);
    await tester.pumpAndSettle();
    expect(gateway.recibido?.ciudad, isEmpty);
    expect(gateway.recibido?.colonia, isEmpty);
    expect(gateway.recibido?.calle, isEmpty);
  });

  testWidgets('muestra la causa del rechazo y ubica los campos con error', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(416, 858);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _Gateway()
      ..errorAlRegistrar = const ApiException(
        'No hay un corte de caja abierto en esta sucursal. Abre uno antes de registrar un pago.',
        statusCode: 400,
        code: 'CORTE_CAJA_NO_ABIERTO',
      );
    await tester.pumpWidget(
      MaterialApp(
        theme: BarroTheme.data,
        localizationsDelegates: const [
          mui.DefaultMaterialLocalizations.delegate,
        ],
        home: RegistrarPedidoPage(
          gestion: GestionPedidos(gateway),
          sucursalId: 1,
          negocio: const NegocioProducto(id: 1, nombre: 'Cerámica'),
          esPropietario: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Selecciona un producto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selecciona un producto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Taza'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), '1');
    await tester.pumpAndSettle();
    await elegirFechaEntrega(tester);
    await tester.ensureVisible(find.text('Continuar'));
    // Espera a que termine el desplazamiento por el foco del campo.
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Marco');
    await tester.enterText(find.byType(TextFormField).at(1), '5512345678');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continuar'));
    // Espera a que termine el desplazamiento por el foco del campo.
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '30');
    await tester.ensureVisible(find.text('Registrar pedido').last);
    // Espera a que termine el desplazamiento por el foco del campo.
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar pedido').last);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No hay un corte de caja abierto'),
      findsOneWidget,
    );
    expect(find.textContaining('anticipo 0'), findsOneWidget);
    expect(gateway.recibido, isNull);

    gateway.errorAlRegistrar = const ApiException(
      'Revisa los datos del formulario.',
      statusCode: 400,
      fieldErrors: {
        'productos[0].cantidad': 'La cantidad debe ser mayor a cero.',
      },
    );
    await tester.ensureVisible(find.text('Registrar pedido').last);
    // Espera a que termine el desplazamiento por el foco del campo.
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar pedido').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Cantidad del producto 1: La cantidad debe ser mayor a cero.'),
      findsOneWidget,
    );
    expect(find.text('Productos del pedido'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Quitar Taza'));
    await tester.tap(find.byTooltip('Quitar Taza'));
    await tester.pump();
    expect(
      find.text('Cantidad del producto 1: La cantidad debe ser mayor a cero.'),
      findsNothing,
    );
  });

  test('redondea el subtotal por producto como el backend', () {
    const producto = ProductoPedido(
      id: 9,
      nombre: 'Ejemplo',
      precio: 0.05,
      descuentos: [EscalonDescuento(cantidadMinima: 1, porcentaje: 10)],
    );
    expect(producto.subtotalEstimadoCentavos(1), BigInt.from(5));
    expect(producto.subtotalEstimadoCentavos(2), BigInt.from(9));
  });

  test('aplica solo el escalón en que cae la cantidad', () {
    const olla = ProductoPedido(
      id: 10,
      nombre: 'Olla',
      precio: 100,
      descuentos: [
        EscalonDescuento(cantidadMinima: 5, cantidadMaxima: 10, porcentaje: 5),
        EscalonDescuento(
          cantidadMinima: 11,
          cantidadMaxima: 20,
          porcentaje: 10,
        ),
        EscalonDescuento(cantidadMinima: 21, porcentaje: 15),
      ],
    );
    expect(olla.porcentajePara(4), isNull);
    expect(olla.porcentajePara(5), 5);
    expect(olla.porcentajePara(15), 10);
    expect(olla.porcentajePara(30), 15);
  });

  test('valida límites numéricos y nombres sin números', () {
    expect(PedidoInputFormatters.validarNombre('María O’Connor'), isNull);
    expect(PedidoInputFormatters.validarNombre('Ana123'), isNotNull);
    expect(PedidoInputFormatters.validarTelefono('5512345678'), isNull);
    expect(PedidoInputFormatters.validarTelefono('55 12345678'), isNotNull);
    expect(PedidoInputFormatters.validarCantidad('2147483648'), isNotNull);
    expect(PedidoInputFormatters.validarDinero('12,50'), isNull);
    expect(PedidoInputFormatters.validarDinero('12.345'), isNotNull);
  });
}

/// Elige hoy como fecha de entrega (campo obligatorio del primer paso).
Future<void> elegirFechaEntrega(WidgetTester tester) async {
  final campo = find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('pedido-fecha-entrega'),
  );
  await tester.ensureVisible(campo);
  await tester.pumpAndSettle();
  await tester.tap(campo);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Aceptar'));
  await tester.pumpAndSettle();
}
