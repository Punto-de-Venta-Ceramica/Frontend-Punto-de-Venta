import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../../../application/ports/outbound/almacen_imagenes.dart';
import '../../../../domain/imagen_producto.dart';
import 'compresor_imagen_movil.dart';

final class CompresorImagenPlataforma implements CompresorImagenProducto {
  const CompresorImagenPlataforma();

  static const _ladoMaximo = 1024;
  static const _calidad = 80;
  static const _compresorMovil = CompresorImagenMovil();

  bool get _esMovil =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<ArchivoImagenProducto> comprimir(ArchivoImagenProducto archivo) async {
    if (_esMovil) return _compresorMovil.comprimir(archivo);
    try {
      final original = img.decodeImage(archivo.bytes);
      if (original == null || original.width <= 0 || original.height <= 0) {
        throw const FormatException();
      }
      final escala = math.min(
        1.0,
        _ladoMaximo / math.max(original.width, original.height),
      );
      final ancho = math.max(1, (original.width * escala).round()).toInt();
      final alto = math.max(1, (original.height * escala).round()).toInt();
      final redimensionada = ancho == original.width && alto == original.height
          ? original
          : img.copyResize(original, width: ancho, height: alto);
      final comprimida = img.encodeJpg(redimensionada, quality: _calidad);
      if (comprimida.isEmpty ||
          math.max(redimensionada.width, redimensionada.height) > _ladoMaximo) {
        throw const FormatException();
      }
      return ArchivoImagenProducto(Uint8List.fromList(comprimida));
    } on Object {
      throw const ImagenProductoException(
        'No se pudo preparar la imagen. Intenta con otra foto.',
      );
    }
  }
}
