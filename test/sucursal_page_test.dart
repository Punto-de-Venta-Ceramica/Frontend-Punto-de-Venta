import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/sucursal/application/ports/inbound/gestion_sucursales_use_case.dart';
import 'package:punto_de_venta/features/sucursal/domain/sucursal.dart';
import 'package:punto_de_venta/features/sucursal/infrastructure/adapters/inbound/flutter/sucursales_page.dart';

const centro = Sucursal(
  id: 1,
  negocioId: 2,
  nombre: 'Sucursal Centro',
  descripcion: 'Local de venta y atención a clientes.',
  ciudad: 'Dolores Hidalgo',
  calle: 'Calle Hidalgo 18',
  codigoPostal: '37800',
);
const norte = Sucursal(
  id: 3,
  negocioId: 2,
  nombre: 'Sucursal Norte',
  ciudad: 'Dolores Hidalgo',
  calle: 'Av. de los Héroes 24',
  codigoPostal: '37800',
);

class GestionFake implements GestionSucursalesUseCase {
  List<Sucursal> filas = [centro, norte];
  List<NegocioSucursal> listaNegocios = [
    const NegocioSucursal(id: 2, nombre: 'Cerámica del Centro'),
  ];
  SucursalFailure? fallo;
  Completer<Sucursal>? pendiente;
  int creadas = 0;
  int eliminadas = 0;
  @override
  Future<List<NegocioSucursal>> negocios() async => listaNegocios;
  @override
  Future<List<Sucursal>> listar(int negocioId) async =>
      filas.where((s) => s.negocioId == negocioId).toList();
  @override
  Future<Sucursal> crear(int negocioId, DatosSucursal datos) async {
    creadas++;
    if (fallo != null) throw fallo!;
    if (pendiente != null) return pendiente!.future;
    return Sucursal(
      id: 9,
      negocioId: negocioId,
      nombre: datos.nombre,
      descripcion: datos.descripcion,
      ciudad: datos.ciudad,
      calle: datos.calle,
      codigoPostal: datos.codigoPostal,
    );
  }

  @override
  Future<Sucursal> editar(int id, DatosSucursal datos) async {
    if (fallo != null) throw fallo!;
    return Sucursal(
      id: id,
      negocioId: 2,
      nombre: datos.nombre,
      descripcion: datos.descripcion,
      ciudad: centro.ciudad,
      calle: centro.calle,
      codigoPostal: centro.codigoPostal,
    );
  }

  @override
  Future<void> eliminar(int id) async {
    eliminadas++;
    if (fallo != null) throw fallo!;
  }
}

