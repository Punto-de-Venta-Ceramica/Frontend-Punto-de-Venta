import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:punto_de_venta/features/authentication/domain/auth_session.dart';
import 'package:punto_de_venta/features/authentication/infrastructure/adapters/inbound/flutter/session_page.dart';
import 'package:punto_de_venta/features/login/infrastructure/adapters/inbound/flutter/login_page.dart';
import 'package:punto_de_venta/main.dart';
import 'memory_session_store.dart';

void main() {
  Future<void> abrir(WidgetTester tester, MemorySessionStore store) async {
    await tester.pumpWidget(
      PuntoDeVentaApp(
        sessionStore: store,
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('con sesión guardada la app entra sin pedir login', (
    tester,
  ) async {
    final ahora = DateTime.now();
    await abrir(
      tester,
      MemorySessionStore(
        AuthSession(
          token: 't',
          expiresAt: ahora.add(const Duration(minutes: 15)),
          refreshToken: 'r',
          refreshExpiresAt: ahora.add(const Duration(days: 20)),
          userId: 1,
          role: 'OTRO',
        ),
      ),
    );
    expect(find.byType(SessionPage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });

  testWidgets('sin sesión guardada muestra el login', (tester) async {
    await abrir(tester, MemorySessionStore());
    expect(find.byType(LoginPage), findsOneWidget);
  });
}
