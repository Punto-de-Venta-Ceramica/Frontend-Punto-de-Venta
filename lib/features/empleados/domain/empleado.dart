class NegocioEmpleado {
  const NegocioEmpleado({required this.id, required this.nombre});
  final int id;
  final String nombre;
}

class SucursalEmpleado {
  const SucursalEmpleado({required this.id, required this.nombre});
  final int id;
  final String nombre;
}

class Empleado {
  const Empleado({
    required this.id,
    required this.negocioId,
    required this.nombre,
    this.apellidoP,
    this.apellidoM,
    required this.correoElectronico,
    this.sucursales = const [],
  });

  final int id;
  final int negocioId;
  final String nombre;
  final String? apellidoP;
  final String? apellidoM;
  final String correoElectronico;

  /// Sucursales en las que trabaja (puede ser más de una).
  final List<SucursalEmpleado> sucursales;

  bool get asignado => sucursales.isNotEmpty;

  /// Nombres de sus sucursales separados por coma (vacío si no tiene ninguna).
  String get sucursalNombre => sucursales.map((s) => s.nombre).join(', ');

  bool trabajaEn(int sucursalId) => sucursales.any((s) => s.id == sucursalId);

  String get nombreCompleto {
    final partes = [
      nombre.trim(),
      if (apellidoP != null && apellidoP!.trim().isNotEmpty) apellidoP!.trim(),
      if (apellidoM != null && apellidoM!.trim().isNotEmpty) apellidoM!.trim(),
    ];
    return partes.join(' ');
  }

  String get inicial {
    final n = nombre.trim();
    return n.isEmpty ? 'E' : n[0].toUpperCase();
  }

  Empleado copyWith({List<SucursalEmpleado>? sucursales}) => Empleado(
    id: id,
    negocioId: negocioId,
    nombre: nombre,
    apellidoP: apellidoP,
    apellidoM: apellidoM,
    correoElectronico: correoElectronico,
    sucursales: sucursales ?? this.sucursales,
  );
}

class EmpleadoCreado {
  const EmpleadoCreado({
    required this.id,
    required this.negocioId,
    required this.nombre,
    required this.correoElectronico,
    required this.passwordGenerada,
    this.sucursalNombre,
  });

  final int id;
  final int negocioId;
  final String nombre;
  final String correoElectronico;
  final String passwordGenerada;
  final String? sucursalNombre;
}

class NuevoEmpleado {
  const NuevoEmpleado({
    required this.negocioId,
    required this.nombre,
    this.apellidoP,
    this.apellidoM,
    required this.correoElectronico,
    this.sucursalId,
  });

  final int negocioId;
  final String nombre;
  final String? apellidoP;
  final String? apellidoM;
  final String correoElectronico;
  final int? sucursalId;

  Map<String, String> validar() {
    final errores = <String, String>{};
    if (nombre.trim().isEmpty) {
      errores['nombre'] = 'El nombre es obligatorio.';
    } else if (nombre.trim().length > 100) {
      errores['nombre'] = 'El nombre no puede tener más de 100 caracteres.';
    }

    if (correoElectronico.trim().isEmpty) {
      errores['correoElectronico'] = 'El correo electrónico es obligatorio.';
    } else if (!RegExp(
      r'^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    ).hasMatch(correoElectronico.trim())) {
      errores['correoElectronico'] = 'Escribe un correo electrónico válido.';
    }

    return errores;
  }
}

class EmpleadoFailure implements Exception {
  const EmpleadoFailure(
    this.message, {
    this.fieldErrors = const {},
    this.sesionExpirada = false,
  });

  final String message;
  final Map<String, String> fieldErrors;
  final bool sesionExpirada;

  @override
  String toString() => message;
}