const captureKey = ValueKey('sucursal-captura');
Future<void> abrir(
  WidgetTester tester,
  GestionFake gestion, {
  Size size = const Size(430, 932),
  double scale = 1,
  VoidCallback? expirada,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final font = FontLoader('Inter')
    ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
  await font.load();
  final iconos = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await iconos.load();
  await tester.pumpWidget(
    RepaintBoundary(
      key: captureKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: BarroTheme.data,
        home: SucursalesPage(
          gestion: gestion,
          onSesionExpirada: expirada ?? () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> pulsar(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> rellenar(WidgetTester tester, String campo, String texto) async {
  final finder = find.byKey(ValueKey('sucursal-$campo'));
  await tester.ensureVisible(finder);
  await tester.enterText(finder, texto);
  await tester.pumpAndSettle();
}

Future<void> captura(WidgetTester tester, String nombre) async {
  if (!const bool.fromEnvironment('WRITE_SUCURSAL_PREVIEWS')) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(captureKey),
    );
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/sucursal-previews').createSync(recursive: true);
    File(
      'build/sucursal-previews/$nombre.png',
    ).writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  testWidgets('El diálogo de eliminación se puede usar con texto ampliado', (
    tester,
  ) async {
    await abrir(tester, GestionFake(), size: const Size(320, 568), scale: 1.4);
    await pulsar(tester, find.text('Editar').first);
    await pulsar(tester, find.text('Eliminar sucursal'));
    expect(tester.takeException(), isNull);
    await pulsar(
      tester,
      find.descendant(of: find.byType(Dialog), matching: find.text('Cancelar')),
    );
    expect(find.text('Editar sucursal'), findsOneWidget);
  });

  testWidgets('Lista con logo original, registro validado y éxito confirmado', (
    tester,
  ) async {
    final gestion = GestionFake();
    await abrir(tester, gestion);
    expect(find.text('2 sucursales registradas'), findsOneWidget);
    expect(find.byType(SvgPicture), findsOneWidget);
    await captura(tester, 'lista');
    await pulsar(tester, find.text('+ Registrar sucursal'));
    await captura(tester, 'registro');
    await pulsar(tester, find.byKey(const ValueKey('sucursal-guardar')));
    expect(find.text('Este campo es obligatorio.'), findsNWidgets(4));
    expect(gestion.creadas, 0);
    for (final e in {
      'nombre': 'Sucursal Sur',
      'descripcion': 'Local de venta',
      'ciudad': 'Dolores Hidalgo',
      'calle': 'Héroes 24',
      'codigoPostal': '37800',
    }.entries) {
      await rellenar(tester, e.key, e.value);
    }
    await pulsar(tester, find.byKey(const ValueKey('sucursal-guardar')));
    expect(find.text('Sucursal registrada correctamente.'), findsOneWidget);
    expect(find.text('3 sucursales registradas'), findsOneWidget);
    expect(gestion.creadas, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Edición restringida, cancelar borrado y eliminación confirmada',
    (tester) async {
      final gestion = GestionFake();
      await abrir(tester, gestion);
      await pulsar(tester, find.text('Editar').first);
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const ValueKey('sucursal-ciudad')),
                matching: find.byType(TextField),
              ),
            )
            .readOnly,
        true,
      );
      await captura(tester, 'edicion');
      await rellenar(tester, 'nombre', 'Sucursal Principal');
      await pulsar(tester, find.byKey(const ValueKey('sucursal-guardar')));
      expect(find.text('Cambios guardados correctamente.'), findsOneWidget);
      await captura(tester, 'guardada');
      await pulsar(tester, find.text('Editar').first);
      await pulsar(tester, find.text('Eliminar sucursal'));
      await captura(tester, 'confirmacion');
      await pulsar(
        tester,
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Cancelar'),
        ),
      );
      expect(gestion.eliminadas, 0);
      await pulsar(tester, find.text('Eliminar sucursal'));
      await pulsar(
        tester,
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Eliminar sucursal'),
        ),
      );
      expect(gestion.eliminadas, 1);
      expect(find.text('Sucursal eliminada correctamente.'), findsOneWidget);
      expect(find.text('1 sucursal registrada'), findsOneWidget);
      await captura(tester, 'eliminada');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Un conflicto al eliminar conserva la sucursal y muestra el error',
    (tester) async {
      final gestion = GestionFake()
        ..fallo = const SucursalFailure('Hay registros relacionados.');
      await abrir(tester, gestion);
      await pulsar(tester, find.text('Editar').first);
      await pulsar(tester, find.text('Eliminar sucursal'));
      await pulsar(
        tester,
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Eliminar sucursal'),
        ),
      );
      expect(find.text('Hay registros relacionados.'), findsOneWidget);
      expect(find.text('Sucursal eliminada correctamente.'), findsNothing);
      expect(find.text('Editar sucursal'), findsOneWidget);
    },
  );
  testWidgets(
    'Negocio sin sucursales y sin negocios son estados reales vacíos',
    (tester) async {
      final gestion = GestionFake()..filas = [];
      await abrir(tester, gestion);
      expect(find.textContaining('Registra la primera'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      gestion.listaNegocios = [];
      await abrir(tester, gestion);
      expect(find.textContaining('Aún no tienes negocios'), findsOneWidget);
      expect(find.text('+ Registrar sucursal'), findsNothing);
    },
  );
  testWidgets(
    'Pantalla pequeña y texto ampliado, incluidos formulario y teclado',
    (tester) async {
      await abrir(
        tester,
        GestionFake(),
        size: const Size(320, 568),
        scale: 1.4,
      );
      expect(tester.takeException(), isNull);
      await pulsar(tester, find.text('+ Registrar sucursal'));
      await rellenar(tester, 'nombre', 'Norte');
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('sucursal-guardar')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
    },
  );
}
