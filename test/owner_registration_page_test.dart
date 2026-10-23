import 'dart:io';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punto_de_venta/main.dart';

const _captureKey = ValueKey('registration-capture');

Future<void> openRegistration(
  WidgetTester tester, {
  Size size = const Size(390, 940),
  double textScale = 1,
  http.Client? client,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final font = FontLoader('Inter')
    ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
  await font.load();
  await tester.pumpWidget(
    RepaintBoundary(
      key: _captureKey,
      child: PuntoDeVentaApp(
        initialRoute: '/register',
        httpClient: client ?? MockClient((_) async => http.Response('{}', 500)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> fill(WidgetTester tester, String field, String value) async {
  final target = find.byKey(ValueKey(field));
  await tester.ensureVisible(target);
  await tester.enterText(target, value);
  await tester.pumpAndSettle();
}

Future<void> submit(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('create-account'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('WRITE_REGISTRATION_PREVIEWS')) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_captureKey),
    );
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/registration-previews')
      ..createSync(recursive: true);
    File(
      '${directory.path}/$name.png',
    ).writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  testWidgets('Estado inicial: siete campos y diseño sin errores', (
    tester,
  ) async {
    await openRegistration(tester);
    expect(find.byType(TextField), findsNWidgets(7));
    expect(find.text('Nombre válido.'), findsNothing);
    expect(find.text('Ingresa tu apellido paterno.'), findsNothing);
    expect(tester.takeException(), isNull);
    await capture(tester, 'registro-inicial');
  });

  testWidgets('Estado de validaciones de Figma y corrección en vivo', (
    tester,
  ) async {
    await openRegistration(tester, size: const Size(390, 1100));
    await fill(tester, 'name', 'Abraham');
    await fill(tester, 'maternalSurname', 'López');
    await fill(tester, 'email', 'abraham@');
    await fill(tester, 'phone', '418150');
    await fill(tester, 'password', '!!!!!');
    await fill(tester, 'passwordConfirmation', '!!!!!!');
    await submit(tester);
    expect(find.text('Nombre válido.'), findsOneWidget);
    expect(find.text('Ingresa tu apellido paterno.'), findsOneWidget);
    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    await capture(tester, 'registro-validaciones');
    await fill(tester, 'paternalSurname', 'Pérez');
    expect(find.text('Ingresa tu apellido paterno.'), findsNothing);
    await fill(tester, 'password', 'Registro123');
    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
    await fill(tester, 'passwordConfirmation', 'Registro123');
    expect(find.text('Las contraseñas no coinciden.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Valida al perder foco y alterna ambos ojos de forma independiente',
    (tester) async {
      await openRegistration(tester);
      await fill(tester, 'email', 'no-es-correo');
      await fill(tester, 'phone', '4181234567');
      expect(
        find.text('El correo electrónico no tiene un formato válido.'),
        findsOneWidget,
      );
      for (final field in ['password', 'passwordConfirmation']) {
        expect(
          tester.widget<TextField>(find.byKey(ValueKey(field))).obscureText,
          isTrue,
        );
        final eye = find.byKey(ValueKey('$field-visibility'));
        await tester.ensureVisible(eye);
        await tester.tap(eye);
        await tester.pump();
        expect(
          tester.widget<TextField>(find.byKey(ValueKey(field))).obscureText,
          isFalse,
        );
      }
    },
  );

  testWidgets('Un formulario válido no simula la creación de una cuenta', (
    tester,
  ) async {
    await openRegistration(tester);
    await fill(tester, 'name', 'María');
    await fill(tester, 'paternalSurname', 'Pérez');
    await fill(tester, 'email', 'maria@ejemplo.com');
    await fill(tester, 'phone', '4181234567');
    await fill(tester, 'password', 'Registro123');
    await fill(tester, 'passwordConfirmation', 'Registro123');
    await submit(tester);
    expect(find.textContaining('HTTP 500'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Permite desplazar el formulario en una pantalla pequeña', (
    tester,
  ) async {
    await openRegistration(tester, size: const Size(320, 568), textScale: 1.3);
    await submit(tester);
    expect(
      find.text('El nombre es obligatorio y no puede contener solo espacios.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
