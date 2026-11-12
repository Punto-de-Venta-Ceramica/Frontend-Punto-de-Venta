String _plural(int n, String singular, String plural) =>
    '$n ${n == 1 ? singular : plural}';

/// Descuento por cantidad de un negocio y los elementos del catálogo a los que
/// está asignado (productos, categorías y áreas).
class Descuento {
  const Descuento({
    required this.id,
    required this.nombre,
    required this.cantidadMinima,
    required this.porcentaje,
    required this.activo,
    this.cantidadMaxima,
    this.productoIds = const [],
    this.categoriaIds = const [],
    this.areaIds = const [],
  });

  final int id;
  final String nombre;
  final int cantidadMinima;

  /// Sin tope cuando es null.
  final int? cantidadMaxima;
  final double porcentaje;
  final bool activo;
  final List<int> productoIds;
  final List<int> categoriaIds;
  final List<int> areaIds;

  String get porcentajeTexto => porcentaje == porcentaje.roundToDouble()
      ? porcentaje.toStringAsFixed(0)
      : porcentaje.toString();

  String get rango => cantidadMaxima == null
      ? 'Desde $cantidadMinima piezas'
      : 'De $cantidadMinima a $cantidadMaxima piezas';

  String get resumen => '$porcentajeTexto % · $rango';

  bool get sinAsignar =>
      productoIds.isEmpty && categoriaIds.isEmpty && areaIds.isEmpty;

  /// Ej.: "2 productos · 1 categoría". Solo menciona lo que tiene asignado.
  String get asignacionTexto {
    if (sinAsignar) return 'Sin asignar';
    return [
      if (productoIds.isNotEmpty)
        _plural(productoIds.length, 'producto', 'productos'),
      if (categoriaIds.isNotEmpty)
        _plural(categoriaIds.length, 'categoría', 'categorías'),
      if (areaIds.isNotEmpty) _plural(areaIds.length, 'área', 'áreas'),
    ].join(' · ');
  }
}

/// A qué se puede asignar un descuento. [segmento] es el tramo de la ruta del API.
enum DestinoDescuento {
  producto('productos', 'producto', 'productos', 'Sin productos asignados.'),
  categoria(
    'categorias',
    'categoría',
    'categorías',
    'Sin categorías asignadas.',
  ),
  area('areas', 'área', 'áreas', 'Sin áreas asignadas.');

  const DestinoDescuento(
    this.segmento,
    this.singular,
    this.plural,
    this.textoVacio,
  );
  final String segmento;
  final String singular;
  final String plural;

  /// Texto cuando el descuento no tiene nada asignado de este tipo.
  final String textoVacio;
}

/// Producto, categoría o área del catálogo que puede recibir un descuento.
/// [contexto] ayuda a distinguirlos: la categoría de un producto o el área de
/// una categoría.
class ElementoCatalogo {
  const ElementoCatalogo({
    required this.id,
    required this.nombre,
    this.contexto = '',
  });
  final int id;
  final String nombre;
  final String contexto;
}

class CatalogoDescuento {
  const CatalogoDescuento({
    this.productos = const [],
    this.categorias = const [],
    this.areas = const [],
  });
  final List<ElementoCatalogo> productos;
  final List<ElementoCatalogo> categorias;
  final List<ElementoCatalogo> areas;

  List<ElementoCatalogo> de(DestinoDescuento destino) => switch (destino) {
    DestinoDescuento.producto => productos,
    DestinoDescuento.categoria => categorias,
    DestinoDescuento.area => areas,
  };
}

extension AsignacionesDescuento on Descuento {
  List<int> idsDe(DestinoDescuento destino) => switch (destino) {
    DestinoDescuento.producto => productoIds,
    DestinoDescuento.categoria => categoriaIds,
    DestinoDescuento.area => areaIds,
  };
}

/// Datos capturados en el formulario; los textos se validan antes de enviarlos.
class DatosDescuento {
  const DatosDescuento({
    required this.nombre,
    required this.cantidadMinima,
    required this.porcentaje,
    this.cantidadMaxima = '',
  });
  final String nombre;
  final String cantidadMinima;

  /// Vacío significa sin tope.
  final String cantidadMaxima;
  final String porcentaje;

  int? get cantidadMinimaNumero => int.tryParse(cantidadMinima.trim());
  int? get cantidadMaximaNumero => int.tryParse(cantidadMaxima.trim());
  double? get porcentajeNumero =>
      double.tryParse(porcentaje.trim().replaceAll(',', '.'));

