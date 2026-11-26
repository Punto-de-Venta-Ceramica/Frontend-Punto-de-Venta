import 'dart:typed_data';

import '../../../../domain/ticket.dart';

/// Arma los bytes ESC/POS del ticket para una impresora de 58 mm
/// (384 puntos), como la POS-5890. Usa la fuente A (12x24 puntos, 32
/// columnas) con un interlineado corto para gastar menos rollo. La fuente B
/// se descartó: se ve mal y en esta impresora imprime '¥' en lugar de '$'.
class EscPosTicket {
  const EscPosTicket({this.columnas = 32, this.interlineado = 26});
  final int columnas;

  /// En puntos; la fuente A mide 24 de alto (el predeterminado es ~30).
  final int interlineado;

  static const _esc = 0x1B, _gs = 0x1D, _fs = 0x1C, _lf = 0x0A;

  List<int> codificar(Ticket ticket) {
    final b = BytesBuilder(copy: false)
      // Reinicia, sale del modo chino (si no, los acentos salen como
      // ideogramas) y elige la página de códigos 16 = WPC1252.
      ..add([_esc, 0x40])
      ..add([_fs, 0x2E])
      ..add([_esc, 0x74, 16])
      // Interlineado corto (ESC @ lo regresa al normal).
      ..add([_esc, 0x33, interlineado]);

    _alinear(b, 1);
    _negrita(b, true);
    _tamano(b, doble: true);
    for (final linea in envolver(ticket.negocio.toUpperCase(), columnas ~/ 2)) {
      _texto(b, linea);
    }
    _tamano(b, doble: false);
    _negrita(b, false);
    for (final linea in envolver('Sucursal: ${ticket.sucursal}', columnas)) {
      _texto(b, linea);
    }
    _salto(b);
    _negrita(b, true);
    _texto(b, ticket.tipo.titulo);
    _negrita(b, false);

    _alinear(b, 0);
    if (ticket.folio != null) {
      for (final linea in envolverEnGuiones('Folio: ${ticket.folio}')) {
        _texto(b, linea);
      }
    }
    _texto(b, fila(ticket.tipo.etiquetaFecha, formatoFecha(ticket.fecha)));
    final entrega = ticket.entrega;
    if (entrega != null) {
      _texto(b, fila('Entrega:', formatoDia(entrega)));
    }
    _texto(b, _separador);

    for (final linea in ticket.lineas) {
      for (final parte in envolver(linea.nombre, columnas)) {
        _texto(b, parte);
      }
      _texto(
        b,
        fila(
          '  ${linea.cantidad} x ${formatoDinero(linea.precioUnitario)}',
          formatoDinero(linea.importeBruto),
        ),
      );
      if (linea.descuento > 0) {
        final porcentaje = linea.porcentajeDescuento > 0
            ? ' ${_porcentaje(linea.porcentajeDescuento)}%'
            : '';
        _texto(
          b,
          fila('  Descuento$porcentaje', '-${formatoDinero(linea.descuento)}'),
        );
      }
    }
    _texto(b, _separador);

    _negrita(b, true);
    _tamano(b, alto: true);
    _texto(b, fila('TOTAL', formatoDinero(ticket.total)));
    _tamano(b, doble: false);
    _negrita(b, false);
    final pagado = ticket.pagado;
    if (pagado != null) {
      final saldo = ticket.total - pagado;
      _texto(b, fila('Pagado', formatoDinero(pagado)));
      _negrita(b, true);
      _texto(
        b,
        saldo > 0.004
            ? fila('Saldo pendiente', formatoDinero(saldo))
            : fila('Saldo pendiente', 'Liquidado'),
      );
      _negrita(b, false);
    }
    _texto(b, _separador);
    _salto(b);

    _alinear(b, 1);
    final eslogan = ticket.eslogan?.trim() ?? '';
    if (eslogan.isNotEmpty) {
      for (final linea in envolver(eslogan, columnas)) {
        _texto(b, linea);
      }
    }
    if (ticket.tipo == TipoTicket.comprobante) {
      for (final linea in envolver(
        'Presente este comprobante al recoger su pedido.',
        columnas,
      )) {
        _texto(b, linea);
      }
    }
    _texto(b, '¡Gracias por su compra!');
    _alinear(b, 0);

    // La POS-5890 no tiene cortador: se avanza el papel para arrancarlo.
    b.add([_esc, 0x64, 4]);
    return b.takeBytes();
  }

  String get _separador => '-' * columnas;

