import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punto_de_venta/features/authentication/domain/auth_session.dart';
import 'package:punto_de_venta/features/authentication/infrastructure/adapters/inbound/flutter/session_page.dart';
import 'package:punto_de_venta/features/negocios/infrastructure/adapters/inbound/flutter/widgets/negocios_scaffold.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_widgets.dart';
import 'package:punto_de_venta/features/areas_categorias/infrastructure/adapters/inbound/flutter/widgets/clasificacion_scaffold.dart';

void main() {
  testWidgets('muestra la marca y la campana en una pantalla estrecha', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final conteo = ValueNotifier<int?>(2);
    var abrioNotificaciones = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SessionPage(
          session: AuthSession(
            token: 'test',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
            refreshToken: 'test-refresh',
            refreshExpiresAt: DateTime.now().add(const Duration(days: 1)),
            userId: 1,
            role: 'PROPIETARIO',
          ),
          clearSession: () {},
          conteoNotificaciones: conteo,
          openNotifications: () => abrioNotificaciones = true,
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(tester.getTopLeft(find.byType(SvgPicture)).dy, 24);
    final marca = tester.widget<Text>(find.text('BarroControl'));
    expect(marca.style?.fontFamily, 'Inter');
    expect(marca.style?.fontWeight, FontWeight.w700);
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.byTooltip('Notificaciones: 2 sin leer'));
    expect(abrioNotificaciones, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    conteo.dispose();
  });

  testWidgets(
    'las cabeceras de negocio, catálogo y pedidos mantienen el margen superior',
    (tester) async {
      tester.view.physicalSize = const Size(376, 858);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final pantalla in <Widget>[
        const NegociosScaffold(children: []),
        const ProductoScaffold(children: []),
        const ClasificacionScaffold(negocio: 'Barro Centro', children: []),
      ]) {
        await tester.pumpWidget(MaterialApp(home: pantalla));
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.byType(SvgPicture)).dy,
          inInclusiveRange(24, 40),
          reason: '${pantalla.runtimeType}',
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}
