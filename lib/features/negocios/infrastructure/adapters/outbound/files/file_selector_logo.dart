import 'package:file_selector/file_selector.dart';
import '../../../../application/ports/outbound/selector_logo.dart';
import '../../../../domain/negocio.dart';

class FileSelectorLogo implements SelectorLogo {
  const FileSelectorLogo();
  @override
  Future<LogoNegocio?> seleccionar() async {
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
      if (await archivo.length() > LogoNegocio.maxBytes) {
        throw const NegocioFailure(
          'El logo no debe superar 2 MB.',
          fieldErrors: {'logo': 'Selecciona una imagen de hasta 2 MB.'},
        );
      }
      return LogoNegocio(
        nombre: archivo.name,
        contenido: await archivo.readAsBytes(),
      );
    } on NegocioFailure {
      rethrow;
    } catch (_) {
      throw const NegocioFailure(
        'No se pudo abrir la imagen. Inténtalo de nuevo.',
      );
    }
  }
}
