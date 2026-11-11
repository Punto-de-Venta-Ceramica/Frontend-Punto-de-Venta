import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punto_de_venta/features/productos/application/ports/outbound/existencias_gateway.dart';
import 'package:punto_de_venta/features/productos/application/ports/outbound/producto_gateway.dart';
import 'package:punto_de_venta/features/productos/application/services/gestion_productos.dart';
import 'package:punto_de_venta/features/productos/domain/producto.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_form_page.dart';

const _negocio = NegocioProducto(id: 7, nombre: 'Barro Centro');
const _sucursal = SucursalProducto(id: 10, nombre: 'Lindavista');

class _Productos implements ProductoGateway {
  final creados = <DatosProducto>[];

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
    _sucursal,
  ];

  @override
  Future<Producto> crear(DatosProducto datos) async {
    creados.add(datos);
    return Producto(
      id: creados.length,
      nombre: datos.nombre,
      precio: datos.precioNumero ?? 0,
      categoriaId: datos.categoriaId!,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Abre el formulario desde una pantalla de inicio y guarda lo que devuelve.
class _Anfitrion {
  Producto? resultado;
  bool cerrado = false;
  int? registrados;
}

Future<(_Productos, _Anfitrion)> _abrir(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final productos = _Productos();
  final anfitrion = _Anfitrion();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                anfitrion.resultado = await Navigator.of(context)
                    .push<Producto>(
                      MaterialPageRoute(
                        builder: (_) => ProductoFormPage(
                          negocio: _negocio,
                          gestion: GestionProductos(
                            productos,
                            const _SinExistencias(),
                          ),
                          onSesionExpirada: () {},
                          sucursal: _sucursal,
                          onRegistrados: (n) => anfitrion.registrados = n,
                        ),
                      ),
                    );
                anfitrion.cerrado = true;
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return (productos, anfitrion);
}

Future<void> _tocar(WidgetTester tester, String clave) async {
  final finder = find.byKey(ValueKey(clave));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _elegirClasificacion(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('producto-area')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cocina').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('producto-categoria')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Vajillas').last);
  await tester.pumpAndSettle();
}

Future<void> _datos(WidgetTester tester, String nombre, String precio) async {
  await tester.enterText(find.byKey(const ValueKey('producto-nombre')), nombre);
  await tester.enterText(find.byKey(const ValueKey('producto-precio')), precio);
}

String _texto(WidgetTester tester, String clave) =>
    tester.widget<TextField>(find.byKey(ValueKey(clave))).controller!.text;

void main() {
  testWidgets('"Crear más productos" viene desactivado', (tester) async {
    await _abrir(tester);

    final interruptor = tester.widget<Switch>(
      find.byKey(const ValueKey('producto-crear-mas')),
    );
    expect(interruptor.value, isFalse);
    expect(find.text('Crear más productos'), findsOneWidget);
    expect(find.text('Registrar producto'), findsWidgets);
    expect(find.text('Registrar y crear otro'), findsNothing);
  });

  testWidgets('sin activarlo, registrar cierra el formulario como siempre', (
    tester,
  ) async {
    final (productos, anfitrion) = await _abrir(tester);
    await _elegirClasificacion(tester);
    await _datos(tester, 'Olla', '40');

    await _tocar(tester, 'producto-guardar');

    expect(productos.creados, hasLength(1));
    expect(anfitrion.cerrado, isTrue);
    expect(anfitrion.resultado?.nombre, 'Olla');
    expect(anfitrion.registrados, 1);
  });

  testWidgets('activado, cada registro deja un formulario nuevo', (
    tester,
  ) async {
    final (productos, anfitrion) = await _abrir(tester);
    await _elegirClasificacion(tester);
    await _tocar(tester, 'producto-crear-mas');
    expect(find.text('Registrar y crear otro'), findsOneWidget);

    await _datos(tester, 'Olla', '40');
    await _tocar(tester, 'producto-guardar');

    // El formulario sigue abierto y completamente en blanco, también área y categoría.
    expect(anfitrion.cerrado, isFalse);
    expect(productos.creados, hasLength(1));
    expect(_texto(tester, 'producto-nombre'), isEmpty);
    expect(_texto(tester, 'producto-precio'), isEmpty);
    expect(find.text('Cocina'), findsNothing);
    expect(find.text('Vajillas'), findsNothing);
    expect(
      find.textContaining('Producto «Olla» registrado correctamente'),
      findsOneWidget,
    );
    expect(find.text('Terminar (1 registrado)'), findsOneWidget);

    // Sin elegir área y categoría de nuevo no se puede registrar el siguiente.
    await _datos(tester, 'Jarra', '25');
    await _tocar(tester, 'producto-guardar');
    expect(productos.creados, hasLength(1));
    expect(find.text('Selecciona un área y una categoría.'), findsOneWidget);

    await _elegirClasificacion(tester);
    await _tocar(tester, 'producto-guardar');
    await _datos(tester, 'Plato', '15');
    await _elegirClasificacion(tester);
    await _tocar(tester, 'producto-guardar');

    expect(productos.creados.map((d) => d.nombre), ['Olla', 'Jarra', 'Plato']);
    expect(productos.creados.every((d) => d.categoriaId == 1), isTrue);
    expect(find.text('Terminar (3 registrados)'), findsOneWidget);
    expect(anfitrion.cerrado, isFalse);
  });

  testWidgets('Terminar cierra devolviendo el último y el total', (
    tester,
  ) async {
    final (_, anfitrion) = await _abrir(tester);
    await _elegirClasificacion(tester);
    await _tocar(tester, 'producto-crear-mas');
    await _datos(tester, 'Olla', '40');
    await _tocar(tester, 'producto-guardar');
    await _datos(tester, 'Jarra', '25');
    await _elegirClasificacion(tester);
    await _tocar(tester, 'producto-guardar');

    await tester.tap(find.text('Terminar (2 registrados)'));
    await tester.pumpAndSettle();

    expect(anfitrion.cerrado, isTrue);
    expect(anfitrion.resultado?.nombre, 'Jarra');
    expect(anfitrion.registrados, 2);
  });

  testWidgets('desactivarlo en el último registro termina el lote', (
    tester,
  ) async {
    final (productos, anfitrion) = await _abrir(tester);
    await _elegirClasificacion(tester);
    await _tocar(tester, 'producto-crear-mas');
    await _datos(tester, 'Olla', '40');
    await _tocar(tester, 'producto-guardar');

    await _tocar(tester, 'producto-crear-mas');
    await _datos(tester, 'Jarra', '25');
    await _elegirClasificacion(tester);
    await _tocar(tester, 'producto-guardar');

    expect(productos.creados, hasLength(2));
    expect(anfitrion.cerrado, isTrue);
    expect(anfitrion.resultado?.nombre, 'Jarra');
    expect(anfitrion.registrados, 2);
  });

  testWidgets('los datos inválidos no registran ni reinician el formulario', (
    tester,
  ) async {
    final (productos, anfitrion) = await _abrir(tester);
    await _elegirClasificacion(tester);
    await _tocar(tester, 'producto-crear-mas');
    await _datos(tester, 'Olla', '');

    await _tocar(tester, 'producto-guardar');

    expect(productos.creados, isEmpty);
    expect(anfitrion.cerrado, isFalse);
    expect(_texto(tester, 'producto-nombre'), 'Olla');
    expect(find.text('Ingresa un precio mayor que cero.'), findsOneWidget);
  });
}

class _SinExistencias implements ExistenciasGateway {
  const _SinExistencias();

  @override
  Future<List<ExistenciaSucursal>> porProducto(int productoId) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
