import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/features/descuentos/application/ports/outbound/descuento_gateway.dart';
import 'package:punto_de_venta/features/descuentos/application/services/gestion_descuentos.dart';
import 'package:punto_de_venta/features/descuentos/domain/descuento.dart';
import 'package:punto_de_venta/features/descuentos/infrastructure/adapters/inbound/flutter/descuento_detalle_page.dart';
import 'package:punto_de_venta/features/descuentos/infrastructure/adapters/inbound/flutter/descuentos_page.dart';
import 'package:punto_de_venta/features/descuentos/infrastructure/adapters/outbound/http/http_descuento_gateway.dart';
import 'package:punto_de_venta/features/productos/domain/producto.dart';
import 'package:punto_de_venta/features/sucursal/application/ports/inbound/gestion_sucursales_use_case.dart';
import 'package:punto_de_venta/features/sucursal/domain/sucursal.dart';
import 'package:punto_de_venta/features/sucursal/infrastructure/adapters/inbound/flutter/sucursales_page.dart';

http.Response _json(String body, [int status = 200]) => http.Response(
  body,
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const _negocio = NegocioProducto(id: 7, nombre: 'Barro Centro');

const _mayoreo = Descuento(
  id: 1,
  nombre: 'Mayoreo',
  cantidadMinima: 10,
  cantidadMaxima: 20,
  porcentaje: 5,
  activo: true,
  productoIds: [3],
);
const _docena = Descuento(
  id: 2,
  nombre: 'Docena',
  cantidadMinima: 12,
  porcentaje: 10,
  activo: false,
);

const _catalogo = CatalogoDescuento(
  productos: [
    ElementoCatalogo(id: 3, nombre: 'Olla michoacana', contexto: 'Ollas'),
    ElementoCatalogo(id: 4, nombre: 'Jarra', contexto: 'Ollas'),
  ],
  categorias: [ElementoCatalogo(id: 10, nombre: 'Ollas', contexto: 'Cocina')],
  areas: [ElementoCatalogo(id: 20, nombre: 'Cocina')],
);

/// Gateway en memoria: aplica los cambios y registra las llamadas.
class _Gateway implements DescuentoGateway {
  _Gateway([List<Descuento>? inicial])
    : filas = [...(inicial ?? const <Descuento>[])];
  List<Descuento> filas;
  DescuentoFailure? fallo;
  final llamadas = <String>[];
  DatosDescuento? ultimosDatos;

  Descuento _con(
    Descuento d, {
    bool? activo,
    List<int>? productos,
    List<int>? categorias,
    List<int>? areas,
  }) => Descuento(
    id: d.id,
    nombre: d.nombre,
    cantidadMinima: d.cantidadMinima,
    cantidadMaxima: d.cantidadMaxima,
    porcentaje: d.porcentaje,
    activo: activo ?? d.activo,
    productoIds: productos ?? d.productoIds,
    categoriaIds: categorias ?? d.categoriaIds,
    areaIds: areas ?? d.areaIds,
  );

  void _reemplazar(Descuento nuevo) =>
      filas = [for (final d in filas) d.id == nuevo.id ? nuevo : d];

  @override
  Future<List<Descuento>> listar(int negocioId) async {
    if (fallo != null) throw fallo!;
    return filas;
  }

  @override
  Future<Descuento> crear(int negocioId, DatosDescuento datos) async {
    llamadas.add('crear');
    ultimosDatos = datos;
    final nuevo = Descuento(
      id: 99,
      nombre: datos.nombre.trim(),
      cantidadMinima: datos.cantidadMinimaNumero!,
      cantidadMaxima: datos.cantidadMaximaNumero,
      porcentaje: datos.porcentajeNumero!,
      activo: true,
    );
    filas = [...filas, nuevo];
    return nuevo;
  }

  @override
  Future<Descuento> editar(int negocioId, int id, DatosDescuento datos) async {
    llamadas.add('editar $id');
    ultimosDatos = datos;
    final actual = filas.firstWhere((d) => d.id == id);
    final nuevo = Descuento(
      id: id,
      nombre: datos.nombre.trim(),
      cantidadMinima: datos.cantidadMinimaNumero!,
      cantidadMaxima: datos.cantidadMaximaNumero,
      porcentaje: datos.porcentajeNumero!,
      activo: actual.activo,
      productoIds: actual.productoIds,
    );
    _reemplazar(nuevo);
    return nuevo;
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
    final nuevo = _con(filas.firstWhere((d) => d.id == id), activo: activo);
    _reemplazar(nuevo);
    return nuevo;
  }

  @override
  Future<CatalogoDescuento> catalogo(int negocioId) async => _catalogo;

  @override
  Future<Descuento> asignar(
    int negocioId,
    int id,
    DestinoDescuento destino,
    int destinoId,
  ) async {
    llamadas.add('asignar ${destino.name} $destinoId');
    final d = filas.firstWhere((x) => x.id == id);
    final nuevo = switch (destino) {
      DestinoDescuento.producto => _con(
        d,
        productos: [...d.productoIds, destinoId],
      ),
      DestinoDescuento.categoria => _con(
        d,
        categorias: [...d.categoriaIds, destinoId],
      ),
      DestinoDescuento.area => _con(d, areas: [...d.areaIds, destinoId]),
    };
    _reemplazar(nuevo);
    return nuevo;
  }

  @override
  Future<Descuento> quitar(
    int negocioId,
    int id,
    DestinoDescuento destino,
    int destinoId,
  ) async {
    llamadas.add('quitar ${destino.name} $destinoId');
    final d = filas.firstWhere((x) => x.id == id);
    final nuevo = switch (destino) {
      DestinoDescuento.producto => _con(
        d,
        productos: [
          for (final p in d.productoIds)
            if (p != destinoId) p,
        ],
      ),
      DestinoDescuento.categoria => _con(d, categorias: const []),
      DestinoDescuento.area => _con(d, areas: const []),
    };
    _reemplazar(nuevo);
    return nuevo;
  }
}

class _GestionSucursales implements GestionSucursalesUseCase {
  @override
  Future<List<Sucursal>> listar(int negocioId) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void _pantalla(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _abrirLista(WidgetTester tester, _Gateway gateway) async {
  _pantalla(tester);
  await tester.pumpWidget(
    MaterialApp(
      home: DescuentosPage(
        gestion: GestionDescuentos(gateway),
        negocio: _negocio,
        onSesionExpirada: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _escribir(WidgetTester tester, String clave, String texto) =>
    tester.enterText(find.byKey(ValueKey(clave)), texto);

Future<void> _tocar(WidgetTester tester, String clave) async {
  final finder = find.byKey(ValueKey(clave));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('DatosDescuento.validar', () {
    test('acepta datos correctos con y sin tope', () {
      expect(
        const DatosDescuento(
          nombre: 'Mayoreo',
          cantidadMinima: '10',
          cantidadMaxima: '20',
          porcentaje: '5.5',
        ).validar(),
        isEmpty,
      );
      expect(
        const DatosDescuento(
          nombre: 'Mayoreo',
          cantidadMinima: '10',
          porcentaje: '5,5',
        ).validar(),
        isEmpty,
      );
    });

    test('señala cada campo inválido', () {
      final errores = const DatosDescuento(
        nombre: ' ',
        cantidadMinima: '0',
        cantidadMaxima: '5',
        porcentaje: '150',
      ).validar();
      expect(errores.keys, containsAll(['nombre', 'cantidadMinima', 'porcentaje']));

      final tope = const DatosDescuento(
        nombre: 'X',
        cantidadMinima: '10',
        cantidadMaxima: '5',
        porcentaje: '10',
      ).validar();
      expect(tope.keys, ['cantidadMaxima']);

      expect(
        const DatosDescuento(
          nombre: 'X',
          cantidadMinima: '1',
          porcentaje: '10.123',
        ).validar().keys,
        ['porcentaje'],
      );
    });
  });

  group('HttpDescuentoGateway', () {
    late List<http.Request> peticiones;
    late HttpDescuentoGateway gateway;
    const respuesta =
        '{"id":1,"negocioId":7,"nombre":"Mayoreo","cantidadMinima":10,'
        '"cantidadMaxima":20,"porcentaje":5.5,"activo":true,'
        '"productoIds":[3,4],"categoriaIds":[2],"areaIds":[]}';

    setUp(() {
      peticiones = [];
      final api = ApiClient(
        baseUrl: 'https://example.test/backend',
        client: MockClient((r) async {
          peticiones.add(r);
          if (r.method == 'DELETE' && r.url.path.endsWith('/descuentos/1')) {
            return _json('', 204);
          }
          if (r.method == 'GET' && r.url.path.endsWith('/descuentos')) {
            return _json('[$respuesta]');
          }
          return _json(respuesta, r.method == 'POST' ? 201 : 200);
        }),
      )..bearerToken = 'jwt';
      addTearDown(api.close);
      gateway = HttpDescuentoGateway(api);
    });

    test('lista los descuentos con rango y asignaciones', () async {
      final lista = await gateway.listar(7);

      expect(peticiones.single.method, 'GET');
      expect(peticiones.single.url.path, '/backend/api/negocios/7/descuentos');
      expect(lista.single.rango, 'De 10 a 20 piezas');
      expect(lista.single.asignacionTexto, '2 productos · 1 categoría');
    });

    test('crea y edita enviando el cuerpo esperado', () async {
      const datos = DatosDescuento(
        nombre: ' Mayoreo ',
        cantidadMinima: '10',
        cantidadMaxima: '',
        porcentaje: '5,5',
      );
      await gateway.crear(7, datos);
      expect(peticiones.last.method, 'POST');
      expect(jsonDecode(peticiones.last.body), {
        'nombre': 'Mayoreo',
        'cantidadMinima': 10,
        'cantidadMaxima': null,
        'porcentaje': 5.5,
      });

      await gateway.editar(7, 1, datos);
      expect(peticiones.last.method, 'PUT');
      expect(peticiones.last.url.path, '/backend/api/negocios/7/descuentos/1');
    });

    test('elimina, activa y desactiva', () async {
      await gateway.eliminar(7, 1);
      expect(peticiones.last.method, 'DELETE');
      await gateway.cambiarEstado(7, 1, activo: true);
      expect(peticiones.last.method, 'PATCH');
      expect(peticiones.last.url.path.endsWith('/1/activar'), isTrue);
      await gateway.cambiarEstado(7, 1, activo: false);
      expect(peticiones.last.url.path.endsWith('/1/desactivar'), isTrue);
    });

    test('asigna y quita productos, categorías y áreas', () async {
      await gateway.asignar(7, 1, DestinoDescuento.producto, 3);
      expect(peticiones.last.method, 'PUT');
      expect(peticiones.last.url.path.endsWith('/1/productos/3'), isTrue);
      await gateway.asignar(7, 1, DestinoDescuento.categoria, 2);
      expect(peticiones.last.url.path.endsWith('/1/categorias/2'), isTrue);
      await gateway.quitar(7, 1, DestinoDescuento.area, 5);
      expect(peticiones.last.method, 'DELETE');
      expect(peticiones.last.url.path.endsWith('/1/areas/5'), isTrue);
    });

    test('un 401 se reporta como sesión expirada', () async {
      final api = ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((_) async => _json('{"detail":"x"}', 401)),
      );
      addTearDown(api.close);

      await expectLater(
        HttpDescuentoGateway(api).listar(7),
        throwsA(
          isA<DescuentoFailure>().having(
            (e) => e.sesionExpirada,
            'sesionExpirada',
            isTrue,
          ),
        ),
      );
    });

    test('una respuesta con formato inesperado falla con mensaje claro', () async {
      final api = ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((_) async => _json('[{"id":1,"nombre":"X"}]')),
      );
      addTearDown(api.close);

      await expectLater(
        HttpDescuentoGateway(api).listar(7),
        throwsA(isA<DescuentoFailure>()),
      );
    });

    test('el catálogo une productos, categorías y áreas con su contexto', () async {
      final api = ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((r) async {
          final ruta = r.url.path + (r.url.hasQuery ? '?${r.url.query}' : '');
          if (ruta.endsWith('api/productos/catalogo?negocioId=7')) {
            return _json('[{"id":3,"nombre":"Olla","categoriaId":10}]');
          }
          if (ruta.endsWith('/areas')) {
            return _json('[{"id":20,"nombre":"Cocina"}]');
          }
          if (ruta.endsWith('/areas/20/categorias')) {
            return _json('[{"id":10,"areaId":20,"nombre":"Ollas"}]');
          }
          return _json('[]', 404);
        }),
      );
      addTearDown(api.close);

      final c = await HttpDescuentoGateway(api).catalogo(7);

      expect(c.productos.single.contexto, 'Ollas');
      expect(c.categorias.single.contexto, 'Cocina');
      expect(c.areas.single.nombre, 'Cocina');
    });
  });

  group('DescuentosPage', () {
    testWidgets('muestra todos los descuentos, también los inactivos', (
      tester,
    ) async {
      await _abrirLista(tester, _Gateway([_mayoreo, _docena]));

      expect(find.text('2 descuentos registrados'), findsOneWidget);
      expect(find.text('5 % de descuento'), findsOneWidget);
      expect(find.text('De 10 a 20 piezas'), findsOneWidget);
      expect(find.text('Asignado a: 1 producto'), findsOneWidget);
      expect(find.text('Activo'), findsOneWidget);
      expect(find.text('Inactivo'), findsOneWidget);
      expect(find.text('Sin asignar'), findsOneWidget);
      expect(find.text('Administrar'), findsNWidgets(2));
      expect(find.text('Editar'), findsNWidgets(2));
    });

    testWidgets('sin descuentos ofrece registrar el primero', (tester) async {
      await _abrirLista(tester, _Gateway());

      expect(find.text('Aún no tienes descuentos registrados.'), findsOneWidget);
      expect(find.byKey(const ValueKey('descuento-registrar')), findsOneWidget);
    });

    testWidgets('un error se muestra y permite reintentar', (tester) async {
      final gateway = _Gateway()..fallo = const DescuentoFailure('Sin conexión.');
      await _abrirLista(tester, gateway);

      expect(find.text('Sin conexión.'), findsOneWidget);
      gateway.fallo = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Aún no tienes descuentos registrados.'), findsOneWidget);
    });

    testWidgets('registrar un descuento lo agrega a la lista', (tester) async {
      final gateway = _Gateway([_mayoreo]);
      await _abrirLista(tester, gateway);

      await _tocar(tester, 'descuento-registrar');
      await _escribir(tester, 'descuento-nombre', 'Super mayoreo');
      await _escribir(tester, 'descuento-cantidadMinima', '21');
      await _escribir(tester, 'descuento-cantidadMaxima', '30');
      await _escribir(tester, 'descuento-porcentaje', '12');
      await _tocar(tester, 'descuento-guardar');

      expect(gateway.llamadas, ['crear']);
      expect(find.text('Descuento registrado correctamente.'), findsOneWidget);
      expect(find.text('Super mayoreo'), findsOneWidget);
      expect(find.text('De 21 a 30 piezas'), findsOneWidget);
    });

    testWidgets('el formulario valida antes de enviar', (tester) async {
      final gateway = _Gateway();
      await _abrirLista(tester, gateway);

      await _tocar(tester, 'descuento-registrar');
      await _tocar(tester, 'descuento-guardar');

      expect(gateway.llamadas, isEmpty);
      expect(find.text('Escribe el nombre del descuento.'), findsOneWidget);
      expect(find.text('Indica al menos 1 pieza.'), findsOneWidget);
      expect(find.text('Usa un valor mayor que 0 y hasta 100.'), findsOneWidget);
    });

    testWidgets('editar actualiza los datos del descuento', (tester) async {
      final gateway = _Gateway([_mayoreo]);
      await _abrirLista(tester, gateway);

      await _tocar(tester, 'descuento-editar-1');
      expect(find.text('Editar descuento'), findsOneWidget);
      await _escribir(tester, 'descuento-nombre', 'Mayoreo plus');
      await _escribir(tester, 'descuento-porcentaje', '8');
      await _tocar(tester, 'descuento-guardar');

      expect(gateway.llamadas, ['editar 1']);
      expect(gateway.ultimosDatos?.cantidadMaxima, '20');
      expect(find.text('Cambios guardados correctamente.'), findsOneWidget);
      expect(find.text('Mayoreo plus'), findsOneWidget);
      expect(find.text('8 % de descuento'), findsOneWidget);
    });

    testWidgets('desactivar y activar desde la edición', (tester) async {
      final gateway = _Gateway([_mayoreo]);
      await _abrirLista(tester, gateway);

      await _tocar(tester, 'descuento-editar-1');
      expect(find.text('Desactivar descuento'), findsOneWidget);
      await _tocar(tester, 'descuento-estado');

      expect(gateway.llamadas, ['desactivar 1']);
      expect(find.text('Descuento desactivado correctamente.'), findsOneWidget);
      expect(find.text('Inactivo'), findsOneWidget);

      await _tocar(tester, 'descuento-editar-1');
      expect(find.text('Activar descuento'), findsOneWidget);
      await _tocar(tester, 'descuento-estado');
      expect(gateway.llamadas, ['desactivar 1', 'activar 1']);
    });

    testWidgets('eliminar pide confirmación y quita el descuento', (
      tester,
    ) async {
      final gateway = _Gateway([_mayoreo, _docena]);
      await _abrirLista(tester, gateway);

      await _tocar(tester, 'descuento-editar-1');
      await _tocar(tester, 'descuento-eliminar');
      expect(find.text('¿Eliminar descuento?'), findsOneWidget);

      await tester.tap(find.text('Cancelar').last);
      await tester.pumpAndSettle();
      expect(gateway.llamadas, isEmpty);

      await _tocar(tester, 'descuento-eliminar');
      await tester.tap(find.byKey(const ValueKey('descuento-confirmar-eliminar')));
      await tester.pumpAndSettle();

      expect(gateway.llamadas, ['eliminar 1']);
      expect(find.text('Descuento eliminado correctamente.'), findsOneWidget);
      expect(find.text('Mayoreo'), findsNothing);
      expect(find.text('Docena'), findsOneWidget);
    });
  });

  group('DescuentoDetallePage', () {
    Future<_Gateway> abrir(WidgetTester tester, [Descuento? d]) async {
      _pantalla(tester);
      final gateway = _Gateway([d ?? _mayoreo]);
      await tester.pumpWidget(
        MaterialApp(
          home: DescuentoDetallePage(
            negocio: _negocio,
            descuento: d ?? _mayoreo,
            gestion: GestionDescuentos(gateway),
            onSesionExpirada: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      return gateway;
    }

    testWidgets('muestra por nombre lo que tiene asignado', (tester) async {
      await abrir(tester);

      expect(find.text('Administrar descuento'), findsOneWidget);
      expect(find.text('Productos (1)'), findsOneWidget);
      expect(find.text('Olla michoacana'), findsOneWidget);
      expect(find.text('Categorías (0)'), findsOneWidget);
      expect(find.text('Sin categorías asignadas.'), findsOneWidget);
      expect(find.text('Áreas (0)'), findsOneWidget);
    });

    testWidgets('asigna un producto, una categoría y un área', (tester) async {
      final gateway = await abrir(tester);

      await _tocar(tester, 'descuento-asignar-producto');
      // La olla ya está asignada: solo se ofrece la jarra.
      expect(find.byKey(const ValueKey('descuento-opcion-3')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('descuento-opcion-4')));
      await tester.pumpAndSettle();
      expect(find.text('Productos (2)'), findsOneWidget);
      expect(find.text('Descuento asignado a Jarra.'), findsOneWidget);

      await _tocar(tester, 'descuento-asignar-categoria');
      await tester.tap(find.byKey(const ValueKey('descuento-opcion-10')));
      await tester.pumpAndSettle();
      expect(find.text('Categorías (1)'), findsOneWidget);

      await _tocar(tester, 'descuento-asignar-area');
      await tester.tap(find.byKey(const ValueKey('descuento-opcion-20')));
      await tester.pumpAndSettle();
      expect(find.text('Áreas (1)'), findsOneWidget);

      expect(gateway.llamadas, [
        'asignar producto 4',
        'asignar categoria 10',
        'asignar area 20',
      ]);
    });

    testWidgets('quita un producto asignado', (tester) async {
      final gateway = await abrir(tester);

      await _tocar(tester, 'descuento-quitar-producto-3');

      expect(gateway.llamadas, ['quitar producto 3']);
      expect(find.text('Productos (0)'), findsOneWidget);
      expect(find.text('Se quitó Olla michoacana del descuento.'), findsOneWidget);
    });

    testWidgets('el selector filtra por búsqueda', (tester) async {
      await abrir(tester, _docena);

      await _tocar(tester, 'descuento-asignar-producto');
      expect(find.byKey(const ValueKey('descuento-opcion-3')), findsOneWidget);
      expect(find.byKey(const ValueKey('descuento-opcion-4')), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('descuento-selector-busqueda')),
        'jarr',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('descuento-opcion-3')), findsNothing);
      expect(find.byKey(const ValueKey('descuento-opcion-4')), findsOneWidget);
    });

    testWidgets('desde la lista, Administrar refleja los cambios', (
      tester,
    ) async {
      final gateway = _Gateway([_mayoreo]);
      await _abrirLista(tester, gateway);

      await _tocar(tester, 'descuento-administrar-1');
      await _tocar(tester, 'descuento-asignar-area');
      await tester.tap(find.byKey(const ValueKey('descuento-opcion-20')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Volver').last);
      await tester.pumpAndSettle();

      expect(find.text('Asignado a: 1 producto · 1 área'), findsOneWidget);
    });
  });

  testWidgets(
    'la pantalla del negocio muestra la tarjeta Descuentos y la abre',
    (tester) async {
      _pantalla(tester);
      NegocioSucursal? abierto;
      await tester.pumpWidget(
        MaterialApp(
          home: SucursalesPage(
            gestion: _GestionSucursales(),
            negocioInicial: const NegocioSucursal(id: 7, nombre: 'Barro Centro'),
            onSesionExpirada: () {},
            onDescuentos: (negocio) => abierto = negocio,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Áreas y categorías'), findsOneWidget);
      expect(find.text('Productos'), findsOneWidget);
      expect(find.text('Descuentos'), findsOneWidget);

      await tester.tap(find.text('Descuentos'));

      expect(abierto?.id, 7);
    },
  );
}
