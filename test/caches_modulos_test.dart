import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:punto_de_venta/core/infrastructure/cache/cache_en_memoria.dart';
import 'package:punto_de_venta/core/infrastructure/cache/consultas_compartidas.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/features/areas_categorias/application/ports/outbound/catalogo_gateway.dart';
import 'package:punto_de_venta/features/areas_categorias/domain/catalogo.dart';
import 'package:punto_de_venta/features/areas_categorias/infrastructure/adapters/outbound/cache/cached_catalogo_gateway.dart';
import 'package:punto_de_venta/features/corte_caja/application/ports/outbound/corte_caja_gateway.dart';
import 'package:punto_de_venta/features/corte_caja/domain/corte_caja.dart';
import 'package:punto_de_venta/features/corte_caja/infrastructure/adapters/outbound/cache/cached_corte_caja_gateway.dart';
import 'package:punto_de_venta/features/empleados/application/ports/outbound/empleado_gateway.dart';
import 'package:punto_de_venta/features/empleados/domain/empleado.dart';
import 'package:punto_de_venta/features/empleados/infrastructure/adapters/outbound/cache/cached_empleado_gateway.dart';
import 'package:punto_de_venta/features/empleados/infrastructure/adapters/outbound/http/http_empleado_gateway.dart';
import 'package:punto_de_venta/features/negocios/domain/negocio.dart';
import 'package:punto_de_venta/features/negocios/infrastructure/adapters/outbound/http/http_negocio_gateway.dart';
import 'package:punto_de_venta/features/pedidos/application/gestion_pedidos.dart';
import 'package:punto_de_venta/features/pedidos/application/ports/pedidos_gateway.dart';
import 'package:punto_de_venta/features/pedidos/domain/pedido.dart';
import 'package:punto_de_venta/features/pedidos/infrastructure/adapters/outbound/pedidos_con_memoria.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/outbound/http/http_producto_gateway.dart';
import 'package:punto_de_venta/features/sucursal/domain/sucursal.dart';
import 'package:punto_de_venta/features/sucursal/infrastructure/adapters/outbound/http/http_sucursal_gateway.dart';

