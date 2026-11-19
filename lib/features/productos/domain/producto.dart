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

/// Escalón de descuento por cantidad vigente para el producto.
class DescuentoProducto {
  const DescuentoProducto({
    required this.cantidadMinima,
    required this.porcentaje,
    this.cantidadMaxima,
  });
  final int cantidadMinima;

  /// Sin tope cuando es null.
  final int? cantidadMaxima;
  final double porcentaje;

  String get porcentajeTexto => porcentaje == porcentaje.roundToDouble()
      ? porcentaje.toStringAsFixed(0)
      : porcentaje.toString();

  /// Ej.: "10 % de 5 a 10 piezas" o "15 % desde 21 piezas".
  String get resumen => cantidadMaxima == null
      ? '$porcentajeTexto % desde $cantidadMinima piezas'
      : '$porcentajeTexto % de $cantidadMinima a $cantidadMaxima piezas';
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
    this.categoriaId,
    this.categoriaNombre,
    this.areaId,
    this.areaNombre,
    this.descuentos = const [],
    this.imagenUrl,
    this.imagenPublicId,
    this.existencias = const [],
  });
  final int id;
  final String nombre;
  final double precio;

  /// Categoría y área: solo vienen en el detalle del producto, no en el listado.
  final int? categoriaId;
  final String? categoriaNombre;
  final int? areaId;
  final String? areaNombre;

  /// Escalones vigentes, ordenados por cantidad mínima (solo en el detalle).
  final List<DescuentoProducto> descuentos;
  final String? imagenUrl;
  final String? imagenPublicId;
  final List<ExistenciaSucursal> existencias;

  int get existenciaTotal => existencias.fold(0, (a, e) => a + e.existencia);

  /// "Área · Categoría" cuando el detalle ya las trae; vacío en caso contrario.
  String get clasificacion => [?areaNombre, ?categoriaNombre].join(' · ');

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
    categoriaNombre: categoriaNombre,
    areaId: areaId,
    areaNombre: areaNombre,
    descuentos: descuentos,
    imagenUrl: imagenUrl,
    imagenPublicId: imagenPublicId,
    existencias: existencias,
  );
}

/// Filtros del listado; se aplican en el servidor para que la paginación sea correcta.
class FiltroProductos {
  const FiltroProductos({
    this.areaId,
    this.categoriaId,
    this.buscar = '',
    this.sucursalId,
    this.precioMinimo,
    this.precioMaximo,
  });
  final int? areaId;
  final int? categoriaId;
  final String buscar;
  final int? sucursalId;

  /// Rango de precio inclusivo; cualquiera de los extremos es opcional.
  final double? precioMinimo;
  final double? precioMaximo;

  FiltroProductos copiarCon({
    int? areaId,
    int? categoriaId,
    String? buscar,
    bool limpiarArea = false,
    bool limpiarCategoria = false,
  }) => FiltroProductos(
    areaId: limpiarArea ? null : (areaId ?? this.areaId),
    categoriaId: limpiarCategoria ? null : (categoriaId ?? this.categoriaId),
    buscar: buscar ?? this.buscar,
    sucursalId: sucursalId,
    precioMinimo: precioMinimo,
    precioMaximo: precioMaximo,
  );
}

/// Una página del listado (pagina empieza en 0).
class PaginaProductos {
  const PaginaProductos({
    required this.productos,
    required this.pagina,
    required this.ultima,
    required this.total,
  });
  final List<Producto> productos;
  final int pagina;
  final bool ultima;
  final int total;
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
    this.imagenUrl,
    this.imagenPublicId,
    this.cantidadMinima = '',
    this.porcentaje = '',
    this.existencias = const [],
  });
  final String nombre;
  final String precio;
  final int? categoriaId;
  final String? imagenUrl;
  final String? imagenPublicId;
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
