import 'package:flutter_test/flutter_test.dart';
import 'package:punto_de_venta/features/descuentos/application/ports/outbound/descuento_gateway.dart';
import 'package:punto_de_venta/features/descuentos/domain/descuento.dart';
import 'package:punto_de_venta/features/descuentos/infrastructure/adapters/outbound/cache/cached_descuento_gateway.dart';

const _mayoreo = Descuento(
  id: 1,
  nombre: 'Mayoreo',
  cantidadMinima: 5,
  porcentaje: 10,
  activo: true,
);

/// Cuenta cuántas veces se llega al servidor.
class _Origen implements DescuentoGateway {
  int listados = 0;
  int catalogos = 0;
  bool fallar = false;

  @override
  Future<List<Descuento>> listar(int negocioId) async {
    listados++;
    if (fallar) throw const DescuentoFailure('Sin conexión.');
    return const [_mayoreo];
  }

  @override
  Future<CatalogoDescuento> catalogo(int negocioId) async {
    catalogos++;
    return const CatalogoDescuento();
  }

  @override
  Future<Descuento> crear(int negocioId, DatosDescuento datos) async =>
      _mayoreo;

  @override
  Future<Descuento> asignar(
    int negocioId,
    int id,
    DestinoDescuento destino,
    int destinoId,
  ) async {
    if (fallar) throw const DescuentoFailure('Se cruza.', traslape: true);
    return _mayoreo;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late _Origen origen;
  late DateTime ahora;
  late CachedDescuentoGateway cache;

  setUp(() {
    origen = _Origen();
    ahora = DateTime(2026, 11, 12, 10);
    cache = CachedDescuentoGateway(origen, ahora: () => ahora);
  });

  test('reutiliza la lista durante 5 minutos', () async {
    await cache.listar(7);
    ahora = ahora.add(const Duration(minutes: 4));
    await cache.listar(7);
    expect(origen.listados, 1);

    ahora = ahora.add(const Duration(minutes: 2));
    await cache.listar(7);
    expect(origen.listados, 2);
  });

  test('cada negocio tiene su propia lista', () async {
    await cache.listar(7);
    await cache.listar(8);
    expect(origen.listados, 2);
  });

  test('un cambio exitoso descarta la lista; uno fallido no', () async {
    await cache.listar(7);
    await cache.crear(
      7,
      const DatosDescuento(nombre: 'A', cantidadMinima: '5', porcentaje: '5'),
    );
    await cache.listar(7);
    expect(origen.listados, 2);

    origen.fallar = true;
    await expectLater(
      cache.asignar(7, 1, DestinoDescuento.producto, 3),
      throwsA(isA<DescuentoFailure>()),
    );
    origen.fallar = false;
    await cache.listar(7);
    expect(origen.listados, 2);
  });

  test('los errores no se guardan', () async {
    origen.fallar = true;
    await expectLater(cache.listar(7), throwsA(isA<DescuentoFailure>()));
    origen.fallar = false;
    expect(await cache.listar(7), [_mayoreo]);
    expect(origen.listados, 2);
  });

  test('peticiones simultáneas comparten una sola llamada', () async {
    await Future.wait([cache.listar(7), cache.listar(7), cache.catalogo(7)]);
    expect(origen.listados, 1);
    expect(origen.catalogos, 1);
  });

  test('el catálogo dura 10 minutos y se puede descartar', () async {
    await cache.catalogo(7);
    ahora = ahora.add(const Duration(minutes: 9));
    await cache.catalogo(7);
    expect(origen.catalogos, 1);

    cache.descartarCatalogo();
    await cache.catalogo(7);
    expect(origen.catalogos, 2);
  });
}
