import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../application/ports/outbound/almacen_imagenes.dart';
import '../../../../domain/imagen_producto.dart';

final class SelectorImagenMovil implements SelectorImagenProducto {
  SelectorImagenMovil(this._picker);

  final ImagePicker _picker;
  static const _maxBytes = 20 * 1024 * 1024;

  bool get _esAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _esIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<ArchivoImagenProducto?> tomarFoto() =>
      _seleccionar(ImageSource.camera);

  @override
  Future<ArchivoImagenProducto?> elegirImagen() =>
      _seleccionar(ImageSource.gallery);

  Future<ArchivoImagenProducto?> _seleccionar(ImageSource fuente) async {
    if (!_esAndroid && !_esIos) {
      throw const ImagenProductoException(
        'La selección de imágenes de producto está disponible en Android e iOS.',
      );
    }
    try {
      final archivo = await _picker.pickImage(
        source: fuente,
        requestFullMetadata: false,
      );
      return await _leer(archivo);
    } on PlatformException catch (error) {
      throw _errorDeSeleccion(error);
    }
  }

  @override
  Future<ArchivoImagenProducto?> recuperarSeleccionPendiente() async {
    if (!_esAndroid) return null;
    try {
      final resultado = await _picker.retrieveLostData();
      final error = resultado.exception;
      if (error != null) throw error;
      return await _leer(resultado.file ?? resultado.files?.firstOrNull);
    } on PlatformException catch (error) {
      throw _errorDeSeleccion(error);
    }
  }

  Future<ArchivoImagenProducto?> _leer(XFile? archivo) async {
    if (archivo == null) return null;
    try {
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
        'No se pudo abrir la imagen elegida.',
      );
    }
  }

  ImagenProductoException _errorDeSeleccion(PlatformException error) =>
      switch (error.code) {
        'camera_access_denied' ||
        'camera_access_restricted' => const ImagenProductoException(
          'Revisa el acceso a la cámara en los ajustes del teléfono.',
        ),
        'photo_access_denied' ||
        'photo_access_restricted' => const ImagenProductoException(
          'Revisa el acceso a las fotos en los ajustes del teléfono.',
        ),
        'no_available_camera' => const ImagenProductoException(
          'No hay una cámara disponible. Puedes elegir una imagen.',
        ),
        _ => const ImagenProductoException(
          'No se pudo obtener la imagen. Inténtalo de nuevo.',
        ),
      };
}
