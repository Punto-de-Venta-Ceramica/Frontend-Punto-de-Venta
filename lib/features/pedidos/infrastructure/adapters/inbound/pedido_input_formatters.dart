import 'package:flutter/services.dart';

/// Reglas de captura para los campos del pedido.
class PedidoInputFormatters {
  PedidoInputFormatters._();

  static final _nombreCaracter = RegExp(r"[\p{L}\p{M} '’\-]", unicode: true);
  static final _nombreCompleto = RegExp(
    r"^[\p{L}\p{M}]+(?:[ '’\-][\p{L}\p{M}]+)*$",
    unicode: true,
  );
  static final _importeParcial = RegExp(r'^\d{1,16}(?:[.,]\d{0,2})?$');
  static final _importeCompleto = RegExp(r'^\d{1,16}(?:[.,]\d{1,2})?$');

  static String limpiarEspacios(String texto) =>
      texto.replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _limpiarMientrasEscribe(String texto) =>
      texto.replaceAll(RegExp(r'\s+'), ' ').replaceFirst(RegExp(r'^ +'), '');

  static final TextInputFormatter espacios = TextInputFormatter.withFunction((
    anterior,
    nuevo,
  ) {
    if (nuevo.composing.isValid && !nuevo.composing.isCollapsed) return nuevo;
    final limpio = _limpiarMientrasEscribe(nuevo.text);
    if (limpio == nuevo.text) return nuevo;
    int posicion(int offset) => _limpiarMientrasEscribe(
      nuevo.text.substring(0, offset.clamp(0, nuevo.text.length)),
    ).length;
    return nuevo.copyWith(
      text: limpio,
      selection: nuevo.selection.isValid
          ? TextSelection(
              baseOffset: posicion(nuevo.selection.baseOffset),
              extentOffset: posicion(nuevo.selection.extentOffset),
              affinity: nuevo.selection.affinity,
              isDirectional: nuevo.selection.isDirectional,
            )
          : TextSelection.collapsed(offset: limpio.length),
      composing: TextRange.empty,
    );
  });

  static List<TextInputFormatter> get nombre => [
    espacios,
    FilteringTextInputFormatter.allow(_nombreCaracter),
    espacios,
  ];

  static List<TextInputFormatter> get texto => [
    espacios,
    FilteringTextInputFormatter.deny(RegExp(r'[\x00-\x1F\x7F-\x9F]')),
    espacios,
  ];

  static List<TextInputFormatter> get telefono => [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(10),
  ];

  static List<TextInputFormatter> get cantidad => [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(10),
  ];

  static List<TextInputFormatter> get dinero => [
    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
    TextInputFormatter.withFunction((anterior, nuevo) {
      if (nuevo.composing.isValid && !nuevo.composing.isCollapsed) return nuevo;
      return nuevo.text.isEmpty || _importeParcial.hasMatch(nuevo.text)
          ? nuevo
          : anterior;
    }),
  ];

  static String? validarNombre(String? valor) {
    final limpio = limpiarEspacios(valor ?? '');
    if (limpio.isEmpty) return 'El nombre del cliente es obligatorio.';
    if (!_nombreCompleto.hasMatch(limpio)) {
      return 'Ingresa un nombre válido, sin números.';
    }
    return null;
  }

  static String? validarTelefono(String? valor) =>
      RegExp(r'^[0-9]{10}$').hasMatch(valor ?? '')
      ? null
      : 'El teléfono debe contener exactamente 10 dígitos.';

  static String? validarCantidad(String? valor) {
    final cantidad = int.tryParse(valor ?? '');
    return cantidad == null || cantidad <= 0 || cantidad > 2147483647
        ? 'Ingresa una cantidad entera válida mayor que cero.'
        : null;
  }

  static String? validarDinero(String? valor) =>
      _importeCompleto.hasMatch(valor ?? '')
      ? null
      : 'Ingresa un importe válido con hasta dos decimales.';
}
