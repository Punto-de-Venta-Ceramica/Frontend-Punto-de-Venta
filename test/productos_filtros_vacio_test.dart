import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart'
    as mui
    show DefaultMaterialLocalizations;
import 'package:punto_de_venta/features/productos/application/ports/inbound/gestion_productos_use_case.dart';
import 'package:punto_de_venta/features/productos/domain/producto.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/productos_page.dart';

/// Catálogo con un producto que solo aparece sin búsqueda ni filtros (salvo
/// [catalogoVacio]). Con [retener] la respuesta espera, para revisar la
/// pantalla mientras la consulta está en curso.
class _Gestion implements GestionProductosUseCase {
  _Gestion({this.catalogoVacio = false});
  final bool catalogoVacio;
  Completer<void>? retener;

  @override
  Future<PaginaProductos> listar(
    int negocioId, {
    int pagina = 0,
    FiltroProductos filtro = const FiltroProductos(),
  }) async {
    await retener?.future;
    final sinFiltros =
        filtro.buscar.isEmpty &&
        filtro.areaId == null &&
        filtro.categoriaId == null &&
        filtro.precioMinimo == null &&
        filtro.precioMaximo == null;
    final productos = !catalogoVacio && sinFiltros
        ? const [Producto(id: 1, nombre: 'Jarrón', precio: 80)]
        : const <Producto>[];
    return PaginaProductos(
      productos: productos,
      pagina: 0,
      ultima: true,
      total: productos.length,
    );
  }

  @override
  Future<List<AreaProducto>> areas(int negocioId) async => const [
    AreaProducto(id: 1, nombre: 'Cocina'),
  ];

  @override
  Future<List<CategoriaProducto>> categorias(int negocioId) async => const [
    CategoriaProducto(id: 1, areaId: 1, nombre: 'Vajillas'),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

const _textoVacio = 'Agrega tu primer producto';
final _sinResultados = find.byKey(const ValueKey('productos-sin-resultados'));
final _buscador = find.byKey(const ValueKey('producto-busqueda'));

Future<_Gestion> _abrir(
  WidgetTester tester, {
  bool catalogoVacio = false,
}) async {
  tester.view.physicalSize = const Size(420, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final gestion = _Gestion(catalogoVacio: catalogoVacio);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [mui.DefaultMaterialLocalizations.delegate],
      home: ProductosPage(
        gestion: gestion,
        negocioInicial: const NegocioProducto(id: 1, nombre: 'Santo Barro'),
        sucursal: const SucursalProducto(id: 10, nombre: 'Lindavista'),
        soloLectura: true,
        puedeRegistrar: true,
        onSesionExpirada: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
  return gestion;
}

/// Revisa la pantalla en cada cuadro mientras la consulta sigue en curso.
Future<void> _sinPantallaVacia(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(_textoVacio), findsNothing);
    expect(_buscador, findsOneWidget);
  }
}

void main() {
  testWidgets('borrar una búsqueda sin resultados no muestra el catálogo vacío', (
    tester,
  ) async {
    final gestion = await _abrir(tester);
    await tester.enterText(_buscador, 'zzz');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(_sinResultados, findsOneWidget);
    expect(find.text(_textoVacio), findsNothing);

    // Se borra la búsqueda: la lista sigue vacía hasta que responde el servidor.
    gestion.retener = Completer();
    await tester.enterText(_buscador, '');
    await _sinPantallaVacia(tester);

    gestion.retener!.complete();
    gestion.retener = null;
    await tester.pumpAndSettle();
    expect(find.text('Jarrón'), findsOneWidget);
  });

  testWidgets('quitar un filtro de área sin resultados no muestra el vacío', (
    tester,
  ) async {
    final gestion = await _abrir(tester);
    await tester.tap(find.text('Todas las áreas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cocina').last, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_sinResultados, findsOneWidget);

    gestion.retener = Completer();
    await tester.tap(find.byKey(const ValueKey('limpiar-filtros')));
    await _sinPantallaVacia(tester);

    gestion.retener!.complete();
    gestion.retener = null;
    await tester.pumpAndSettle();
    expect(find.text('Jarrón'), findsOneWidget);
  });

  testWidgets('borrar un precio sin resultados no muestra el vacío', (
    tester,
  ) async {
    final gestion = await _abrir(tester);
    final minimo = find.byKey(const ValueKey('precio-min'));
    await tester.enterText(minimo, '1000');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(_sinResultados, findsOneWidget);

    gestion.retener = Completer();
    await tester.enterText(minimo, '');
    await _sinPantallaVacia(tester);

    gestion.retener!.complete();
    gestion.retener = null;
    await tester.pumpAndSettle();
    expect(find.text('Jarrón'), findsOneWidget);
  });

  testWidgets('un catálogo realmente vacío sí muestra la pantalla inicial', (
    tester,
  ) async {
    await _abrir(tester, catalogoVacio: true);
    expect(find.text(_textoVacio), findsOneWidget);
    expect(_sinResultados, findsNothing);
  });
}
