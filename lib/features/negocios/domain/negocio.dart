import 'dart:typed_data';

class Negocio {
  const Negocio({
    required this.id,
    required this.nombre,
    this.logo,
    this.eslogan,
  });
  final int id;
  final String nombre;
  final String? logo;

  /// Frase al pie de los tickets; null si no tiene.
  final String? eslogan;

  String get iniciales {
    final palabras = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where(
          (p) =>
              p.isNotEmpty &&
              !const [
                'de',
                'del',
                'la',
                'las',
                'el',
                'los',
              ].contains(p.toLowerCase()),
        );
    return palabras
        .take(2)
        .map((p) => String.fromCharCode(p.runes.first))
        .join()
        .toUpperCase();
  }
}

class LogoNegocio {
  LogoNegocio({required this.nombre, required List<int> contenido})
    : contenido = Uint8List.fromList(contenido).asUnmodifiableView() {
    if (contenido.isEmpty || contenido.length > maxBytes) {
      throw const NegocioFailure(
        'El logo debe tener contenido y no superar 2 MB.',
        fieldErrors: {'logo': 'Selecciona una imagen de hasta 2 MB.'},
      );
    }
    if (tipo == null) {
      throw const NegocioFailure(
        'Selecciona una imagen PNG o JPEG.',
        fieldErrors: {'logo': 'El logo debe ser PNG o JPEG.'},
      );
    }
  }
  static const maxBytes = 2 * 1024 * 1024;
  final String nombre;
  final Uint8List contenido;
  String? get tipo {
    if (contenido.length >= 8 &&
        contenido.take(8).join(',') == '137,80,78,71,13,10,26,10') {
      return 'image/png';
    }
    if (contenido.length >= 3 &&
        contenido[0] == 255 &&
        contenido[1] == 216 &&
        contenido[2] == 255) {
      return 'image/jpeg';
    }
    return null;
  }
}

class DatosNegocio {
  const DatosNegocio({
    required this.nombre,
    this.logo,
    this.eliminarLogo = false,
    this.eslogan = '',
  });
  final String nombre;
  final LogoNegocio? logo;
  final bool eliminarLogo;

  /// Vacío = sin eslogan.
  final String eslogan;
  static const maxEslogan = 150;

  Map<String, String> validar() {
    if (nombre.trim().isEmpty) {
      return {'nombre': 'Escribe el nombre de tu negocio.'};
    }
    if (nombre.length > 150) {
      return {'nombre': 'El nombre no debe superar 150 caracteres.'};
    }
    if (RegExp(r'[\x00-\x1F\x7F-\x9F]').hasMatch(nombre)) {
      return {
        'nombre': 'No se permiten saltos de línea ni caracteres de control.',
      };
    }
    if (eslogan.trim().length > maxEslogan) {
      return {'eslogan': 'El eslogan no debe superar $maxEslogan caracteres.'};
    }
    if (RegExp(r'[\x00-\x1F\x7F-\x9F]').hasMatch(eslogan)) {
      return {
        'eslogan': 'No se permiten saltos de línea ni caracteres de control.',
      };
    }
    if (logo != null && eliminarLogo) {
      return {'logo': 'Selecciona o elimina el logo, una acción a la vez.'};
    }
    return {};
  }
}

class NegocioFailure implements Exception {
  const NegocioFailure(
    this.message, {
    this.fieldErrors = const {},
    this.sesionExpirada = false,
  });
  final String message;
  final Map<String, String> fieldErrors;
  final bool sesionExpirada;
}
