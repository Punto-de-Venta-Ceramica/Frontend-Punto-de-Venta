import 'package:image_picker/image_picker.dart';

import '../application/services/imagenes_producto.dart';
import 'adapters/outbound/imagenes/cloudinary_almacen_imagenes.dart';
import 'adapters/outbound/imagenes/compresor_imagen_plataforma.dart';
import 'adapters/outbound/imagenes/selector_imagen_plataforma.dart';

ImagenesProducto crearImagenesProducto() => ImagenesProducto(
  selector: SelectorImagenPlataforma(ImagePicker()),
  compresor: const CompresorImagenPlataforma(),
  almacen: CloudinaryAlmacenImagenes(
    cloudName: const String.fromEnvironment(
      'CLOUDINARY_CLOUD_NAME',
      defaultValue: 'ecbb3tac',
    ),
    uploadPreset: const String.fromEnvironment(
      'CLOUDINARY_UPLOAD_PRESET',
      defaultValue: 'BarroControl',
    ),
  ),
);
