import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../application/ports/outbound/almacen_imagenes.dart';
import '../../../../domain/imagen_producto.dart';
import 'selector_imagen_movil.dart';

final class SelectorImagenPlataforma implements SelectorImagenProducto {
  SelectorImagenPlataforma(ImagePicker picker)
    : _movil = SelectorImagenMovil(picker);

  final SelectorImagenMovil _movil;
  static const _maxBytes = 20 * 1024 * 1024;

  bool get _esMovil =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<ArchivoImagenProducto?> tomarFoto() => _movil.tomarFoto();

  @override
  Future<ArchivoImagenProducto?> elegirImagen() =>
      _esMovil ? _movil.elegirImagen() : _elegirArchivo();

  Future<ArchivoImagenProducto?> _elegirArchivo() async {
    try {
      final archivo = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Imágenes PNG o JPEG',
            extensions: ['png', 'jpg', 'jpeg'],
            mimeTypes: ['image/png', 'image/jpeg'],
            uniformTypeIdentifiers: ['public.png', 'public.jpeg'],
          ),
        ],
      );
      if (archivo == null) return null;
      final longitud = await archivo.length();
      if (longitud <= 0 || longitud > _maxBytes) {
        throw const ImagenProductoException(
          'Elige una imagen que no esté vacía y que pese hasta 20 MB.',
        );
      }
      return ArchivoImagenProducto(await archivo.readAsBytes());
    } on ImagenProductoException {
      rethrow;
    } on Exception {
      throw const ImagenProductoException(
        'No se pudo abrir la imagen. Inténtalo de nuevo.',
      );
    }
  }

  @override
  Future<ArchivoImagenProducto?> recuperarSeleccionPendiente() =>
      _movil.recuperarSeleccionPendiente();
}