  /// [izquierda] y [derecha] en la misma línea; si no caben, la derecha
  /// baja a su propio renglón alineada al margen derecho.
  String fila(String izquierda, String derecha) {
    final espacio = columnas - izquierda.length - derecha.length;
    if (espacio >= 1) return '$izquierda${' ' * espacio}$derecha';
    final partes = envolver(izquierda, columnas);
    return [...partes, derecha.padLeft(columnas)].join('\n');
  }

  /// Parte [texto] por palabras en renglones de [ancho] columnas; corta las
  /// palabras más largas que el renglón.
  static List<String> envolver(String texto, int ancho) {
    final renglones = <String>[];
    var actual = '';
    for (var palabra in texto.trim().split(RegExp(r'\s+'))) {
      while (palabra.length > ancho) {
        if (actual.isNotEmpty) {
          renglones.add(actual);
          actual = '';
        }
        renglones.add(palabra.substring(0, ancho));
        palabra = palabra.substring(ancho);
      }
      if (palabra.isEmpty) continue;
      if (actual.isEmpty) {
        actual = palabra;
      } else if (actual.length + 1 + palabra.length <= ancho) {
        actual = '$actual $palabra';
      } else {
        renglones.add(actual);
        actual = palabra;
      }
    }
    if (actual.isNotEmpty || renglones.isEmpty) renglones.add(actual);
    return renglones;
  }

  /// Como [envolver], pero corta las palabras largas después de un guion
  /// (folios tipo UUID) en lugar de dejar una letra suelta.
  List<String> envolverEnGuiones(String texto) {
    final renglones = <String>[];
    var resto = texto.trim();
    while (resto.length > columnas) {
      var corte = resto.lastIndexOf(RegExp(r'[-\s]'), columnas - 1) + 1;
      if (corte <= 0) corte = columnas;
      renglones.add(resto.substring(0, corte).trimRight());
      resto = resto.substring(corte).trimLeft();
    }
    if (resto.isNotEmpty) renglones.add(resto);
    return renglones;
  }

  static String formatoDinero(double valor) {
    final centavos = (valor.abs() * 100).round();
    final enteros = (centavos ~/ 100).toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+$)'),
      (_) => ',',
    );
    final signo = valor < 0 ? '-' : '';
    return '$signo\$$enteros.${(centavos % 100).toString().padLeft(2, '0')}';
  }

  static String formatoFecha(DateTime fecha) {
    final f = fecha.toLocal();
    return '${formatoDia(f)} ${_dos(f.hour)}:${_dos(f.minute)}';
  }

  /// Solo el día: dd/mm/aaaa.
  static String formatoDia(DateTime fecha) {
    final f = fecha.toLocal();
    return '${_dos(f.day)}/${_dos(f.month)}/${f.year}';
  }

  static String _dos(int n) => n.toString().padLeft(2, '0');

  static String _porcentaje(double valor) => valor == valor.roundToDouble()
      ? valor.toInt().toString()
      : valor.toStringAsFixed(2);

  /// Texto en WPC1252: el rango latino (acentos, ñ, ¡, ¿) pasa tal cual, unos
  /// pocos símbolos tipográficos se traducen y lo demás se vuelve '?'.
  static List<int> cp1252(String texto) => [
    for (final rune in texto.runes)
      if (rune < 0x80 || (rune >= 0xA0 && rune <= 0xFF))
        rune
      else
        _cp1252Extra[rune] ?? 0x3F,
  ];

  static const _cp1252Extra = {
    0x20AC: 0x80, // €
    0x2026: 0x85, // …
    0x2018: 0x91, // ‘
    0x2019: 0x92, // ’
    0x201C: 0x93, // “
    0x201D: 0x94, // ”
    0x2022: 0x95, // •
    0x2013: 0x96, // –
    0x2014: 0x97, // —
  };

  void _texto(BytesBuilder b, String texto) {
    b.add(cp1252(texto));
    b.addByte(_lf);
  }

  void _salto(BytesBuilder b) => b.addByte(_lf);
  void _alinear(BytesBuilder b, int modo) => b.add([_esc, 0x61, modo]);
  void _negrita(BytesBuilder b, bool activa) =>
      b.add([_esc, 0x45, activa ? 1 : 0]);

  /// [doble]: doble ancho y alto. [alto]: solo doble alto (mantiene columnas).
  void _tamano(BytesBuilder b, {bool doble = false, bool alto = false}) =>
      b.add([_gs, 0x21, doble ? 0x11 : (alto ? 0x01 : 0x00)]);
}
