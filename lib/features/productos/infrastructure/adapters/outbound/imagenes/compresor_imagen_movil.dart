import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../../../application/ports/outbound/almacen_imagenes.dart';
import '../../../../domain/imagen_producto.dart';

final class CompresorImagenMovil implements CompresorImagenProducto {
  const CompresorImagenMovil();

  static const _ladoMaximo = 1024;
  static const _calidad = 80;

  @override
  Future<ArchivoImagenProducto> comprimir(ArchivoImagenProducto archivo) async {
    try {
      final (ancho, alto) = await _dimensiones(archivo);
      final escala = math.min(1.0, _ladoMaximo / math.max(ancho, alto));
      /* El plugin conserva la proporción. Usar el lado menor como límite en
         ambos ejes evita depender de cómo el sistema interpreta la orientación EXIF. */
      final ladoMenor = math.max(1, (math.min(ancho, alto) * escala).floor());
      final bytes = await FlutterImageCompress.compressWithList(
        archivo.bytes,
        minWidth: ladoMenor,
        minHeight: ladoMenor,
        quality: _calidad,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
      if (bytes.isEmpty) throw const FormatException();
      final resultado = ArchivoImagenProducto(bytes);
      final (anchoFinal, altoFinal) = await _dimensiones(resultado);
      if (math.max(anchoFinal, altoFinal) > _ladoMaximo) {
        throw const FormatException();
      }
      return resultado;
    } on Exception {
      throw const ImagenProductoException(
        'No se pudo preparar la imagen. Intenta con otra foto.',
      );
    }
  }

  Future<(int, int)> _dimensiones(ArchivoImagenProducto archivo) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(archivo.bytes);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        return (descriptor.width, descriptor.height);
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
  }
}
