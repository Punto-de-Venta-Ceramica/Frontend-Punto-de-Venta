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

  String get rango => textoRango(cantidadMinima, cantidadMaxima);

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
  const DescuentosDeProducto({
    this.propios = const [],
    this.compartidos = const [],
  });
  final List<Descuento> propios;
  final List<Descuento> compartidos;
}

/// Descuento compartido activo cuyo rango se cruza con el que tendrá la línea
/// al guardarse ([maximo] según [maximosDeLineas]). El servidor no admite dos
/// descuentos activos del mismo producto con rangos cruzados. Una línea
/// desactivada no choca con nada.
Descuento? compartidoQueSeCruza(
  LineaDescuento linea,
  int? maximo,
  List<Descuento> compartidos,
) {
  final minimo = linea.cantidadMinimaNumero;
  if (!linea.activo || minimo == null || minimo < 1) return null;
  for (final d in compartidos) {
    if (!d.activo) continue;
    final empiezaAntes = maximo == null || d.cantidadMinima <= maximo;
    final terminaDespues =
        d.cantidadMaxima == null || minimo <= d.cantidadMaxima!;
    if (empiezaAntes && terminaDespues) return d;
  }
  return null;
}

/// Mensaje breve de un cruce: "Se cruza con «Mayoreo» (de 10 a 20 piezas)."
String mensajeCruce(Descuento d) =>
    'Se cruza con «${d.nombre}» (${d.rango.toLowerCase()}).';

/// Errores por posición de la lista: `{0: {'cantidadMinima': '...'}}`.
/// Con [compartidos] también señala las líneas que chocarían con ellos.
Map<int, Map<String, String>> validarLineasDescuento(
  List<LineaDescuento> lineas, {
  List<Descuento> compartidos = const [],
}) {
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
  if (errores.isEmpty && compartidos.isNotEmpty) {
    final maximos = maximosDeLineas(lineas, compartidos: compartidos);
    for (final (i, linea) in lineas.indexed) {
      final cruce = compartidoQueSeCruza(linea, maximos[linea], compartidos);
      if (cruce != null) errores[i] = {'cantidadMinima': mensajeCruce(cruce)};
    }
  }
  return errores;
}

/// Hasta cuántas piezas aplica cada línea del formulario de producto (null = sin
/// tope). Las líneas son escalones "a partir de N": cada una termina donde
/// empieza la siguiente activa, así sus rangos nunca se cruzan (5–10, 11–20,
/// 21+). Un descuento [compartidos] activo que empiece después también la
/// corta (desde 2 + «Mayoreo» 10–20 → 2–9). Si el descuento ya tenía un tope
/// menor, se respeta. Requiere mínimos válidos y distintos (ver
/// [validarLineasDescuento]).
Map<LineaDescuento, int?> maximosDeLineas(
  List<LineaDescuento> lineas, {
  List<Descuento> compartidos = const [],
}) {
  final maximos = Map<LineaDescuento, int?>.identity();
  for (final linea in lineas) {
    final minimo = linea.cantidadMinimaNumero;
    if (minimo == null) continue;
    int? siguiente;
    for (final otra in lineas) {
      final m = otra.cantidadMinimaNumero;
      if (identical(otra, linea) || !otra.activo || m == null || m <= minimo) {
        continue;
      }
      if (siguiente == null || m < siguiente) siguiente = m;
    }
    for (final d in compartidos) {
      final m = d.cantidadMinima;
      if (!d.activo || m <= minimo) continue;
      if (siguiente == null || m < siguiente) siguiente = m;
    }
    final previo = linea.original?.cantidadMaxima;
    final previoValido = previo != null && previo >= minimo;
    if (siguiente == null) {
      maximos[linea] = previoValido ? previo : null;
    } else {
      final limite = siguiente - 1;
      maximos[linea] = previoValido && previo <= limite ? previo : limite;
    }
  }
  return maximos;
}

/// Texto breve del rango, p. ej. "De 5 a 10 piezas" o "Desde 21 piezas".
String textoRango(int minimo, int? maximo) =>
    maximo == null ? 'Desde $minimo piezas' : 'De $minimo a $maximo piezas';

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
    this.traslape = false,
  });
  final String message;
  final Map<String, String> fieldErrors;
  final bool sesionExpirada;

  /// El rango de piezas se cruza con otro descuento activo del mismo elemento.
  final bool traslape;
}
