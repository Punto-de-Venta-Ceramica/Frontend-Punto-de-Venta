class NegocioSucursal {
  const NegocioSucursal({required this.id, required this.nombre});
  final int id;
  final String nombre;
}

class Sucursal {
  const Sucursal({
    required this.id,
    required this.negocioId,
    required this.nombre,
    this.descripcion = '',
    this.ciudad = '',
    this.calle = '',
    this.codigoPostal = '',
  });
  final int id;
  final int negocioId;
  final String nombre;
  final String descripcion;
  final String ciudad;
  final String calle;
  final String codigoPostal;
  bool get direccionPendiente =>
      ciudad.isEmpty || calle.isEmpty || codigoPostal.isEmpty;
  String get direccion => [
    if (calle.isNotEmpty) calle,
    if (codigoPostal.isNotEmpty) 'C.P. $codigoPostal',
  ].join(' · ');
}

class DatosSucursal {
  const DatosSucursal({
    required this.nombre,
    this.descripcion = '',
    this.ciudad = '',
    this.calle = '',
    this.codigoPostal = '',
  });
  final String nombre;
  final String descripcion;
  final String ciudad;
  final String calle;
  final String codigoPostal;

  Map<String, String> validar({required bool registro}) {
    final errores = <String, String>{};
    void texto(
      String campo,
      String valor,
      int maximo, {
      bool obligatorio = true,
    }) {
      if (obligatorio && valor.trim().isEmpty) {
        errores[campo] = 'Este campo es obligatorio.';
      } else if (valor.length > maximo) {
        errores[campo] = 'No debe superar $maximo caracteres.';
      } else if (RegExp(r'[\x00-\x1F\x7F-\x9F]').hasMatch(valor)) {
        errores[campo] =
            'No se permiten saltos de línea ni caracteres de control.';
      }
    }

    texto('nombre', nombre, 150);
    if (descripcion.length > 2000) {
      errores['descripcion'] = 'No debe superar 2000 caracteres.';
    } else if (RegExp(
      r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]',
    ).hasMatch(descripcion)) {
      errores['descripcion'] =
          'La descripción contiene caracteres no permitidos.';
    }
    if (registro) {
      texto('ciudad', ciudad, 120);
      texto('calle', calle, 200);
      if (codigoPostal.trim().isEmpty) {
        errores['codigoPostal'] = 'Este campo es obligatorio.';
      } else if (!RegExp(r'^[0-9]{5}$').hasMatch(codigoPostal)) {
        errores['codigoPostal'] = 'Escribe un código postal de 5 dígitos.';
      }
    }
    return errores;
  }
}

class SucursalFailure implements Exception {
  const SucursalFailure(
    this.message, {
    this.fieldErrors = const {},
    this.sesionExpirada = false,
  });
  final String message;
  final Map<String, String> fieldErrors;
  final bool sesionExpirada;
}
