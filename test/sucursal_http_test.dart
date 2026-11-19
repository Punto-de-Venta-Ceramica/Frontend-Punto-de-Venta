import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/features/sucursal/domain/sucursal.dart';
import 'package:punto_de_venta/features/sucursal/application/services/gestion_sucursales.dart';
import 'package:punto_de_venta/features/sucursal/infrastructure/adapters/outbound/http/http_sucursal_gateway.dart';

const datos = DatosSucursal(
  nombre: 'Norte',
  descripcion: 'Atención a clientes',
  ciudad: 'Dolores Hidalgo',
  calle: 'Héroes 24',
  codigoPostal: '37800',
);
const respuesta =
    '{"id":8,"negocioId":2,"nombre":"Norte","descripcion":null,"ciudad":"Dolores Hidalgo","calle":"Héroes 24","codigoPostal":"37800"}';

http.Response jsonResponse(String body, int status) => http.Response(
  body,
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test(
    'Contrato HTTP real: Bearer, consulta POST, PATCH restringido y DELETE 204',
    () async {
      final peticiones = <http.Request>[];
      final api = ApiClient(
        baseUrl: 'https://example.test/backend',
        client: MockClient((r) async {
          peticiones.add(r);
          expect(r.headers['Authorization'], 'Bearer jwt-de-prueba');
          if (r.method == 'DELETE') return jsonResponse('', 204);
          if (r.url.path.endsWith('negocios')) {
            return jsonResponse(
              '[{"id":2,"nombre":"Cerámica del Centro"}]',
              200,
            );
          }
          if (r.url.path.endsWith('consultar')) {
            return jsonResponse('[$respuesta]', 200);
          }
          return jsonResponse(respuesta, r.method == 'POST' ? 201 : 200);
        }),
      )..bearerToken = 'jwt-de-prueba';
      addTearDown(api.close);
      final gateway = HttpSucursalGateway(api);
      expect((await gateway.negocios()).single.id, 2);
      expect((await gateway.listar(2)).single.descripcion, '');
      expect(peticiones.last.method, 'POST');
      expect(jsonDecode(peticiones.last.body), {'negocioId': 2});
      await gateway.crear(2, datos);
      expect(jsonDecode(peticiones.last.body)['ciudad'], 'Dolores Hidalgo');
      await gateway.editar(8, datos);
      expect(peticiones.last.method, 'PATCH');
      expect(jsonDecode(peticiones.last.body), {
        'id': 8,
        'nombre': 'Norte',
        'descripcion': 'Atención a clientes',
      });
      await gateway.eliminar(8);
      expect(jsonDecode(peticiones.last.body), {'id': 8});
    },
  );

  for (final status in [400, 401, 403, 404, 409, 500]) {
    test(
      'HTTP $status no filtra el cuerpo y distingue sesión expirada',
      () async {
        final api = ApiClient(
          baseUrl: 'http://localhost',
          client: MockClient(
            (_) async =>
                jsonResponse('{"detail":"SQL secreto del servidor"}', status),
          ),
        );
        addTearDown(api.close);
        await expectLater(
          HttpSucursalGateway(api).eliminar(8),
          throwsA(
            isA<SucursalFailure>()
                .having(
                  (e) => e.message.contains('SQL'),
                  'sin información interna',
                  false,
                )
                .having((e) => e.sesionExpirada, 'sesión', status == 401),
          ),
        );
      },
    );
  }
  for (final body in [
    '{}',
    '[{"id":8}]',
    '[${respuesta.replaceFirst('"negocioId":2', '"negocioId":3')}]',
  ]) {
    test(
      'Rechaza listas mal formadas o de un negocio diferente: $body',
      () async {
        final api = ApiClient(
          baseUrl: 'http://localhost',
          client: MockClient((_) async => jsonResponse(body, 200)),
        );
        addTearDown(api.close);
        await expectLater(
          HttpSucursalGateway(api).listar(2),
          throwsA(isA<SucursalFailure>()),
        );
      },
    );
  }
  test('Valida antes de enviar y no exige dirección durante edición', () async {
    var llamadas = 0;
    final api = ApiClient(
      baseUrl: 'http://localhost',
      client: MockClient((_) async {
        llamadas++;
        return jsonResponse(respuesta, 200);
      }),
    );
    addTearDown(api.close);
    final gestion = GestionSucursales(HttpSucursalGateway(api));
    expect(
      () => gestion.crear(2, const DatosSucursal(nombre: ' ')),
      throwsA(isA<SucursalFailure>()),
    );
    expect(llamadas, 0);
    final errores = const DatosSucursal(
      nombre: 'Norte',
      ciudad: 'Ciudad',
      calle: 'Calle',
      codigoPostal: '1234',
    ).validar(registro: true);
    expect(errores.keys, contains('codigoPostal'));
    expect(
      const DatosSucursal(nombre: 'Norte').validar(registro: false),
      isEmpty,
    );
    await gestion.editar(8, const DatosSucursal(nombre: 'Norte'));
    expect(llamadas, 1);
  });
}
