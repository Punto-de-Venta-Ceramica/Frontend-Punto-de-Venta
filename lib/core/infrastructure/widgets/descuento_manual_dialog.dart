import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';

/// Resultado del diálogo: [porcentaje] null significa quitar el descuento.
typedef DescuentoManual = ({double? porcentaje});

final _formato = RegExp(r'^\d{0,3}([.,]\d{0,2})?$');

/// Porcentaje válido (1 a 100, máximo 2 decimales) o null. Mismas reglas que el servidor.
double? leerPorcentajeManual(String texto) {
  final limpio = texto.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d{1,3}(\.\d{1,2})?$').hasMatch(limpio)) return null;
  final valor = double.parse(limpio);
  return valor < 1 || valor > 100 ? null : valor;
}

String textoPorcentaje(num valor) =>
    valor.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

/// Pide el porcentaje de descuento de una línea. Devuelve null si se cancela.
Future<DescuentoManual?> pedirDescuentoManual(
  BuildContext context, {
  required String producto,
  num? actual,
  bool puedeQuitar = false,
}) => showDialog<DescuentoManual>(
  context: context,
  builder: (_) => _DialogoDescuento(
    producto: producto,
    actual: actual,
    puedeQuitar: puedeQuitar,
  ),
);

/// Arriba de este porcentaje se pide confirmar antes de aplicar.
const umbralDescuentoAlto = 60;

const _ambar = Color(0xFFB45309);
const _ambarSuave = Color(0xFFFFF4E0);

/// Pide confirmar un descuento mayor a [umbralDescuentoAlto]. Devuelve true
/// sin mostrar nada si el porcentaje no lo supera.
Future<bool> confirmarDescuentoAlto(
  BuildContext context,
  double porcentaje,
) async {
  if (porcentaje <= umbralDescuentoAlto) return true;
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (_) => _AlertaDescuentoAlto(porcentaje: porcentaje),
  );
  return confirmado ?? false;
}

class _AlertaDescuentoAlto extends StatelessWidget {
  const _AlertaDescuentoAlto({required this.porcentaje});

  final double porcentaje;

  @override
  Widget build(BuildContext context) {
    final texto = textoPorcentaje(porcentaje);
    final paga = textoPorcentaje(100 - porcentaje);
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        // Desplazable para pantallas bajas o con el teclado abierto.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF59E0B), BarroTheme.primary],
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        size: 36,
                        color: _ambar,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Descuento muy alto',
                      textAlign: TextAlign.center,
                      style: BarroTheme.type(
                        20,
                        26,
                        weight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _ambarSuave,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFFCD9A0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.sell_outlined,
                            size: 20,
                            color: _ambar,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$texto %',
                            style: BarroTheme.type(
                              26,
                              32,
                              weight: FontWeight.w800,
                              color: _ambar,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Supera el $umbralDescuentoAlto % recomendado. '
                      'El cliente pagará solo el $paga % del precio.',
                      textAlign: TextAlign.center,
                      style: BarroTheme.type(
                        14,
                        21,
                        color: BarroTheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Revisa que el porcentaje sea correcto antes de aplicarlo.',
                      textAlign: TextAlign.center,
                      style: BarroTheme.type(
                        13,
                        19,
                        weight: FontWeight.w600,
                        color: BarroTheme.text,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      key: const ValueKey('confirmar-descuento-alto'),
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.check_rounded),
                      label: Text('Sí, aplicar $texto %'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _ambar,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: BarroTheme.type(
                          14,
                          20,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      key: const ValueKey('revisar-descuento-alto'),
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BarroTheme.secondary,
                        side: const BorderSide(color: BarroTheme.border),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: BarroTheme.type(
                          14,
                          20,
                          weight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Revisar porcentaje'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Campo de porcentaje para formularios que ya tienen su propio botón de guardar.
TextInputFormatter get formatoPorcentajeManual =>
    TextInputFormatter.withFunction(
      (anterior, nuevo) => _formato.hasMatch(nuevo.text) ? nuevo : anterior,
    );

class _DialogoDescuento extends StatefulWidget {
  const _DialogoDescuento({
    required this.producto,
    required this.actual,
    required this.puedeQuitar,
  });

  final String producto;
  final num? actual;
  final bool puedeQuitar;

  @override
  State<_DialogoDescuento> createState() => _DialogoDescuentoState();
}

class _DialogoDescuentoState extends State<_DialogoDescuento> {
  late final _campo = TextEditingController(
    text: widget.actual == null ? '' : textoPorcentaje(widget.actual!),
  );

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final valor = leerPorcentajeManual(_campo.text);
    if (valor == null || !await confirmarDescuentoAlto(context, valor)) return;
    if (mounted) Navigator.of(context).pop((porcentaje: valor));
  }

  @override
  Widget build(BuildContext context) {
    final valido = leerPorcentajeManual(_campo.text) != null;
    return AlertDialog(
      title: const Text('Descuento'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.producto, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('campo-descuento-manual'),
            controller: _campo,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [formatoPorcentajeManual],
            decoration: InputDecoration(
              labelText: 'Porcentaje',
              suffixText: '%',
              errorText: _campo.text.trim().isEmpty || valido
                  ? null
                  : 'Escribe un porcentaje entre 1 y 100.',
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _guardar(),
          ),
        ],
      ),
      actions: [
        if (widget.puedeQuitar)
          TextButton(
            onPressed: () => Navigator.of(context).pop((porcentaje: null)),
            child: const Text('Quitar'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: valido ? _guardar : null,
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}
