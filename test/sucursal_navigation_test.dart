import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:punto_de_venta/main.dart';

void main() {
  for (final rechazar in [false, true]) {
    testWidgets(
      'Login → sucursales con JWT${rechazar ? ' → 401 vuelve al login' : ''}',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final requests = <http.Request>[];
        await tester.pumpWidget(
          PuntoDeVentaApp(
            httpClient: MockClient((r) async {
              requests.add(r);
              if (r.url.path == '/api/auth/login') {
                expect(r.headers['Authorization'], isNull);
                return http.Response(
                  jsonEncode({
                    'token': 'jwt-prueba',
                    'tipo': 'Bearer',
                    'usuarioId': 7,
                    'rol': 'PROPIETARIO',
                    'expiraEn': DateTime.now()
                        .toUtc()
                        .add(const Duration(minutes: 5))
                        .toIso8601String(),
                  }),
                  200,
                );
              }
              expect(r.headers['Authorization'], 'Bearer jwt-prueba');
              if (r.url.path == '/api/negocios') {
                return http.Response(
                  '[{"id":2,"nombre":"Ceramica del Centro"}]',
                  200,
                );
              }
              expect(r.url.path, '/api/sucursales/consultar');
              expect(r.method, 'POST');
              expect(jsonDecode(r.body), {'negocioId': 2});
              return http.Response(
                rechazar ? '{}' : '[]',
                rechazar ? 401 : 200,
              );
            }),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('login-email')),
          'propietario@example.com',
        );
        await tester.enterText(
          find.byKey(const ValueKey('login-password')),
          'Registro123',
        );
        await tester.tap(find.byKey(const ValueKey('login-submit')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Administrar sucursales'));
        await tester.pumpAndSettle();
        expect(requests, hasLength(3));
        expect(
          find.text(rechazar ? 'Bienvenido de nuevo' : 'Sucursales'),
          findsOneWidget,
        );
        expect(find.text('jwt-prueba'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
