import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:punto_de_venta/features/productos/application/ports/outbound/almacen_imagenes.dart';
import 'package:punto_de_venta/features/productos/application/services/imagenes_producto.dart';
import 'package:punto_de_venta/features/productos/domain/imagen_producto.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/outbound/imagenes/cloudinary_almacen_imagenes.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/outbound/imagenes/compresor_imagen_movil.dart';

const _url =
    'https://res.cloudinary.com/pruebas/image/upload/v1/productos/a.jpg';
const _respuesta = '{"secure_url":"$_url","public_id":"productos/a"}';

void main() {
  test(
    'sube JPEG multipart sin credenciales y devuelve el resultado',
    () async {
      final datos = Uint8List(180 * 1024)..setRange(0, 4, [255, 216, 255, 224]);
      final progreso = <double>[];
      final almacen = _almacen((solicitud) async {
        final cuerpo = String.fromCharCodes(solicitud.bodyBytes);
        expect(solicitud.method, 'POST');
        expect(
          solicitud.url.toString(),
          'https://api.cloudinary.com/v1_1/pruebas/image/upload',
        );
        expect(solicitud.headers['authorization'], isNull);
        expect(
          solicitud.headers['content-type'],
          startsWith('multipart/form-data; boundary='),
        );
        expect(cuerpo, contains('name="upload_preset"\r\n\r\npreset-test'));
        expect(cuerpo, contains('name="file"; filename="producto.jpg"'));
        expect(cuerpo, contains('content-type: image/jpeg'));
        expect(cuerpo, isNot(contains('api_secret')));
        expect(solicitud.bodyBytes, containsAllInOrder([255, 216, 255, 224]));
        return http.Response(_respuesta, 200);
      });

      final imagen = await almacen.subir(
        ArchivoImagenProducto(datos),
        alProgresar: progreso.add,
      );

      expect(imagen.url, _url);
      expect(imagen.publicId, 'productos/a');
      expect(progreso.first, 0);
      expect(progreso.last, 1);
      expect(progreso.any((p) => p > 0 && p < 1), isTrue);
      expect(progreso, orderedEquals(progreso.toList()..sort()));
    },
  );

  test('distingue rechazo HTTP, respuesta inválida y tiempo de espera', () async {
    final archivo = ArchivoImagenProducto(Uint8List.fromList([1, 2, 3]));
    final rechazo = _almacen((_) async => http.Response('{"error":{}}', 400));
    final insegura = _almacen(
      (_) async => http.Response(
        '{"secure_url":"http://res.cloudinary.com/pruebas/a.jpg","public_id":"a"}',
        200,
      ),
    );
    final sinId = _almacen(
      (_) async => http.Response('{"secure_url":"$_url"}', 200),
    );
    final conEspera = _almacen(
      (_) => Future(() => http.Response(_respuesta, 200)),
      timeout: Duration.zero,
    );

    await expectLater(rechazo.subir(archivo), throwsA(_conMensaje('rechazó')));
    await expectLater(insegura.subir(archivo), throwsA(_conMensaje('válidos')));
    await expectLater(sinId.subir(archivo), throwsA(_conMensaje('válidos')));
    await expectLater(conEspera.subir(archivo), throwsA(_conMensaje('tardó')));
  });

  test(
    'el servicio sube el archivo comprimido y conserva el resultado',
    () async {
      final original = ArchivoImagenProducto(Uint8List.fromList([1]));
      final comprimido = ArchivoImagenProducto(Uint8List.fromList([2]));
      final almacen = _AlmacenSimulado();
      final servicio = ImagenesProducto(
        selector: _SelectorSimulado(),
        compresor: _CompresorSimulado(comprimido),
        almacen: almacen,
      );

      final imagen = await servicio.subir(original);
      expect(almacen.archivo, same(comprimido));
      expect(imagen.publicId, 'productos/a');
    },
  );

  testWidgets('rechaza bytes que no representan una foto', (tester) async {
    final archivo = ArchivoImagenProducto(Uint8List.fromList([1, 2, 3]));
    await tester.runAsync(() async {
      await expectLater(
        const CompresorImagenMovil().comprimir(archivo),
        throwsA(_conMensaje('preparar la imagen')),
      );
    });
  });
}

Matcher _conMensaje(String texto) => isA<ImagenProductoException>().having(
  (error) => error.mensaje,
  'mensaje',
  contains(texto),
);

CloudinaryAlmacenImagenes _almacen(
  Future<http.Response> Function(http.Request) responder, {
  Duration timeout = const Duration(seconds: 5),
}) => CloudinaryAlmacenImagenes(
  cloudName: 'pruebas',
  uploadPreset: 'preset-test',
  crearCliente: () => MockClient(responder),
  timeout: timeout,
);

final class _SelectorSimulado implements SelectorImagenProducto {
  @override
  Future<ArchivoImagenProducto?> elegirImagen() async => null;

  @override
  Future<ArchivoImagenProducto?> tomarFoto() async => null;

  @override
  Future<ArchivoImagenProducto?> recuperarSeleccionPendiente() async => null;
}

final class _CompresorSimulado implements CompresorImagenProducto {
  _CompresorSimulado(this.resultado);

  final ArchivoImagenProducto resultado;

  @override
  Future<ArchivoImagenProducto> comprimir(
    ArchivoImagenProducto archivo,
  ) async => resultado;
}

final class _AlmacenSimulado implements AlmacenImagenes {
  ArchivoImagenProducto? archivo;

  @override
  Future<ImagenProductoSubida> subir(
    ArchivoImagenProducto archivo, {
    void Function(double)? alProgresar,
  }) async {
    this.archivo = archivo;
    return const ImagenProductoSubida(url: _url, publicId: 'productos/a');
  }
}
