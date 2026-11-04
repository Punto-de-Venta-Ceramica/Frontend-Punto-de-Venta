class NegocioCatalogo {
  const NegocioCatalogo({required this.id, required this.nombre});
  final int id;
  final String nombre;
}

class AreaCatalogo {
  const AreaCatalogo({
    required this.id,
    required this.negocioId,
    required this.nombre,
    this.descripcion = '',
  });
  final int id;
  final int negocioId;
  final String nombre;
  final String descripcion;
}

class CategoriaCatalogo {
  const CategoriaCatalogo({
    required this.id,
    required this.areaId,
    required this.nombre,
    this.descripcion = '',
  });
  final int id;
  final int areaId;
  final String nombre;
  final String descripcion;
}

class ResumenAreaCatalogo {
  const ResumenAreaCatalogo({
    required this.area,
    required this.numeroCategorias,
  });
  final AreaCatalogo area;
  final int numeroCategorias;
}

class DatosClasificacion {
  const DatosClasificacion({required this.nombre, this.descripcion = ''});
  final String nombre;
  final String descripcion;

  Map<String, String> validar() {
    if (nombre.trim().isEmpty) {
      return {'nombre': 'Escribe el nombre.'};
    }
    if (nombre.length > 100) {
      return {'nombre': 'El nombre no debe superar 100 caracteres.'};
    }
    if (RegExp(r'[\x00-\x1F\x7F-\x9F]').hasMatch(nombre)) {
      return {
        'nombre': 'No se permiten saltos de línea ni caracteres de control.',
      };
    }
    return {};
  }
}

class CatalogoFailure implements Exception {
  const CatalogoFailure(
    this.message, {
    this.fieldErrors = const {},
    this.sesionExpirada = false,
  });
  final String message;
  final Map<String, String> fieldErrors;
  final bool sesionExpirada;
}
