import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';

String _refreshBody(String token) => jsonEncode({
  'token': token,
  'tipo': 'Bearer',
  'expiraEn': DateTime.now()
      .toUtc()
      .add(const Duration(minutes: 15))
      .toIso8601String(),
  'refreshToken': 'refresh-1',
  'refreshExpiraEn': DateTime.now()
      .toUtc()
      .add(const Duration(days: 20))
      .toIso8601String(),
});

ApiClient _client(
  MockClient mock, {
  Duration accessLeft = const Duration(minutes: 15),
  Duration refreshLeft = const Duration(days: 20),
  void Function()? onExpired,
}) => ApiClient(baseUrl: 'http://localhost:8080', client: mock)
  ..onSessionExpired = onExpired
  ..iniciarSesion(
    token: 'acceso-viejo',
    expiresAt: DateTime.now().add(accessLeft),
    refreshToken: 'refresh-1',
    refreshExpiresAt: DateTime.now().add(refreshLeft),
  );

void main() {
  test(
    'un 401 renueva el acceso en segundo plano y reintenta la petición',
    () async {
      final seen = <String>[];
      var refreshes = 0;
      final api = _client(
        MockClient((r) async {
          if (r.url.path == '/api/auth/refresh') {
            refreshes++;
            expect(jsonDecode(r.body), {'refreshToken': 'refresh-1'});
            return http.Response(_refreshBody('acceso-nuevo'), 200);
          }
          seen.add(r.headers['Authorization']!);
          return r.headers['Authorization'] == 'Bearer acceso-nuevo'
              ? http.Response('{"ok":true}', 200)
              : http.Response('', 401);
        }),
      );

      final data = await api.getJson('api/negocios');

      expect(data['ok'], true);
      expect(refreshes, 1);
      expect(seen, ['Bearer acceso-viejo', 'Bearer acceso-nuevo']);
    },
  );

  test('renueva antes de enviar si el acceso está por vencer', () async {
    final seen = <String>[];
    final api = _client(
      MockClient((r) async {
        if (r.url.path == '/api/auth/refresh') {
          return http.Response(_refreshBody('acceso-nuevo'), 200);
        }
        seen.add(r.headers['Authorization']!);
        return http.Response('{"ok":true}', 200);
      }),
      accessLeft: const Duration(seconds: 5),
    );

    await api.getJson('api/negocios');

    expect(seen, ['Bearer acceso-nuevo']);
  });

  test('peticiones simultáneas comparten una sola renovación', () async {
    var refreshes = 0;
    final api = _client(
      MockClient((r) async {
        if (r.url.path == '/api/auth/refresh') {
          refreshes++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return http.Response(_refreshBody('acceso-nuevo'), 200);
        }
        return http.Response('{"ok":true}', 200);
      }),
      accessLeft: const Duration(seconds: 5),
    );

    await Future.wait([api.getJson('api/a'), api.getJson('api/b')]);

    expect(refreshes, 1);
  });

  test('si el refresh es rechazado la sesión termina una sola vez', () async {
    var expired = 0;
    final api = _client(
      MockClient((r) async => http.Response('', 401)),
      onExpired: () => expired++,
    );

    await expectLater(
      api.getJson('api/negocios'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );
    expect(expired, 1);
    expect(api.bearerToken, isNull);
  });

  test('un fallo de red al renovar NO cierra la sesión', () async {
    var expired = 0;
    final api = _client(
      MockClient((r) async {
        if (r.url.path == '/api/auth/refresh') {
          throw http.ClientException('sin red');
        }
        return http.Response('', 401);
      }),
      onExpired: () => expired++,
    );

    await expectLater(
      api.getJson('api/negocios'),
      throwsA(isA<ApiException>()),
    );
    expect(expired, 0);
    expect(api.bearerToken, 'acceso-viejo');
  });

  test('con el refresh vencido cierra sesión sin llamar al servidor', () async {
    var calls = 0;
    var expired = 0;
    final api = _client(
      MockClient((r) async {
        calls++;
        return http.Response('', 401);
      }),
      accessLeft: const Duration(seconds: 1),
      refreshLeft: const Duration(seconds: -1),
      onExpired: () => expired++,
    );

    await expectLater(
      api.getJson('api/negocios'),
      throwsA(isA<ApiException>()),
    );
    expect(calls, 0);
    expect(expired, 1);
  });
}
