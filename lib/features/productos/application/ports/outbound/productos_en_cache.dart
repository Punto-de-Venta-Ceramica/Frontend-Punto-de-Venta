import '../../../domain/producto.dart';

/// Lo que la aplicación puede pedirle al caché local de productos.
abstract interface class ProductosEnCache {
  /// Último detalle conocido (producto y existencias), aunque pueda estar
  /// desactualizado; null si falta alguna de las dos partes.
  Producto? detalleGuardado(int id);

  /// Olvida todo lo guardado: la siguiente consulta irá al servidor.
  void descartar();
}