http.Response _json(String body, [int status = 200]) => http.Response(
  body,
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const _sucursal =
    '{"id":8,"negocioId":2,"nombre":"Norte","descripcion":null,"ciudad":"Dolores","calle":"Héroes 24","codigoPostal":"37800"}';

/// API falsa que cuenta las peticiones por "MÉTODO ruta".
(ApiClient, Map<String, int>) _api({String negocio = 'Cerámica'}) {
  final conteo = <String, int>{};
  var nombre = negocio;
  final api = ApiClient(
    baseUrl: 'https://example.test/backend',
    client: MockClient((r) async {
      final clave = '${r.method} ${r.url.path.split('/backend/').last}';
      conteo[clave] = (conteo[clave] ?? 0) + 1;
      if (r.url.path.endsWith('api/negocios') && r.method == 'GET') {
        return _json('[{"id":2,"nombre":"$nombre"}]');
      }
      if (r.url.path.endsWith('consultar')) return _json('[$_sucursal]');
      if (r.method == 'PUT' && r.url.path.endsWith('api/negocios/2')) {
        nombre = 'Cerámica Nueva';
        return _json('{"id":2,"nombre":"$nombre"}');
      }
      if (r.method == 'PATCH') return _json(_sucursal);
      if (r.method == 'DELETE') return _json('', 204);
      if (r.url.path.endsWith('api/empleados')) return _json('[]');
      return _json('{}', 404);
    }),
  )..bearerToken = 'jwt';
  return (api, conteo);
}

class _Reloj {
  DateTime ahora = DateTime(2026, 1, 1, 9);
  void avanzar(Duration d) => ahora = ahora.add(d);
}

void main() {
  group('CacheEnMemoria', () {
    test(
      'reutiliza lo vigente, comparte llamadas y no guarda errores',
      () async {
        final reloj = _Reloj();
        final cache = CacheEnMemoria<int, int>(
          vigencia: const Duration(minutes: 10),
          ahora: () => reloj.ahora,
        );
        var llamadas = 0;
        Future<int> cargar() async => ++llamadas;

        final a = cache.obtener(1, cargar);
        final b = cache.obtener(1, cargar);
        expect(await a, 1);
        expect(await b, 1, reason: 'llamadas simultáneas comparten una sola');

        reloj.avanzar(const Duration(minutes: 9));
        expect(await cache.obtener(1, cargar), 1);
        reloj.avanzar(const Duration(minutes: 2));
        expect(await cache.obtener(1, cargar), 2, reason: 'venció la vigencia');

        await expectLater(
          cache.obtener(2, () async => throw StateError('falla')),
          throwsStateError,
        );
        expect(
          await cache.obtener(2, cargar),
          3,
          reason: 'el error no se guarda',
        );
      },
    );
  });

  group('ConsultasCompartidas', () {
    test(
      'negocios y sucursales se piden una vez para todos los módulos',
      () async {
        final (api, conteo) = _api();
        addTearDown(api.close);
        final compartidas = ConsultasCompartidas(api);
        final negocios = HttpNegocioGateway(api, compartidas: compartidas);
        final sucursales = HttpSucursalGateway(api, compartidas: compartidas);
        final productos = HttpProductoGateway(api, compartidas: compartidas);
        final empleados = HttpEmpleadoGateway(api, compartidas: compartidas);

        expect((await negocios.listar()).single.nombre, 'Cerámica');
        expect((await sucursales.negocios()).single.id, 2);
        expect((await productos.negocios()).single.nombre, 'Cerámica');
        expect(conteo['GET api/negocios'], 1);

        expect((await sucursales.listar(2)).single.nombre, 'Norte');
        expect((await productos.sucursales(2)).single.id, 8);
        expect((await empleados.sucursales(2)).single.nombre, 'Norte');
        expect(conteo['POST api/sucursales/consultar'], 1);
      },
    );

    test('editar un negocio o una sucursal descarta lo guardado', () async {
      final (api, conteo) = _api();
      addTearDown(api.close);
      final compartidas = ConsultasCompartidas(api);
      final negocios = HttpNegocioGateway(api, compartidas: compartidas);
      final sucursales = HttpSucursalGateway(api, compartidas: compartidas);
      final productos = HttpProductoGateway(api, compartidas: compartidas);

      await productos.negocios();
      await negocios.editar(
        2,
        const DatosNegocio(nombre: 'Cerámica Nueva', eslogan: ''),
      );
      expect((await productos.negocios()).single.nombre, 'Cerámica Nueva');
      expect(conteo['GET api/negocios'], 2);

      await productos.sucursales(2);
      await sucursales.editar(
        8,
        const DatosSucursal(
          nombre: 'Norte',
          descripcion: '',
          ciudad: 'Dolores',
          calle: 'Héroes 24',
          codigoPostal: '37800',
        ),
      );
      await productos.sucursales(2);
      expect(conteo['POST api/sucursales/consultar'], 2);
    });

    test('vence a los 30 min y se vacía al cerrar sesión', () async {
      final (api, conteo) = _api();
      addTearDown(api.close);
      final reloj = _Reloj();
      final compartidas = ConsultasCompartidas(api, ahora: () => reloj.ahora);
      final negocios = HttpNegocioGateway(api, compartidas: compartidas);

      await negocios.listar();
      reloj.avanzar(const Duration(minutes: 29));
      await negocios.listar();
      expect(conteo['GET api/negocios'], 1);
      reloj.avanzar(const Duration(minutes: 2));
      await negocios.listar();
      expect(conteo['GET api/negocios'], 2);

      compartidas.descartar();
      await negocios.listar();
      expect(conteo['GET api/negocios'], 3);
    });
  });

  group('CachedEmpleadoGateway', () {
    test('10 min de vigencia y los cambios descartan el negocio', () async {
      final origen = _EmpleadosFalsos();
      final reloj = _Reloj();
      final cache = CachedEmpleadoGateway(origen, ahora: () => reloj.ahora);

      await cache.listar(2);
      await cache.listar(2);
      expect(origen.listados, 1);
      await cache.listar(2, sucursalId: 8);
      expect(origen.listados, 2, reason: 'otro filtro, otra entrada');

      await cache.asignarSucursales(
        negocioId: 2,
        empleadoId: 1,
        sucursalIds: const [8],
      );
      await cache.listar(2);
      await cache.listar(2, sucursalId: 8);
      expect(origen.listados, 4);

      reloj.avanzar(const Duration(minutes: 11));
      await cache.listar(2);
      expect(origen.listados, 5);

      await cache.eliminar(2, 1);
      await cache.listar(2);
      expect(origen.listados, 6);
    });
  });

  test(
    'dar de baja o renombrar una sucursal descarta los empleados guardados',
    () async {
      final (api, conteo) = _api();
      addTearDown(api.close);
      final compartidas = ConsultasCompartidas(api);
      final empleados = CachedEmpleadoGateway(
        HttpEmpleadoGateway(api, compartidas: compartidas),
      );
      compartidas.escucharCambiosSucursales(empleados.sucursalesCambiaron);
      final sucursales = HttpSucursalGateway(api, compartidas: compartidas);

      await empleados.listar(2);
      await empleados.listar(2);
      expect(conteo['GET api/empleados'], 1);

      await sucursales.eliminar(8);
      await empleados.listar(2);
      expect(conteo['GET api/empleados'], 2);

      await sucursales.editar(
        8,
        const DatosSucursal(
          nombre: 'Norte',
          descripcion: '',
          ciudad: 'Dolores',
          calle: 'Héroes 24',
          codigoPostal: '37800',
        ),
      );
      await empleados.listar(2);
      expect(conteo['GET api/empleados'], 3);
    },
  );

  group('CachedCatalogoGateway', () {
    test('30 min de vigencia y cada cambio descarta lo afectado', () async {
      final origen = _CatalogoFalso();
      final reloj = _Reloj();
      final cache = CachedCatalogoGateway(origen, ahora: () => reloj.ahora);
      const datos = DatosClasificacion(nombre: 'Nueva');

      await cache.listarAreas(2);
      await cache.listarCategorias(2, 5);
      await cache.listarAreas(2);
      await cache.listarCategorias(2, 5);
      expect((origen.areas, origen.categorias), (1, 1));

      await cache.crearCategoria(2, 5, datos);
      await cache.listarCategorias(2, 5);
      await cache.listarAreas(2);
      expect((origen.areas, origen.categorias), (1, 2));

      await cache.editarArea(2, 5, datos);
      await cache.listarAreas(2);
      expect(origen.areas, 2);

      reloj.avanzar(const Duration(minutes: 31));
      await cache.listarCategorias(2, 5);
      expect(origen.categorias, 3);
    });
  });

  group('PedidosConMemoria', () {
    test(
      'siempre consulta, recuerda lo último y un cambio lo descarta',
      () async {
        final origen = _PedidosFalsos();
        final memoria = PedidosConMemoria(origen);
        final gestion = GestionPedidos(memoria, memoria: memoria);

        expect(gestion.listadoGuardado(3, estado: 'PENDIENTE'), isNull);
        expect(gestion.pedidoGuardado(7), isNull);

        await gestion.listar(3, estado: 'PENDIENTE');
        await gestion.listar(3, estado: 'PENDIENTE');
        expect(origen.listados, 2, reason: 'nunca evita la consulta');
        expect(gestion.listadoGuardado(3, estado: 'PENDIENTE')?.total, 1);
        expect(gestion.listadoGuardado(3, estado: null), isNull);

        await gestion.listar(3, estado: 'PENDIENTE', pagina: 1);
        expect(
          gestion.listadoGuardado(3, estado: 'PENDIENTE')?.pagina,
          0,
          reason: 'solo se recuerda la primera página',
        );

        await gestion.obtener(7);
        expect(gestion.pedidoGuardado(7)?.saldo, 100);

        await gestion.pagar(7, 50, 'EFECTIVO');
        expect(gestion.pedidoGuardado(7), isNull);
        expect(gestion.listadoGuardado(3, estado: 'PENDIENTE'), isNull);
      },
    );
  });

  test(
    'una consulta que empezó antes de un pago no se recuerda al terminar',
    () async {
      final origen = _PedidosFalsos()..espera = Completer<void>();
      final memoria = PedidosConMemoria(origen);

      final listado = memoria.listar(3);
      final detalle = memoria.obtener(7);
      await memoria.pagar(7, 50, 'EFECTIVO');
      origen.espera!.complete();
      await (listado, detalle).wait;

      expect(memoria.listadoGuardado(3, null), isNull);
      expect(memoria.pedidoGuardado(7), isNull);
    },
  );

  group('CachedCorteCajaGateway', () {
    test('guarda solo los cortes cerrados', () async {
      final origen = _CortesFalsos();
      final cache = CachedCorteCajaGateway(origen);

      await cache.consultarCorte(1);
      await cache.consultarCorte(1);
      expect(origen.consultas, 1, reason: 'el corte 1 está cerrado');

      await cache.consultarCorte(2);
      await cache.consultarCorte(2);
      expect(origen.consultas, 3, reason: 'el corte 2 sigue abierto');

      await cache.cerrarCorte(corteId: 2, totalReal: 100);
      await cache.consultarCorte(2);
      expect(origen.consultas, 3, reason: 'al cerrarlo queda guardado');

      cache.descartar();
      await cache.consultarCorte(1);
      expect(origen.consultas, 4);
    });
  });
}

class _EmpleadosFalsos implements EmpleadoGateway {
  int listados = 0;

  @override
  Future<List<Empleado>> listar(
    int negocioId, {
    bool incluirAsignacion = true,
    int? sucursalId,
  }) async {
    listados++;
    return const [];
  }

  @override
  Future<Empleado> asignarSucursales({
    required int negocioId,
    required int empleadoId,
    required List<int> sucursalIds,
  }) async => Empleado(
    id: empleadoId,
    negocioId: negocioId,
    nombre: 'Ana',
    correoElectronico: 'ana@example.test',
  );

  @override
  Future<void> eliminar(int negocioId, int empleadoId) async {}

  @override
  Future<EmpleadoCreado> registrar(NuevoEmpleado datos) =>
      throw UnimplementedError();

  @override
  Future<List<SucursalEmpleado>> sucursales(int negocioId) async => const [];
}

class _CatalogoFalso implements CatalogoGateway {
  int areas = 0;
  int categorias = 0;

  AreaCatalogo _area(int negocioId, int id) =>
      AreaCatalogo(id: id, negocioId: negocioId, nombre: 'Área');

  CategoriaCatalogo _categoria(int areaId) =>
      CategoriaCatalogo(id: 9, areaId: areaId, nombre: 'Categoría');

  @override
  Future<List<AreaCatalogo>> listarAreas(int negocioId) async {
    areas++;
    return [_area(negocioId, 5)];
  }

  @override
  Future<List<CategoriaCatalogo>> listarCategorias(
    int negocioId,
    int areaId,
  ) async {
    categorias++;
    return [_categoria(areaId)];
  }

  @override
  Future<AreaCatalogo> consultarArea(int negocioId, int areaId) async =>
      _area(negocioId, areaId);

  @override
  Future<AreaCatalogo> crearArea(
    int negocioId,
    DatosClasificacion datos,
  ) async => _area(negocioId, 6);

  @override
  Future<AreaCatalogo> editarArea(
    int negocioId,
    int areaId,
    DatosClasificacion datos,
  ) async => _area(negocioId, areaId);

  @override
  Future<void> eliminarArea(int negocioId, int areaId) async {}

  @override
  Future<CategoriaCatalogo> crearCategoria(
    int negocioId,
    int areaId,
    DatosClasificacion datos,
  ) async => _categoria(areaId);

  @override
  Future<CategoriaCatalogo> editarCategoria(
    int negocioId,
    int areaId,
    int categoriaId,
    DatosClasificacion datos,
  ) async => _categoria(areaId);

  @override
  Future<void> eliminarCategoria(
    int negocioId,
    int areaId,
    int categoriaId,
  ) async {}
}

class _PedidosFalsos implements PedidosGateway {
  int listados = 0;

  /// Si se asigna, las consultas esperan a que se complete.
  Completer<void>? espera;

  @override
  Future<PaginaPedidos> listar(
    int sucursalId, {
    String? estado,
    int pagina = 0,
  }) async {
    listados++;
    await espera?.future;
    return PaginaPedidos(
      pedidos: const [],
      pagina: pagina,
      ultima: true,
      total: 1,
    );
  }

  @override
  Future<Pedido> obtener(int pedidoId) async {
    await espera?.future;
    return _pedido(pedidoId);
  }

  Pedido _pedido(int pedidoId) => Pedido(
    id: pedidoId,
    folio: 'P-$pedidoId',
    estado: 'PENDIENTE',
    cliente: 'Luis',
    telefono: '4181234567',
    ciudad: '',
    colonia: '',
    calle: '',
    descripcion: '',
    tipoEntrega: 'RECOGER',
    productos: const [],
    total: 100,
    pagado: 0,
    saldo: 100,
  );

  @override
  Future<void> pagar(int pedidoId, double monto, String metodo) async {}

  @override
  Future<bool> cajaAbierta(int sucursalId) async => true;

  @override
  Future<void> cambiarEstado(int pedidoId, String estado) async {}

  @override
  Future<void> cancelar(int pedidoId) async {}

  @override
  Future<void> editarDatos(int pedidoId, DatosEdicionPedido datos) async {}

  @override
  Future<void> marcarLeida(int id) async {}

  @override
  Future<PaginaAvisos> notificaciones({int pagina = 0}) async =>
      const PaginaAvisos(avisos: [], pagina: 0, ultima: true);

  @override
  Future<List<ProductoPedido>> productos(int sucursalId) async => const [];

  @override
  Future<int> registrar(DatosPedido datos) async => 1;
}

class _CortesFalsos implements CorteCajaGateway {
  int consultas = 0;

  static CorteCaja _corte(int id, {required bool cerrado}) => CorteCaja(
    id: id,
    cajaId: 1,
    sucursalId: 3,
    usuarioId: 1,
    usuarioNombre: 'Ana',
    fechaHoraApertura: DateTime(2026, 1, 1, 9),
    cerrado: cerrado,
    montoInicial: 0,
    totalVentas: 0,
    totalAnticipos: 0,
    totalLiquidaciones: 0,
    totalCancelaciones: 0,
    ventasEfectivo: const DesgloseMetodoPago(
      totalVentas: 0,
      anticipos: 0,
      liquidaciones: 0,
      cancelaciones: 0,
      subtotalNeto: 0,
      montoInicial: 0,
      totalEsperado: 0,
    ),
    ventasTarjeta: const DesgloseMetodoPago(
      totalVentas: 0,
      anticipos: 0,
      liquidaciones: 0,
      cancelaciones: 0,
      subtotalNeto: 0,
      montoInicial: 0,
      totalEsperado: 0,
    ),
    cancelacionesPedidos: const SeccionCancelaciones(
      totalCancelaciones: 0,
      cancelacionesEfectivo: 0,
      cancelacionesTarjeta: 0,
      detalles: [],
    ),
    totalEfectivo: 0,
    totalTarjeta: 0,
    totalEstimado: 0,
  );

  @override
  Future<CorteCaja> consultarCorte(int corteId) async {
    consultas++;
    return _corte(corteId, cerrado: corteId == 1);
  }

  @override
  Future<CorteCaja> cerrarCorte({
    required int corteId,
    required double totalReal,
  }) async => _corte(corteId, cerrado: true);

  @override
  Future<CorteCaja> abrirCorte({
    required int sucursalId,
    required double montoInicial,
  }) => throw UnimplementedError();

  @override
  Future<CorteCaja?> obtenerCorteActivo(int sucursalId) async => null;

  @override
  Future<List<ResumenCorteCaja>> listarHistorial(
    int sucursalId, {
    int page = 0,
    int size = 20,
  }) async => const [];
}
