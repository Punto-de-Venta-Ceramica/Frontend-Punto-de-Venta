class NegocioProducto {
  const NegocioProducto({required this.id, required this.nombre});
  final int id;
  final String nombre;
}

class SucursalProducto {
  const SucursalProducto({required this.id, required this.nombre});
  final int id;
  final String nombre;
}

class AreaProducto {
  const AreaProducto({required this.id, required this.nombre});
  final int id;
  final String nombre;
}

class CategoriaProducto {
  const CategoriaProducto({
    required this.id,
    required this.areaId,
    required this.nombre,
  });
  final int id;
  final int areaId;
  final String nombre;
}

class DescuentoProducto {
  const DescuentoProducto({
    required this.cantidadMinima,
    required this.porcentaje,
  });
  final int cantidadMinima;
  final double porcentaje;

  String get porcentajeTexto => porcentaje == porcentaje.roundToDouble()
      ? porcentaje.toStringAsFixed(0)
      : porcentaje.toString();
  String get resumen => '$porcentajeTexto % desde $cantidadMinima piezas';
}

class ExistenciaSucursal {
  const ExistenciaSucursal({
    required this.inventarioId,
    required this.sucursalId,
    required this.sucursalNombre,
    required this.existencia,
  });

  /// Identificador del registro de inventario (producto en una sucursal).
  final int inventarioId;
  final int sucursalId;
  final String sucursalNombre;
  final int existencia;

  ExistenciaSucursal conExistencia(int existencia) => ExistenciaSucursal(
    inventarioId: inventarioId,
    sucursalId: sucursalId,
    sucursalNombre: sucursalNombre,
    existencia: existencia,
  );
}

class Producto {
  const Producto({
    required this.id,
    required this.nombre,
    required this.precio,
    required this.categoriaId,
    this.descuento,
    this.existencias = const [],
  });
  final int id;
  final String nombre;
  final double precio;
  final int categoriaId;
  final DescuentoProducto? descuento;
  final List<ExistenciaSucursal> existencias;

  int get existenciaTotal => existencias.fold(0, (a, e) => a + e.existencia);

  /// Solo la existencia de una sucursal (la gestión de productos es por sucursal).
  Producto soloSucursal(int sucursalId) => conExistencias([
    for (final e in existencias)
      if (e.sucursalId == sucursalId) e,
  ]);

  Producto conExistencias(List<ExistenciaSucursal> existencias) => Producto(
    id: id,
    nombre: nombre,
    precio: precio,
    categoriaId: categoriaId,
    descuento: descuento,
    existencias: existencias,
  );
}

class ExistenciaInicial {
  const ExistenciaInicial({required this.sucursalId, required this.existencia});
  final int sucursalId;
  final int existencia;
}

/// Datos capturados en el formulario; los textos se validan antes de enviarlos.
class DatosProducto {
  const DatosProducto({
    required this.nombre,
    required this.precio,
    required this.categoriaId,
    this.cantidadMinima = '',
    this.porcentaje = '',
    this.existencias = const [],
  });
  final String nombre;
  final String precio;
  final int? categoriaId;
  final String cantidadMinima;
  final String porcentaje;
  final List<ExistenciaInicial> existencias;

  double? get precioNumero =>
      double.tryParse(precio.trim().replaceAll(',', '.'));
  int? get cantidadMinimaNumero => int.tryParse(cantidadMinima.trim());
  double? get porcentajeNumero =>
      double.tryParse(porcentaje.trim().replaceAll(',', '.'));

  /// Sin descuento cuando el porcentaje está vacío o es 0.
  bool get tieneDescuento => (porcentajeNumero ?? 0) > 0;

  Map<String, String> validar() {
    final errores = <String, String>{};
    final nombreLimpio = nombre.trim();
    if (nombreLimpio.isEmpty) {
      errores['nombre'] = 'Escribe el nombre del producto.';
    } else if (nombreLimpio.length > 150) {
      errores['nombre'] = 'No debe superar 150 caracteres.';
    } else if (RegExp(r'[\x00-\x1F\x7F-\x9F]').hasMatch(nombre)) {
      errores['nombre'] =
          'No se permiten saltos de línea ni caracteres de control.';
    }
    final p = precioNumero;
    if (p == null || p <= 0) {
      errores['precio'] = 'Ingresa un precio mayor que cero.';
    } else if (!RegExp(r'^\d{1,10}([.,]\d{1,2})?$').hasMatch(precio.trim())) {
      errores['precio'] = 'Máximo 10 enteros y 2 decimales.';
    }
    if (categoriaId == null) {
      errores['categoriaId'] = 'Selecciona un área y una categoría.';
    }
    if (porcentaje.trim().isNotEmpty) {
      final d = porcentajeNumero;
      if (d == null || d < 0 || d > 100) {
        errores['porcentaje'] = 'Usa un valor de 0 a 100.';
      }
    }
    if (tieneDescuento) {
      final minimo = cantidadMinimaNumero;
      if (minimo == null || minimo < 1) {
        errores['cantidadMinima'] = 'Indica al menos 1 pieza.';
      }
    }
    return errores;
  }
}

class ProductoFailure implements Exception {
  const ProductoFailure(
    this.message, {
    this.fieldErrors = const {},
    this.sesionExpirada = false,
  });
  final String message;
  final Map<String, String> fieldErrors;
  final bool sesionExpirada;
}