  Map<String, String> validar() {
    final errores = <String, String>{};
    final nombreLimpio = nombre.trim();
    if (nombreLimpio.isEmpty) {
      errores['nombre'] = 'Escribe el nombre del descuento.';
    } else if (nombreLimpio.length > 120) {
      errores['nombre'] = 'No debe superar 120 caracteres.';
    } else if (RegExp(r'[\x00-\x1F\x7F-\x9F]').hasMatch(nombre)) {
      errores['nombre'] =
          'No se permiten saltos de línea ni caracteres de control.';
    }
    final minimo = cantidadMinimaNumero;
    if (minimo == null || minimo < 1) {
      errores['cantidadMinima'] = 'Indica al menos 1 pieza.';
    }
    if (cantidadMaxima.trim().isNotEmpty) {
      final maximo = cantidadMaximaNumero;
      if (maximo == null || maximo < 1) {
        errores['cantidadMaxima'] = 'Indica al menos 1 pieza o déjalo vacío.';
      } else if (minimo != null && minimo >= 1 && maximo < minimo) {
        errores['cantidadMaxima'] =
            'No puede ser menor que la cantidad mínima.';
      }
    }
    final p = porcentajeNumero;
    if (p == null || p <= 0 || p > 100) {
      errores['porcentaje'] = 'Usa un valor mayor que 0 y hasta 100.';
    } else if (!RegExp(
      r'^\d{1,3}([.,]\d{1,2})?$',
    ).hasMatch(porcentaje.trim())) {
      errores['porcentaje'] = 'Máximo 2 decimales.';
    }
    return errores;
  }
}

/// Descuento de un producto tal como se edita en su formulario: "a partir de N
/// piezas, P %". Si [original] es null todavía no existe en el servidor.
class LineaDescuento {
  LineaDescuento({
    this.original,
    this.cantidadMinima = '',
    this.porcentaje = '',
    this.activo = true,
  });

  factory LineaDescuento.desde(Descuento d) => LineaDescuento(
    original: d,
    cantidadMinima: '${d.cantidadMinima}',
    porcentaje: d.porcentajeTexto,
    activo: d.activo,
  );

  /// Última versión conocida en el servidor. El guardado la va actualizando, de
  /// modo que reintentar tras un fallo parcial no duplica lo ya creado.
  Descuento? original;
  String cantidadMinima;
  String porcentaje;
  bool activo;

  int? get id => original?.id;
  int? get cantidadMinimaNumero => int.tryParse(cantidadMinima.trim());
  double? get porcentajeNumero =>
      double.tryParse(porcentaje.trim().replaceAll(',', '.'));
}

/// Descuentos que recibe un producto por asignación directa. Los [propios]
/// existen solo para él y se editan desde su formulario; los [compartidos] se
/// administran en el módulo de Descuentos.
class DescuentosDeProducto {
  const DescuentosDeProducto({this.propios = const [], this.compartidos = 0});
  final List<Descuento> propios;
  final int compartidos;
}

/// Errores por posición de la lista: `{0: {'cantidadMinima': '...'}}`.
Map<int, Map<String, String>> validarLineasDescuento(
  List<LineaDescuento> lineas,
) {
  final errores = <int, Map<String, String>>{};
  final vistas = <int, int>{};
  for (final (i, linea) in lineas.indexed) {
    final campos = DatosDescuento(
      nombre: 'descuento',
      cantidadMinima: linea.cantidadMinima,
      porcentaje: linea.porcentaje,
    ).validar()..remove('nombre');
    final minimo = linea.cantidadMinimaNumero;
    if (!campos.containsKey('cantidadMinima') && minimo != null) {
      if (vistas.containsKey(minimo)) {
        campos['cantidadMinima'] = 'Ya hay un descuento desde $minimo piezas.';
      }
      vistas[minimo] = i;
    }
    if (campos.isNotEmpty) errores[i] = campos;
  }
  return errores;
}

/// Resultado de guardar, activar/desactivar o eliminar desde el formulario.
class ResultadoDescuento {
  const ResultadoDescuento({
    required this.mensaje,
    this.descuento,
    this.eliminado = false,
  });
  final String mensaje;
  final Descuento? descuento;
  final bool eliminado;
}

class DescuentoFailure implements Exception {
  const DescuentoFailure(
    this.message, {
    this.fieldErrors = const {},
    this.sesionExpirada = false,
  });
  final String message;
  final Map<String, String> fieldErrors;
  final bool sesionExpirada;
}
