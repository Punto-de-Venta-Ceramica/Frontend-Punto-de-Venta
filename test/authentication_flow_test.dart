import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/features/authentication/domain/auth_session.dart';
import 'package:punto_de_venta/features/authentication/infrastructure/adapters/outbound/http/http_authentication_gateway.dart';
import 'package:punto_de_venta/features/login/domain/login_input.dart';
import 'owner_registration_page_test.dart' as registration;
import 'login_test.dart' as login;

String sessionResponse({int seconds = 900}) => jsonEncode({
  'token': 'test-jwt',
  'tipo': 'Bearer',
  'expiraEn': DateTime.now()
      .toUtc()
      .add(Duration(seconds: seconds))
      .toIso8601String(),
  'usuarioId': 42,
  'rol': 'PROPIETARIO',
});

void main() {
  testWidgets(
    'Registro confirmado → login con correo precargado → sesión → logout',
    (tester) async {
      final requests = <http.Request>[];
      await registration.openRegistration(
        tester,
        client: MockClient((request) async {
          requests.add(request);
          expect(request.headers['Authorization'], isNull);
          final data = jsonDecode(request.body) as Map<String, dynamic>;
          if (request.url.path == '/api/usuarios/registro') {
            expect(data['apellidoPaterno'], 'Pérez');
            expect(data.containsKey('passwordConfirmation'), isFalse);
            return http.Response('{"id":42,"correo":"maria@ejemplo.com"}', 201);
          }
          expect(request.url.path, '/api/auth/login');
          expect(data, {
            'correo': 'maria@ejemplo.com',
            'password': 'Registro123',
          });
          return http.Response(sessionResponse(), 200);
        }),
      );
      for (final entry in {
        'name': 'María',
        'paternalSurname': 'Pérez',
        'email': 'maria@ejemplo.com',
        'phone': '4181234567',
        'password': 'Registro123',
        'passwordConfirmation': 'Registro123',
      }.entries) {
        await registration.fill(tester, entry.key, entry.value);
      }
      await registration.submit(tester);
      expect(find.text('Cuenta creada'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('login-email')))
            .controller!
            .text,
        'maria@ejemplo.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-password')),
        'Registro123',
      );
      await tester.tap(find.byKey(const ValueKey('login-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Sesión iniciada'), findsOneWidget);
      expect(find.text('test-jwt'), findsNothing);
      expect(requests, hasLength(2));
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Bienvenido de nuevo'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('login-password')))
            .controller!
            .text,
        isEmpty,
      );
    },
  );

  testWidgets('Evita envíos repetidos y cierra la sesión al vencer el JWT', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    var calls = 0;
    await login.openLogin(
      tester,
      client: MockClient((_) {
        calls++;
        return pending.future;
      }),
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-email')),
      'maria@ejemplo.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password')),
      'Registro123',
    );
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('login-submit')))
          .onPressed,
      isNull,
    );
    expect(calls, 1);
    pending.complete(http.Response(sessionResponse(seconds: 2), 200));
    await tester.pumpAndSettle();
    expect(find.text('Sesión iniciada'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    expect(
      find.text('Tu sesión expiró. Inicia sesión de nuevo.'),
      findsOneWidget,
    );
  });

  for (final status in [400, 401, 409, 500]) {
    test('Traduce HTTP $status sin exponer el cuerpo de error', () async {
      final api = ApiClient(
        baseUrl: 'http://localhost:8080',
        client: MockClient(
          (_) async =>
              http.Response('{"detail":"private server details"}', status),
        ),
      );
      addTearDown(api.close);
      await expectLater(
        HttpAuthenticationGateway(
          api,
        ).login(const LoginInput(email: 'a@b.com', password: 'valid123')),
        throwsA(
          isA<AuthenticationFailure>().having(
            (e) => e.message.contains('private'),
            'no internals',
            isFalse,
          ),
        ),
      );
    });
  }

  test(
    'Bearer solo en solicitudes autenticadas y respuestas de sesión inválidas se rechazan',
    () async {
      final requests = <http.Request>[];
      final api = ApiClient(
        baseUrl: 'http://localhost:8080',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{}', 200);
        }),
      )..bearerToken = 'test-token';
      addTearDown(api.close);
      await api.getJson('api/private');
      expect(requests.single.headers['Authorization'], 'Bearer test-token');
      await expectLater(
        HttpAuthenticationGateway(
          api,
        ).login(const LoginInput(email: 'a@b.com', password: 'valid123')),
        throwsA(isA<AuthenticationFailure>()),
      );
      expect(requests.last.headers['Authorization'], isNull);
    },
  );
}
