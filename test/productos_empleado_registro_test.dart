import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart'
    as mui
    show DefaultMaterialLocalizations;
import 'package:punto_de_venta/features/productos/application/ports/inbound/gestion_productos_use_case.dart';
import 'package:punto_de_venta/features/productos/domain/producto.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/productos_page.dart';

import 'notificaciones_test_utils.dart';

/// Gestión mínima: un producto en el listado y la clasificación de la sucursal.
class _Gestion implements GestionProductosUseCase {
  @override
  Future<PaginaProductos> listar(
    int negocioId, {
    int pagina = 0,
    FiltroProductos filtro = const FiltroProductos(),
  }) async => const PaginaProductos(
    productos: [Producto(id: 1, nombre: 'Jarrón', precio: 80)],
    pagina: 0,
    ultima: true,
    total: 1,
  );

  @override
  Future<List<AreaProducto>> areas(int negocioId) async => const [
    AreaProducto(id: 1, nombre: 'Cocina'),
  ];

  @override
  Future<List<CategoriaProducto>> categorias(int negocioId) async => const [
    CategoriaProducto(id: 1, areaId: 1, nombre: 'Vajillas'),
  ];

  @override
  Producto? detalleGuardado(int productoId) => null;

  @override
  Future<Producto> consultar(int productoId, int negocioId) async =>
      const Producto(
        id: 1,
        nombre: 'Jarrón',
        precio: 80,
        existencias: [
          ExistenciaSucursal(
            inventarioId: 5,
            sucursalId: 10,
            sucursalNombre: 'Lindavista',
            existencia: 7,
          ),
        ],
      );

  /// Entradas pedidas: (inventarioId, cantidad).
  final entradas = <(int, int)>[];

  @override
  Future<int> agregarExistencia(int inventarioId, int cantidad) async {
    entradas.add((inventarioId, cantidad));
    return 7 + cantidad;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<_Gestion> _abrir(
  WidgetTester tester, {
  required bool puedeRegistrar,
}) async {
  tester.view.physicalSize = const Size(420, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  final gestion = _Gestion();
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [mui.DefaultMaterialLocalizations.delegate],
      home: ProductosPage(
        gestion: gestion,
        negocioInicial: const NegocioProducto(id: 1, nombre: 'Santo Barro'),
        sucursal: const SucursalProducto(id: 10, nombre: 'Lindavista'),
        soloLectura: true,
        puedeRegistrar: puedeRegistrar,
        onSesionExpirada: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
  return gestion;
}

/// Abre el detalle del jarrón y escribe cuántas piezas agregar.
Future<void> _pedirEntrada(WidgetTester tester, String cantidad) async {
  await tester.tap(find.text('Jarrón'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('existencia-agregar-5')));
  await tester.pumpAndSettle();
  expect(find.text('Agregar'), findsNothing, reason: 'sin opción de quitar');
  expect(find.text('Quitar'), findsNothing);
  await tester.enterText(
    find.byKey(const ValueKey('existencia-cantidad')),
    cantidad,
  );
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('el empleado con permiso ve el botón de registrar', (
    tester,
  ) async {
    await _abrir(tester, puedeRegistrar: true);

    expect(find.text('+ Registrar producto'), findsOneWidget);
    expect(find.text('Jarrón'), findsOneWidget);
  });

  testWidgets('sin permiso la vista sigue siendo solo de lectura', (
    tester,
  ) async {
    await _abrir(tester, puedeRegistrar: false);

    expect(find.text('+ Registrar producto'), findsNothing);
    expect(find.text('Jarrón'), findsOneWidget);
  });

  testWidgets('el empleado ve la existencia pero no puede ajustarla', (
    tester,
  ) async {
    await _abrir(tester, puedeRegistrar: true);
    await tester.tap(find.text('Jarrón'));
    await tester.pumpAndSettle();

    expect(find.text('Existencia en Lindavista'), findsOneWidget);
    expect(find.text('7 piezas'), findsWidgets);
    expect(find.text('Ajustar cantidad'), findsNothing);
    expect(find.byTooltip('Agregar 1 pieza'), findsNothing);
    expect(find.byTooltip('Quitar 1 pieza'), findsNothing);
    expect(find.text('Agregar existencias'), findsOneWidget);
  });

  testWidgetsConNotificaciones(
    'el empleado agrega piezas solo después de confirmar',
    (tester) async {
      final gestion = await _abrir(tester, puedeRegistrar: false);
      await _pedirEntrada(tester, '5');

      expect(find.text('¿Agregar 5 piezas?'), findsOneWidget);
      expect(find.text('12 piezas'), findsOneWidget);
      expect(gestion.entradas, isEmpty);

      await tester.tap(
        find.byKey(const ValueKey('existencia-confirmar-agregar')),
      );
      await tester.pumpAndSettle();

      expect(gestion.entradas, [(5, 5)]);
      expect(find.text('12 piezas'), findsWidgets);
    },
  );

  testWidgetsConNotificaciones('si el empleado cancela no se agrega nada', (
    tester,
  ) async {
    final gestion = await _abrir(tester, puedeRegistrar: false);
    await _pedirEntrada(tester, '3');

    await tester.tap(find.text('Cancelar').last);
    await tester.pumpAndSettle();

    expect(gestion.entradas, isEmpty);
    expect(find.text('7 piezas'), findsWidgets);
  });

  testWidgets(
    'el empleado registra en su sucursal: sin elegir sucursal ni descuentos',
    (tester) async {
      await _abrir(tester, puedeRegistrar: true);

      await tester.tap(find.text('+ Registrar producto'));
      await tester.pumpAndSettle();

      expect(find.text('Registrar producto'), findsWidgets);
      expect(find.text('Agrega un producto a Lindavista.'), findsOneWidget);
      expect(find.text('Existencia'), findsOneWidget);
      expect(find.text('Descuento por cantidad'), findsNothing);
      expect(find.text('2. Sucursales'), findsNothing);
    },
  );
}
