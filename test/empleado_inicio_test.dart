import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punto_de_venta/features/empleados/domain/sucursal_asignada.dart';
import 'package:punto_de_venta/features/empleados/infrastructure/adapters/inbound/flutter/empleado_inicio_page.dart';
import 'package:punto_de_venta/features/sucursal/infrastructure/adapters/inbound/flutter/sucursal_widgets.dart';

const _centro = SucursalAsignada(
  sucursalId: 1,
  sucursal: 'Sucursal Centro',
  negocioId: 9,
  negocio: 'Negocio',
);
const _norte = SucursalAsignada(
  sucursalId: 2,
  sucursal: 'Sucursal Norte',
  negocioId: 9,
  negocio: 'Negocio',
);

Widget _pagina(List<SucursalAsignada> sucursales, {VoidCallback? salir}) =>
    MaterialApp(
      home: EmpleadoInicioPage(
        cargarSucursales: () async => sucursales,
        construirPedidos: (s) => Center(child: Text('PEDIDOS ${s.sucursal}')),
        construirCaja: (s) => Center(child: Text('CAJA ${s.sucursal}')),
        construirInventario: (s) =>
            Center(child: Text('INVENTARIO ${s.sucursal}')),
        onCerrarSesion: salir ?? () {},
      ),
    );

Finder _nav(String rotulo) => find.descendant(
  of: find.byType(SucursalNavegacion),
  matching: find.text(rotulo),
);

void main() {
  testWidgets('abre en Caja y la barra solo tiene 3 iconos', (tester) async {
    await tester.pumpWidget(_pagina([_centro]));
    await tester.pumpAndSettle();

    expect(find.text('CAJA Sucursal Centro'), findsOneWidget);
    expect(_nav('Pedidos'), findsOneWidget);
    expect(_nav('Caja'), findsOneWidget);
    expect(_nav('Productos'), findsOneWidget);
    expect(_nav('Inicio'), findsNothing);
    expect(_nav('Reportes'), findsNothing);

    // Pedidos a la izquierda de Caja e Inventario a la derecha.
    final pedidos = tester.getCenter(_nav('Pedidos')).dx;
    final caja = tester.getCenter(_nav('Caja')).dx;
    final inventario = tester.getCenter(_nav('Productos')).dx;
    expect(pedidos, lessThan(caja));
    expect(caja, lessThan(inventario));
  });

  testWidgets('cambia entre Pedidos, Caja e Inventario', (tester) async {
    await tester.pumpWidget(_pagina([_centro]));
    await tester.pumpAndSettle();

    await tester.tap(_nav('Pedidos'));
    await tester.pumpAndSettle();
    expect(find.text('PEDIDOS Sucursal Centro'), findsOneWidget);

    await tester.tap(_nav('Productos'));
    await tester.pumpAndSettle();
    expect(find.text('INVENTARIO Sucursal Centro'), findsOneWidget);

    await tester.tap(_nav('Caja'));
    await tester.pumpAndSettle();
    expect(find.text('CAJA Sucursal Centro'), findsOneWidget);
  });

  testWidgets('con varias sucursales pide elegir y luego muestra Caja', (
    tester,
  ) async {
    await tester.pumpWidget(_pagina([_centro, _norte]));
    await tester.pumpAndSettle();

    expect(find.text('¿En qué sucursal trabajas hoy?'), findsOneWidget);
    await tester.tap(find.text('Sucursal Norte'));
    await tester.pumpAndSettle();

    expect(find.text('CAJA Sucursal Norte'), findsOneWidget);
  });

  testWidgets('sin sucursal asignada avisa y permite cerrar sesión', (
    tester,
  ) async {
    var cerro = false;
    await tester.pumpWidget(_pagina([], salir: () => cerro = true));
    await tester.pumpAndSettle();

    expect(
      find.text('No tienes una sucursal asignada. Contacta al propietario.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cerrar sesión'));
    expect(cerro, isTrue);
  });
}
