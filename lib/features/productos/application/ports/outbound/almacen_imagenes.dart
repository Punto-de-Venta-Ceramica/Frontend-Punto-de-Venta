import '../../../domain/imagen_producto.dart';

abstract interface class AlmacenImagenes {
  /// [alProgresar] informa la fracción del cuerpo multipart enviada (0 a 1).
  /// La subida solo se considera exitosa cuando el Future devuelve el resultado.
  Future<ImagenProductoSubida> subir(
    ArchivoImagenProducto archivo, {
    void Function(double fraccion)? alProgresar,
  });
}

abstract interface class CompresorImagenProducto {
  Future<ArchivoImagenProducto> comprimir(ArchivoImagenProducto archivo);
}

abstract interface class SelectorImagenProducto {
  Future<ArchivoImagenProducto?> tomarFoto();
  Future<ArchivoImagenProducto?> elegirImagen();
  Future<ArchivoImagenProducto?> recuperarSeleccionPendiente();
}
