import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punto_de_venta/features/descuentos/application/ports/outbound/descuento_gateway.dart';
import 'package:punto_de_venta/features/descuentos/application/services/gestion_descuentos.dart';
import 'package:punto_de_venta/features/descuentos/domain/descuento.dart';
import 'package:punto_de_venta/features/productos/application/ports/outbound/existencias_gateway.dart';
import 'package:punto_de_venta/features/productos/application/ports/outbound/producto_gateway.dart';
import 'package:punto_de_venta/features/productos/application/services/gestion_productos.dart';
import 'package:punto_de_venta/features/productos/domain/producto.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_form_page.dart';

const _negocio = NegocioProducto(id: 7, nombre: 'Barro Centro');
const _sucursal = SucursalProducto(id: 10, nombre: 'Lindavista');

class _Productos implements ProductoGateway {
  DatosProducto? creado;
  int editados = 0;

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
    creado = datos;
    return Producto(
      id: 5,
      nombre: datos.nombre,
      precio: datos.precioNumero ?? 0,
      categoriaId: datos.categoriaId!,
    );
  }

  @override
  Future<Producto> editar(int id, DatosProducto datos) async {
    editados++;
    return Producto(
      id: id,
      nombre: datos.nombre,
      precio: datos.precioNumero ?? 0,
      categoriaId: datos.categoriaId!,
    );
  }

  @override
  Future<Producto> consultar(int id) async =>
      Producto(id: id, nombre: 'Olla', precio: 40, categoriaId: 1);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Descuentos en memoria que registran cada llamada.
class _Descuentos implements DescuentoGateway {
  _Descuentos([List<Descuento>? inicial]) : filas = [...?inicial];
  List<Descuento> filas;
  final llamadas = <String>[];
  int _siguiente = 100;

  /// Si es mayor que cero, falla la próxima asignación (y decrementa).
  int fallosDeAsignar = 0;

  void _reemplazar(Descuento d) =>
      filas = [for (final x in filas) x.id == d.id ? d : x];

  @override
  Future<List<Descuento>> listar(int negocioId) async => filas;

  @override
  Future<Descuento> crear(int negocioId, DatosDescuento datos) async {
    llamadas.add(
      'crear ${datos.nombre} ${datos.cantidadMinima} ${datos.porcentaje}',
    );
    final d = Descuento(
      id: _siguiente++,
      nombre: datos.nombre,
      cantidadMinima: datos.cantidadMinimaNumero!,
      porcentaje: datos.porcentajeNumero!,
      activo: true,
    );
    filas = [...filas, d];
    return d;
  }

  @override
  Future<Descuento> editar(int negocioId, int id, DatosDescuento datos) async {
    llamadas.add('editar $id ${datos.cantidadMinima} ${datos.porcentaje}');
    final actual = filas.firstWhere((d) => d.id == id);
    final d = Descuento(
      id: id,
      nombre: actual.nombre,
      cantidadMinima: datos.cantidadMinimaNumero!,
      cantidadMaxima: datos.cantidadMaximaNumero,
      porcentaje: datos.porcentajeNumero!,
      activo: actual.activo,
      productoIds: actual.productoIds,
    );
    _reemplazar(d);
    return d;
  }

  @override
  Future<void> eliminar(int negocioId, int id) async {
    llamadas.add('eliminar $id');
    filas = [
      for (final d in filas)
        if (d.id != id) d,
    ];
  }

  @override
  Future<Descuento> cambiarEstado(
    int negocioId,
    int id, {
    required bool activo,
  }) async {
    llamadas.add(activo ? 'activar $id' : 'desactivar $id');
    final a = filas.firstWhere((d) => d.id == id);
    final d = Descuento(
      id: id,
      nombre: a.nombre,
      cantidadMinima: a.cantidadMinima,
      cantidadMaxima: a.cantidadMaxima,
      porcentaje: a.porcentaje,
      activo: activo,
      productoIds: a.productoIds,
    );
    _reemplazar(d);
    return d;
  }

