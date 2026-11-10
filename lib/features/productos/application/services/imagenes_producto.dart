import '../../domain/imagen_producto.dart';
import '../ports/outbound/almacen_imagenes.dart';

final class ImagenesProducto {
  const ImagenesProducto({
    required SelectorImagenProducto selector,
    required CompresorImagenProducto compresor,
    required AlmacenImagenes almacen,
  }) : _selector = selector,
       _compresor = compresor,
       _almacen = almacen;

  final SelectorImagenProducto _selector;
  final CompresorImagenProducto _compresor;
  final AlmacenImagenes _almacen;

  Future<ArchivoImagenProducto?> tomarFoto() => _selector.tomarFoto();

  Future<ArchivoImagenProducto?> elegirImagen() => _selector.elegirImagen();

  Future<ArchivoImagenProducto?> recuperarSeleccionPendiente() =>
      _selector.recuperarSeleccionPendiente();

  Future<ImagenProductoSubida> subir(
    ArchivoImagenProducto archivo, {
    void Function(double fraccion)? alProgresar,
  }) async {
    final comprimido = await _compresor.comprimir(archivo);
    return _almacen.subir(comprimido, alProgresar: alProgresar);
  }
}
