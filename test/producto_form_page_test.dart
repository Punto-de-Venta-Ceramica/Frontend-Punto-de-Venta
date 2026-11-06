import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punto_de_venta/features/productos/application/ports/outbound/producto_gateway.dart';
import 'package:punto_de_venta/features/productos/application/services/gestion_productos.dart';
import 'package:punto_de_venta/features/productos/domain/producto.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_form_page.dart';

class _Gateway implements ProductoGateway {
  DatosProducto? creado;

  @override
  Future<List<AreaProducto>> areas(int negocioId) async => const [
    AreaProducto(id: 1, nombre: 'Cocina'),
  ];

  @override
  Future<List<CategoriaProducto>> categorias(int negocioId) async => const [
    CategoriaProducto(id: 1, areaId: 1, nombre: 'Vajillas'),
  ];

  @override
  Future<List<SucursalProducto>> sucursales(int negocioId) async => const [
    SucursalProducto(id: 10, nombre: 'Lindavista'),
    SucursalProducto(id: 11, nombre: '15 Septiembre'),
  ];

  @override
  Future<Producto> crear(int negocioId, DatosProducto datos) async {
    creado = datos;
    return Producto(
      id: 1,
      nombre: datos.nombre,
      precio: datos.precioNumero ?? 0,
      categoriaId: datos.categoriaId!,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<_Gateway> _abrir(
  WidgetTester tester, {
  SucursalProducto? sucursal,
}) async {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final gateway = _Gateway();
  await tester.pumpWidget(
    MaterialApp(
      home: ProductoFormPage(
        negocio: const NegocioProducto(id: 1, nombre: 'Barro Centro'),
        gestion: GestionProductos(gateway),
        onSesionExpirada: () {},
        sucursal: sucursal,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return gateway;
}

Future<void> _llenarDatos(WidgetTester tester) async {
  await tester.enterText(find.byKey(const ValueKey('producto-nombre')), 'Olla');
  await tester.enterText(find.byKey(const ValueKey('producto-precio')), '40');
  await tester.tap(find.byKey(const ValueKey('producto-area')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cocina').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('producto-categoria')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Vajillas').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'en una sucursal el registro es una sola pantalla con existencia',
    (tester) async {
      final gateway = await _abrir(
        tester,
        sucursal: const SucursalProducto(id: 10, nombre: 'Lindavista'),
      );
      expect(find.text('1. Datos del producto'), findsNothing);
      expect(find.text('Existencia'), findsOneWidget);
      expect(find.textContaining('una sola sucursal'), findsNothing);

      await _llenarDatos(tester);
      await tester.enterText(
        find.byKey(const ValueKey('producto-existencia-10')),
        '7',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('producto-guardar')),
      );
      await tester.tap(find.byKey(const ValueKey('producto-guardar')));
      await tester.pumpAndSettle();

      expect(gateway.creado, isNotNull);
      expect(gateway.creado!.existencias.single.sucursalId, 10);
      expect(gateway.creado!.existencias.single.existencia, 7);
    },
  );

  testWidgets('en el negocio el paso 2 guía la selección de sucursales', (
    tester,
  ) async {
    await _abrir(tester);
    await _llenarDatos(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('producto-guardar')));
    await tester.tap(find.byKey(const ValueKey('producto-guardar')));
    await tester.pumpAndSettle();

    expect(
      find.text('Selecciona la sucursal que quieres agregar a este producto.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Selecciona la sucursal para agregar'),
      findsNothing,
    );
    // Sin seleccionar no hay campo de existencia; al marcarla aparece.
    expect(find.byKey(const ValueKey('producto-existencia-10')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('producto-sucursal-10')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('producto-existencia-10')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('producto-existencia-11')), findsNothing);
  });
}
