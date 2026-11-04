import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/features/notificaciones/application/contador_notificaciones.dart';
import 'package:punto_de_venta/features/notificaciones/infrastructure/boton_notificaciones.dart';

class IconoFalso implements IndicadorIcono {
  final valores = <int>[];

  @override
  Future<void> actualizar(int cantidad) async => valores.add(cantidad);
}

void main() {
  testWidgets('sincroniza el conteo y limpia el icono al cerrar sesión', (
    tester,
  ) async {
    var cantidad = 143;
    final api = ApiClient(
      baseUrl: 'http://localhost/',
      client: MockClient((request) async {
        expect(request.url.path, '/api/notificaciones/no-leidas/conteo');
        return http.Response('{"cantidad":$cantidad}', 200);
      }),
    );
    final icono = IconoFalso();
    final contador = ContadorNotificaciones(api, icono);
    contador.iniciar('sesion');
    await tester.runAsync(() => contador.actualizar());
    await tester.pump();
    expect(contador.value, 143);
    expect(icono.valores.last, 143);

    cantidad = 142;
    await tester.runAsync(() => contador.actualizar());
    await tester.pump();
    expect(contador.value, 142);
    expect(icono.valores.last, 142);

    contador.cerrarSesion();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(contador.value, isNull);
    expect(icono.valores.last, 0);
    contador.dispose();
    api.close();
  });

  testWidgets('descarta respuestas de una sesión cerrada', (tester) async {
    final respuesta = Completer<http.Response>();
    final api = ApiClient(
      baseUrl: 'http://localhost/',
      client: MockClient((_) => respuesta.future),
    );
    final icono = IconoFalso();
    final contador = ContadorNotificaciones(api, icono);
    contador.iniciar('sesion');
    await tester.pump();
    contador.cerrarSesion();
    respuesta.complete(http.Response('{"cantidad":5}', 200));
    await tester.pump();
    await tester.pump();
    expect(contador.value, isNull);
    expect(icono.valores.last, 0);
    contador.dispose();
    api.close();
  });

  testWidgets('la campana oculta cero y muestra 99+ para cantidades grandes', (
    tester,
  ) async {
    final conteo = ValueNotifier<int?>(0);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BotonNotificaciones(conteo: conteo, onPressed: () {}),
        ),
      ),
    );
    expect(find.text('0'), findsNothing);
    conteo.value = 2;
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
    conteo.value = 143;
    await tester.pump();
    expect(find.text('99+'), findsOneWidget);
    expect(find.byTooltip('Notificaciones: 143 sin leer'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    conteo.dispose();
  });
}
