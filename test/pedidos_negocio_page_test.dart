import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/features/notificaciones/application/contador_notificaciones.dart';
import 'package:punto_de_venta/features/pedidos/application/gestion_pedidos.dart';
import 'package:punto_de_venta/features/pedidos/application/ports/pedidos_gateway.dart';
import 'package:punto_de_venta/features/pedidos/domain/pedido.dart';
import 'package:punto_de_venta/features/pedidos/infrastructure/adapters/inbound/pedidos_negocio_page.dart';
import 'package:punto_de_venta/features/sucursal/application/ports/inbound/gestion_sucursales_use_case.dart';
import 'package:punto_de_venta/features/sucursal/domain/sucursal.dart';

class _IconoFalso implements IndicadorIcono {
  @override
  Future<void> actualizar(int cantidad) async {}
}

class _Sucursales extends Fake implements GestionSucursalesUseCase {
  _Sucursales(this.sucursales);
  final List<Sucursal> sucursales;

  @override
  Future<List<Sucursal>> listar(int negocioId) async => sucursales;
}

class _Pedidos extends Fake implements PedidosGateway {
  final consultadas = <int>[];

  @override
  Future<PaginaPedidos> listar(
    int sucursalId, {
    String? estado,
    String? busqueda,
    int pagina = 0,
  }) async {
    consultadas.add(sucursalId);
    return const PaginaPedidos(pedidos: [], pagina: 0, ultima: true, total: 0);
  }
}

void main() {
  late ApiClient api;
  late ContadorNotificaciones contador;

  setUp(() {
    api = ApiClient(
      baseUrl: 'http://localhost/',
      client: MockClient((_) async => throw StateError('Sin red en pruebas')),
    );
    contador = ContadorNotificaciones(api, _IconoFalso());
  });

  tearDown(() {
    contador.dispose();
    api.close();
  });

  Future<_Pedidos> abrir(WidgetTester tester, List<Sucursal> sucursales) async {
    tester.view.physicalSize = const Size(480, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pedidos = _Pedidos();
    await tester.pumpWidget(
      MaterialApp(
        home: PedidosNegocioPage(
          negocio: const NegocioSucursal(id: 1, nombre: 'Cerámica del centro'),
          sucursales: _Sucursales(sucursales),
          gestion: GestionPedidos(pedidos),
          contador: contador,
          onSesionExpirada: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    return pedidos;
  }

  testWidgets('pide elegir la sucursal y luego muestra sus pedidos', (
    tester,
  ) async {
    final pedidos = await abrir(tester, const [
      Sucursal(id: 3, negocioId: 1, nombre: 'Sucursal Norte'),
      Sucursal(id: 4, negocioId: 1, nombre: 'Sucursal Sur'),
    ]);
    expect(find.text('Cerámica del centro'), findsOneWidget);
    expect(find.text('Elige una sucursal'), findsOneWidget);
    expect(pedidos.consultadas, isEmpty);

    await tester.tap(find.text('Selecciona una sucursal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sucursal Sur').last);
    await tester.pumpAndSettle();

    expect(pedidos.consultadas, [4]);
    expect(find.text('Elige una sucursal'), findsNothing);
    expect(find.text('+ Nuevo pedido'), findsOneWidget);
    // Mismo encabezado: sigue el selector para cambiar de sucursal.
    expect(find.text('Sucursal Sur'), findsOneWidget);
  });

  testWidgets('con una sola sucursal entra directo a sus pedidos', (
    tester,
  ) async {
    final pedidos = await abrir(tester, const [
      Sucursal(id: 3, negocioId: 1, nombre: 'Sucursal Norte'),
    ]);
    expect(pedidos.consultadas, [3]);
    expect(find.text('+ Nuevo pedido'), findsOneWidget);
  });
}
