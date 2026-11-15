import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart'
    as mui
    show DefaultMaterialLocalizations;
import 'package:punto_de_venta/features/productos/application/ports/inbound/gestion_productos_use_case.dart';
import 'package:punto_de_venta/features/productos/domain/producto.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/productos_page.dart';

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

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<void> _abrir(WidgetTester tester, {required bool puedeRegistrar}) async {
  tester.view.physicalSize = const Size(420, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [mui.DefaultMaterialLocalizations.delegate],
      home: ProductosPage(
        gestion: _Gestion(),
        negocioInicial: const NegocioProducto(id: 1, nombre: 'Santo Barro'),
        sucursal: const SucursalProducto(id: 10, nombre: 'Lindavista'),
        soloLectura: true,
        puedeRegistrar: puedeRegistrar,
        onSesionExpirada: () {},
      ),
    ),
  );
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
