import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/features/connection/domain/connection_failure.dart';
import 'package:punto_de_venta/features/connection/infrastructure/adapters/outbound/http/http_health_gateway.dart';

void main() {
  test(
    'Consulta el endpoint real y conserva el prefijo de despliegue',
    () async {
      final api = ApiClient(
        baseUrl: 'https://example.com/backend',
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://example.com/backend/api/health',
          );
          expect(request.headers['Accept'], 'application/json');
          return http.Response(
            '{"status":"UP","application":"puntoventaapi"}',
            200,
          );
        }),
      );
      addTearDown(api.close);
      expect(
        (await HttpHealthGateway(api).check()).application,
        'puntoventaapi',
      );
    },
  );

  test('Reporta fallos HTTP', () async {
    final api = ApiClient(
      baseUrl: 'http://localhost:8080',
      client: MockClient((_) async => http.Response('error', 503)),
    );
    addTearDown(api.close);
    await expectLater(
      HttpHealthGateway(api).check(),
      throwsA(isA<ConnectionFailure>()),
    );
  });

  for (final body in [
    '<html>error</html>',
    '[]',
    '{"status":"DOWN"}',
    '{"status":"UP","application":"other"}',
  ]) {
    test('Rechaza una respuesta inesperada: $body', () async {
      final api = ApiClient(
        baseUrl: 'http://localhost:8080',
        client: MockClient((_) async => http.Response(body, 200)),
      );
      addTearDown(api.close);
      await expectLater(
        HttpHealthGateway(api).check(),
        throwsA(isA<ConnectionFailure>()),
      );
    });
  }

  test('Reporta una conexión fallida', () async {
    final api = ApiClient(
      baseUrl: 'http://localhost:8080',
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    addTearDown(api.close);
    await expectLater(
      HttpHealthGateway(api).check(),
      throwsA(isA<ConnectionFailure>()),
    );
  });
}
