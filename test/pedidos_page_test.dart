import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/pedidos/application/gestion_pedidos.dart';
import 'package:punto_de_venta/features/pedidos/application/ports/pedidos_gateway.dart';
import 'package:punto_de_venta/features/pedidos/domain/pedido.dart';
import 'package:punto_de_venta/features/pedidos/infrastructure/adapters/inbound/pedido_input_formatters.dart';
import 'package:punto_de_venta/features/pedidos/infrastructure/adapters/inbound/registrar_pedido_page.dart';
import 'package:punto_de_venta/features/productos/domain/producto.dart';

class _Gateway implements PedidosGateway {
  DatosPedido? recibido;
  ApiException? errorAlRegistrar;
  @override
  Future<List<AvisoPedido>> notificaciones() async => [];
  @override
  Future<void> marcarLeida(int id) async {}
  @override
  Future<List<ProductoPedido>> productos(int id) async => [
    const ProductoPedido(
      id: 3,
      nombre: 'Taza',
      precio: 100,
      cantidadMinima: 2,
      porcentajeDescuento: 10,
    ),
    const ProductoPedido(id: 4, nombre: 'Plato', precio: 50),
    const ProductoPedido(id: 5, nombre: 'Ánfora', precio: 80),
  ];
  @override
  Future<void> registrar(DatosPedido datos) async {
    if (errorAlRegistrar != null) throw errorAlRegistrar!;
    recibido = datos;
  }

  @override
  Future<List<Pedido>> listar(int id) async => [];
  @override
  Future<void> pagar(int id, double monto, String metodo) async {}
  @override
  Future<void> cambiarEstado(int id, String estado) async {}
  @override
  Future<void> cancelar(int id) async {}
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
    expect(find.byTooltip('Inicio'), findsOneWidget);
    expect(find.byTooltip('Pedidos'), findsOneWidget);
    expect(find.byTooltip('Caja'), findsOneWidget);
    expect(find.byTooltip('Inventario'), findsOneWidget);
    expect(find.byTooltip('Más'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) => widget is IconButton && widget.tooltip == 'Pedidos',
            ),
          )
          .isSelected,
      isTrue,
    );
    await tester.enterText(
      find.byType(TextFormField).first,
      '  Pedido   de 5 piezas  ',
    );
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
    await tester.ensureVisible(find.text('Agregar producto'));
    await tester.tap(find.text('Agregar producto'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aplica descuento de mayoreo'), findsOneWidget);
    expect(find.text('Selecciona un producto'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller!
          .text,
      '1',
    );
    await tester.ensureVisible(find.text('Selecciona un producto'));
    await tester.tap(find.text('Selecciona un producto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plato').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continuar'));
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), '  An4a   María  ');
    await tester.enterText(campos.at(1), '123');
    await tester.ensureVisible(find.text('Continuar'));
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
    await tester.ensureVisible(find.text('Continuar'));
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
    await tester.tap(find.text('Registrar pedido').last);
    await tester.pumpAndSettle();
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
        home: RegistrarPedidoPage(
          gestion: GestionPedidos(_Gateway()),
          sucursalId: 1,
          negocio: const NegocioProducto(id: 1, nombre: 'Cerámica'),
          esPropietario: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selecciona un producto'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Plato')).dy,
      lessThan(tester.getTopLeft(find.text('Taza')).dy),
    );
    final buscador = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
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
    expect(find.textContaining('Taza ·'), findsOneWidget);
    await tester.tap(find.byTooltip('Quitar selección de producto'));
    await tester.pumpAndSettle();
    expect(find.text('Selecciona un producto'), findsOneWidget);
    expect(find.textContaining('Taza ·'), findsNothing);
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
        home: RegistrarPedidoPage(
          gestion: GestionPedidos(gateway),
          sucursalId: 1,
          negocio: const NegocioProducto(id: 1, nombre: 'Cerámica'),
          esPropietario: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selecciona un producto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Taza'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continuar'));
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'Ana');
    await tester.enterText(campos.at(1), '5512345678');
    await tester.ensureVisible(find.text('Continuar'));
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Registrar pedido').last);
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
        home: RegistrarPedidoPage(
          gestion: GestionPedidos(gateway),
          sucursalId: 1,
          negocio: const NegocioProducto(id: 1, nombre: 'Cerámica'),
          esPropietario: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selecciona un producto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Taza'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continuar'));
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Marco');
    await tester.enterText(find.byType(TextFormField).at(1), '5512345678');
    await tester.ensureVisible(find.text('Continuar'));
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '30');
    await tester.ensureVisible(find.text('Registrar pedido').last);
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
    await tester.tap(find.text('Registrar pedido').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Cantidad del producto 1: La cantidad debe ser mayor a cero.'),
      findsOneWidget,
    );
    expect(find.text('Agregar producto'), findsOneWidget);
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
      cantidadMinima: 1,
      porcentajeDescuento: 10,
    );
    expect(producto.subtotalEstimadoCentavos(1), BigInt.from(5));
    expect(producto.subtotalEstimadoCentavos(2), BigInt.from(9));
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