  @override
  Future<Descuento> asignar(
    int negocioId,
    int id,
    DestinoDescuento destino,
    int destinoId,
  ) async {
    llamadas.add('asignar $id a ${destino.name} $destinoId');
    if (fallosDeAsignar > 0) {
      fallosDeAsignar--;
      throw const DescuentoFailure('Sin conexión.');
    }
    final a = filas.firstWhere((d) => d.id == id);
    final d = Descuento(
      id: id,
      nombre: a.nombre,
      cantidadMinima: a.cantidadMinima,
      cantidadMaxima: a.cantidadMaxima,
      porcentaje: a.porcentaje,
      activo: a.activo,
      productoIds: [...a.productoIds, destinoId],
    );
    _reemplazar(d);
    return d;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

const _propioA = Descuento(
  id: 1,
  nombre: 'Olla · desde 2 piezas',
  cantidadMinima: 2,
  porcentaje: 10,
  activo: true,
  productoIds: [5],
);
const _propioB = Descuento(
  id: 2,
  nombre: 'Olla · desde 5 piezas',
  cantidadMinima: 5,
  porcentaje: 20,
  activo: true,
  productoIds: [5],
);
const _compartido = Descuento(
  id: 3,
  nombre: 'Mayoreo',
  cantidadMinima: 10,
  porcentaje: 5,
  activo: true,
  productoIds: [5, 6],
);

Future<void> _abrir(
  WidgetTester tester, {
  required _Productos productos,
  required _Descuentos descuentos,
  Producto? editar,
}) async {
  tester.view.physicalSize = const Size(420, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: ProductoFormPage(
        negocio: _negocio,
        gestion: GestionProductos(productos, const _SinExistencias()),
        descuentos: GestionDescuentos(descuentos),
        onSesionExpirada: () {},
        producto: editar,
        sucursal: editar == null ? _sucursal : null,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _llenarProducto(WidgetTester tester) async {
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

Future<void> _tocar(WidgetTester tester, String clave) async {
  final finder = find.byKey(ValueKey(clave));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _escribir(WidgetTester tester, String clave, String texto) async {
  final finder = find.byKey(ValueKey(clave));
  await tester.ensureVisible(finder);
  await tester.enterText(finder, texto);
}

const _producto = Producto(id: 5, nombre: 'Olla', precio: 40, categoriaId: 1);

void main() {
  group('registro', () {
    testWidgets('el descuento es opcional y así se indica', (tester) async {
      final productos = _Productos();
      final descuentos = _Descuentos();
      await _abrir(tester, productos: productos, descuentos: descuentos);

      expect(find.text('Descuento por cantidad'), findsOneWidget);
      expect(
        find.text('Agrega uno o más descuentos opcionales.'),
        findsOneWidget,
      );
      expect(find.text('+ Agregar descuento'), findsOneWidget);
      expect(
        find.textContaining('Es opcional: puedes omitirlo'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('producto-descuentos')), findsNothing);

      await _llenarProducto(tester);
      await _tocar(tester, 'producto-guardar');

      expect(productos.creado, isNotNull);
      expect(descuentos.llamadas, isEmpty);
    });

    testWidgets('permite agregar varios descuentos y quitar alguno', (
      tester,
    ) async {
      final productos = _Productos();
      final descuentos = _Descuentos();
      await _abrir(tester, productos: productos, descuentos: descuentos);
      await _llenarProducto(tester);

      for (var i = 0; i < 3; i++) {
        await _tocar(tester, 'producto-descuento-agregar');
      }
      expect(
        find.text('Puedes agregar más descuentos si lo deseas.'),
        findsOneWidget,
      );
      expect(find.text('A partir de (piezas)'), findsNWidgets(3));
      // Sin interruptor de activo por descuento al registrar.
      expect(
        find.byKey(const ValueKey('producto-descuento-activo-0')),
        findsNothing,
      );

      await _escribir(tester, 'producto-descuento-minimo-0', '2');
      await _escribir(tester, 'producto-descuento-porcentaje-0', '10');
      await _escribir(tester, 'producto-descuento-minimo-1', '9');
      await _escribir(tester, 'producto-descuento-porcentaje-1', '99');
      await _escribir(tester, 'producto-descuento-minimo-2', '5');
      await _escribir(tester, 'producto-descuento-porcentaje-2', '20');
      // La fila 1 era un error de captura: se quita antes de guardar.
      await _tocar(tester, 'producto-descuento-quitar-1');
      expect(find.text('A partir de (piezas)'), findsNWidgets(2));

      await _tocar(tester, 'producto-guardar');

      expect(descuentos.llamadas, [
        'crear Olla · desde 2 piezas 2 10',
        'asignar 100 a producto 5',
        'crear Olla · desde 5 piezas 5 20',
        'asignar 101 a producto 5',
      ]);
    });

    testWidgets(
      'no guarda el producto si un descuento es inválido o repetido',
      (tester) async {
        final productos = _Productos();
        final descuentos = _Descuentos();
        await _abrir(tester, productos: productos, descuentos: descuentos);
        await _llenarProducto(tester);
        await _tocar(tester, 'producto-descuento-agregar');
        await _tocar(tester, 'producto-descuento-agregar');
        await _escribir(tester, 'producto-descuento-minimo-0', '3');
        await _escribir(tester, 'producto-descuento-porcentaje-0', '10');
        await _escribir(tester, 'producto-descuento-minimo-1', '3');
        await _escribir(tester, 'producto-descuento-porcentaje-1', '150');

        await _tocar(tester, 'producto-guardar');

        expect(productos.creado, isNull);
        expect(descuentos.llamadas, isEmpty);
        expect(
          find.text('Ya hay un descuento desde 3 piezas.'),
          findsOneWidget,
        );
        expect(
          find.text('Usa un valor mayor que 0 y hasta 100.'),
          findsOneWidget,
        );
      },
    );
  });

  group('edición', () {
    testWidgets('muestra los descuentos propios y avisa de los compartidos', (
      tester,
    ) async {
      await _abrir(
        tester,
        productos: _Productos(),
        descuentos: _Descuentos([_propioA, _propioB, _compartido]),
        editar: _producto,
      );

      expect(
        find.text('Puedes agregar uno o más descuentos opcionales.'),
        findsOneWidget,
      );
      expect(find.text('A partir de (piezas)'), findsNWidgets(2));
      expect(find.widgetWithText(TextField, '2'), findsOneWidget);
      expect(find.widgetWithText(TextField, '20'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('producto-descuento-activo-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('producto-descuento-activo-1')),
        findsOneWidget,
      );
      // Al editar no se ofrece crear más productos.
      expect(find.byKey(const ValueKey('producto-crear-mas')), findsNothing);
      expect(
        find.textContaining('también recibe 1 descuento compartido'),
        findsOneWidget,
      );
    });

    testWidgets('desactiva, modifica y elimina al guardar', (tester) async {
      final productos = _Productos();
      final descuentos = _Descuentos([_propioA, _propioB, _compartido]);
      await _abrir(
        tester,
        productos: productos,
        descuentos: descuentos,
        editar: _producto,
      );

      await _tocar(tester, 'producto-descuento-activo-0');
      expect(
        find.textContaining('Descuento desactivado: no se aplica'),
        findsOneWidget,
      );
      await _escribir(tester, 'producto-descuento-porcentaje-0', '12');
      await _tocar(tester, 'producto-descuento-quitar-1');
      expect(
        find.text(
          'Los descuentos que quitaste se eliminarán al guardar los cambios.',
        ),
        findsOneWidget,
      );
      // Nada se elimina hasta guardar.
      expect(descuentos.llamadas, isEmpty);

      await _tocar(tester, 'producto-guardar');

      expect(productos.editados, 1);
      expect(descuentos.llamadas, [
        'eliminar 2',
        'editar 1 2 12',
        'desactivar 1',
      ]);
      // El descuento compartido no se toca.
      expect(descuentos.filas.any((d) => d.id == 3), isTrue);
    });

    testWidgets('agrega un descuento nuevo a un producto sin descuentos', (
      tester,
    ) async {
      final descuentos = _Descuentos();
      await _abrir(
        tester,
        productos: _Productos(),
        descuentos: descuentos,
        editar: _producto,
      );

      await _tocar(tester, 'producto-descuento-agregar');
      await _escribir(tester, 'producto-descuento-minimo-0', '6');
      await _escribir(tester, 'producto-descuento-porcentaje-0', '8');
      await _tocar(tester, 'producto-guardar');

      expect(descuentos.llamadas, [
        'crear Olla · desde 6 piezas 6 8',
        'asignar 100 a producto 5',
      ]);
    });
  });

  group('GestionDescuentos.guardarDeProducto', () {
    test(
      'un reintento tras un fallo parcial no duplica lo ya creado',
      () async {
        final gateway = _Descuentos()..fallosDeAsignar = 1;
        final gestion = GestionDescuentos(gateway);
        final lineas = [
          LineaDescuento(cantidadMinima: '2', porcentaje: '10'),
          LineaDescuento(cantidadMinima: '5', porcentaje: '20'),
        ];

        await expectLater(
          gestion.guardarDeProducto(7, 5, 'Olla', lineas, <int>{}),
          throwsA(isA<DescuentoFailure>()),
        );
        // Se creó la primera pero no quedó asignada.
        expect(gateway.filas, hasLength(1));
        expect(lineas.first.id, 100);

        await gestion.guardarDeProducto(7, 5, 'Olla', lineas, <int>{});

        expect(gateway.filas, hasLength(2));
        expect(gateway.filas.every((d) => d.productoIds.contains(5)), isTrue);
      },
    );

    test('rechaza líneas inválidas sin llamar al servidor', () async {
      final gateway = _Descuentos();
      final gestion = GestionDescuentos(gateway);

      await expectLater(
        gestion.guardarDeProducto(7, 5, 'Olla', [
          LineaDescuento(cantidadMinima: '0', porcentaje: '10'),
        ], <int>{}),
        throwsA(isA<DescuentoFailure>()),
      );
      expect(gateway.llamadas, isEmpty);
    });

    test('delProducto separa propios de compartidos', () async {
      final gestion = GestionDescuentos(_Descuentos([_propioA, _compartido]));

      final r = await gestion.delProducto(7, 5);

      expect(r.propios.single.id, 1);
      expect(r.compartidos, 1);
    });
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
