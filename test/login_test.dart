import 'dart:io';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punto_de_venta/main.dart';
import 'package:punto_de_venta/features/login/application/services/validate_login.dart';
import 'package:punto_de_venta/features/login/domain/login_input.dart';

Future<void> openLogin(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
  http.Client? client,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await (FontLoader(
    'Inter',
  )..addFont(rootBundle.load('assets/fonts/Inter.ttf'))).load();
  await tester.pumpWidget(
    RepaintBoundary(
      key: ValueKey('login-capture'),
      child: PuntoDeVentaApp(
        httpClient: client ?? MockClient((_) async => http.Response('{}', 401)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test(
    'Login valida correo y presencia de contraseña sin exigir la política de registro',
    () {
      const useCase = ValidateLogin();
      expect(
        useCase
            .execute(
              const LoginInput(email: 'maria@ejemplo.com', password: 'abc'),
            )
            .isValid,
        isTrue,
      );
      final invalid = useCase.execute(
        const LoginInput(email: 'correo@', password: ''),
      );
      expect(invalid.emailError, isNotNull);
      expect(invalid.passwordError, 'La contraseña es obligatoria.');
    },
  );

  testWidgets(
    'Login inicial coincide con Figma y permite mostrar la contraseña',
    (tester) async {
      await openLogin(tester);
      expect(find.text('Bienvenido de nuevo'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('La contraseña es obligatoria.'), findsNothing);
      if (const bool.fromEnvironment('WRITE_LOGIN_PREVIEW')) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('login-capture')),
          );
          final screenshot = await boundary.toImage(pixelRatio: 1);
          final bytes = await screenshot.toByteData(
            format: ui.ImageByteFormat.png,
          );
          Directory('build/login-preview').createSync(recursive: true);
          File(
            'build/login-preview/login.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          screenshot.dispose();
        });
      }
      final password = find.byKey(const ValueKey('login-password'));
      await tester.enterText(password, 'secreto');
      expect(tester.widget<TextField>(password).obscureText, isTrue);
      await tester.tap(find.byKey(const ValueKey('login-password-visibility')));
      await tester.pump();
      expect(tester.widget<TextField>(password).obscureText, isFalse);
    },
  );

  testWidgets('Valida al enviar y al corregir; no simula una sesión', (
    tester,
  ) async {
    await openLogin(tester);
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();
    expect(find.text('La contraseña es obligatoria.'), findsOneWidget);
    expect(find.text('El correo electrónico es obligatorio.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('login-email')),
      'maria@ejemplo.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password')),
      'secreto',
    );
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
  });

  testWidgets('Navega a registro y vuelve al login', (tester) async {
    await openLogin(tester);
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Registro de propietario'), findsOneWidget);
    final link = find.text('Iniciar sesión');
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets(
    'Recuperación informa su disponibilidad y el login admite pantalla pequeña',
    (tester) async {
      await openLogin(tester, size: const Size(320, 568), textScale: 1.3);
      final recovery = find.text('¿Olvidaste tu contraseña?');
      await tester.ensureVisible(recovery);
      await tester.tap(recovery);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'La recuperación de contraseña estará disponible próximamente.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
