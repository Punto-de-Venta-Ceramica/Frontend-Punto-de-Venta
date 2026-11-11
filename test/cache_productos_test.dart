import 'package:flutter_test/flutter_test.dart';
import 'package:punto_de_venta/features/productos/application/ports/outbound/existencias_gateway.dart';
import 'package:punto_de_venta/features/productos/application/ports/outbound/producto_gateway.dart';
import 'package:punto_de_venta/features/productos/application/services/gestion_productos.dart';
import 'package:punto_de_venta/features/productos/domain/producto.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/outbound/cache/cache_productos.dart';

class _Productos implements ProductoGateway {
  int listados = 0;
  int consultas = 0;
  int areasPedidas = 0;
  bool fallarConsulta = false;

  @override
  Future<PaginaProductos> listar(
    int negocioId, {
    int pagina = 0,
    FiltroProductos filtro = const FiltroProductos(),
  }) async {
    listados++;
    return const PaginaProductos(
      productos: [],
      pagina: 0,
      ultima: true,
      total: 0,
    );
  }

  @override
  Future<List<AreaProducto>> areas(int negocioId) async {
    areasPedidas++;
    return const [AreaProducto(id: 1, nombre: 'Cocina')];
  }

  @override
  Future<Producto> consultar(int id) async {
    consultas++;
    if (fallarConsulta) throw const ProductoFailure('No encontrado');
    return Producto(id: id, nombre: 'Jarro', precio: 10);
  }

  @override
  Future<Producto> editar(int id, DatosProducto datos) async =>
      Producto(id: id, nombre: datos.nombre, precio: 1);

  @override
  Future<void> eliminar(int id) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Existencias implements ExistenciasGateway {
  int consultas = 0;
  int existencia = 5;

  @override
  Future<List<ExistenciaSucursal>> porProducto(int productoId) async {
    consultas++;
    return [
      ExistenciaSucursal(
        inventarioId: 7,
        sucursalId: 1,
        sucursalNombre: 'Centro',
        existencia: existencia,
      ),
    ];
  }

  @override
  Future<int> ajustar(int inventarioId, int cantidad) async =>
      existencia += cantidad;

  @override
  Future<ExistenciaSucursal> asignar(
    int productoId,
    SucursalProducto sucursal,
    int existencia,
  ) async => ExistenciaSucursal(
    inventarioId: 8,
    sucursalId: sucursal.id,
    sucursalNombre: sucursal.nombre,
    existencia: existencia,
  );
}

void main() {
  late _Productos productos;
  late _Existencias existencias;
  late DateTime ahora;
  late CacheProductos cache;
  late GestionProductos gestion;

  setUp(() {
    productos = _Productos();
    existencias = _Existencias();
    ahora = DateTime(2026, 1, 1);
    cache = CacheProductos(productos, existencias, ahora: () => ahora);
    gestion = GestionProductos(
      cache.productos,
      cache.existencias,
      cache: cache,
    );
  });

  const datos = DatosProducto(nombre: 'Nuevo', precio: '1', categoriaId: 1);

  test('reutiliza la página vigente y la renueva al vencer', () async {
    await gestion.listar(1);
    await gestion.listar(1);
    expect(productos.listados, 1);

    await gestion.listar(1, filtro: const FiltroProductos(buscar: 'ja'));
    expect(productos.listados, 2, reason: 'otro filtro, otra clave');

    ahora = ahora.add(const Duration(minutes: 6));
    await gestion.listar(1);
    expect(productos.listados, 3);
  });

  test('editar y eliminar descartan las páginas guardadas', () async {
    await gestion.listar(1);
    await gestion.editar(3, 1, datos);
    await gestion.listar(1);
    await gestion.eliminar(3);
    await gestion.listar(1);
    expect(productos.listados, 3);
  });

  test(
    'el detalle combina producto y existencias de su propio endpoint',
    () async {
      final detalle = await gestion.consultar(3, 1);
      expect(detalle.existenciaTotal, 5);
      expect(existencias.consultas, 1);
    },
  );

  test('el detalle siempre va al servidor pero queda guardado', () async {
    expect(gestion.detalleGuardado(3), isNull);
    await gestion.consultar(3, 1);
    await gestion.consultar(3, 1);
    expect(productos.consultas, 2);
    expect(gestion.detalleGuardado(3)?.existenciaTotal, 5);

    await gestion.eliminar(3);
    expect(gestion.detalleGuardado(3), isNull);
  });

  test('editar conserva las existencias leídas en paralelo', () async {
    final editado = await gestion.editar(3, 1, datos);
    expect(editado.nombre, 'Nuevo');
    expect(editado.existenciaTotal, 5);
    expect(gestion.detalleGuardado(3)?.nombre, 'Nuevo');
  });

  test('ajustar y asignar corrigen el detalle guardado', () async {
    await gestion.consultar(3, 1);
    await gestion.listar(1);

    await gestion.ajustarExistencia(7, -2);
    expect(gestion.detalleGuardado(3)?.existenciaTotal, 3);

    await gestion.asignarASucursal(
      3,
      const SucursalProducto(id: 2, nombre: 'Norte'),
      4,
    );
    expect(gestion.detalleGuardado(3)?.existenciaTotal, 7);
    await gestion.listar(1);
    expect(productos.listados, 2, reason: 'asignar descarta los listados');
  });

  test('si falla el producto se informa su error', () async {
    productos.fallarConsulta = true;
    await expectLater(gestion.consultar(3, 1), throwsA(isA<ProductoFailure>()));
  });

  test('las áreas se guardan y descartar lo olvida todo', () async {
    await gestion.areas(1);
    await gestion.areas(1);
    expect(productos.areasPedidas, 1);
    await gestion.consultar(3, 1);

    gestion.descartarCache();
    await gestion.areas(1);
    expect(productos.areasPedidas, 2);
    expect(gestion.detalleGuardado(3), isNull);
  });
}
