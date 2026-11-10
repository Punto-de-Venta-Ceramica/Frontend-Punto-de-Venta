import 'dart:typed_data';

final class ArchivoImagenProducto {
  const ArchivoImagenProducto(this.bytes);

  final Uint8List bytes;
}

final class ImagenProductoSubida {
  const ImagenProductoSubida({required this.url, required this.publicId});

  final String url;
  final String publicId;
}

final class ImagenProductoException implements Exception {
  const ImagenProductoException(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}
