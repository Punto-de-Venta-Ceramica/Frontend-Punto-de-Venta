import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';

/// Resultado de la hoja: [porcentaje] null significa quitar el descuento.
typedef DescuentoManual = ({double? porcentaje});

/// Arriba de este porcentaje se pide confirmar antes de aplicar.
const umbralDescuentoAlto = 60;

/// Porcentajes que se ofrecen con un toque.
const porcentajesRapidos = [5, 10, 15, 20, 25, 50];

const _ambar = Color(0xFFB45309);
const _ambarSuave = Color(0xFFFFF4E0);
const _verdeSuave = Color(0xFFE7F4EC);
const _rosaSuave = Color(0xFFF7E7DF);

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

String _dinero(num importe) => '\$${importe.toStringAsFixed(2)}';

/// Importe con el descuento aplicado, con el redondeo por línea del servidor.
num importeConDescuento(num bruto, num? porcentaje) {
  final centavos = BigInt.from((bruto * 100).round());
  final factor = BigInt.from(10000 - ((porcentaje ?? 0) * 100).round());
  return ((centavos * factor + BigInt.from(5000)) ~/ BigInt.from(10000))
          .toDouble() /
      100;
}

/// Campo de porcentaje para formularios que ya tienen su propio botón de guardar.
TextInputFormatter get formatoPorcentajeManual =>
    TextInputFormatter.withFunction(
      (anterior, nuevo) => _formato.hasMatch(nuevo.text) ? nuevo : anterior,
    );

/// Pide el porcentaje de descuento de una línea en una hoja inferior.
/// [importe] es el precio sin descuento de la línea, para mostrar el ahorro.
/// Devuelve null si se cancela.
Future<DescuentoManual?> pedirDescuentoManual(
  BuildContext context, {
  required String producto,
  num? actual,
  num? importe,
  bool puedeQuitar = false,
}) => showModalBottomSheet<DescuentoManual>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (_) => _HojaDescuento(
    producto: producto,
    actual: actual,
    importe: importe,
    puedeQuitar: puedeQuitar,
  ),
);

/// Pide confirmar un descuento mayor a [umbralDescuentoAlto]. Devuelve true
/// sin mostrar nada si el porcentaje no lo supera.
Future<bool> confirmarDescuentoAlto(
  BuildContext context,
  double porcentaje,
) async {
  if (porcentaje <= umbralDescuentoAlto) return true;
  final confirmado = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, _, _) => _AlertaDescuentoAlto(porcentaje: porcentaje),
    transitionBuilder: (_, animacion, _, hijo) {
      final curva = CurvedAnimation(
        parent: animacion,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: animacion,
        child: ScaleTransition(
          scale: Tween(begin: 0.85, end: 1.0).animate(curva),
          child: hijo,
        ),
      );
    },
  );
  return confirmado ?? false;
}

/// Accesos rápidos de porcentaje; resalta el que coincide con [seleccionado].
class ChipsPorcentaje extends StatelessWidget {
  const ChipsPorcentaje({
    required this.seleccionado,
    required this.onSeleccionar,
    super.key,
  });

  final double? seleccionado;
  final ValueChanged<int> onSeleccionar;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final valor in porcentajesRapidos)
        _ChipPorcentaje(
          valor: valor,
          activo: seleccionado == valor,
          onTap: () => onSeleccionar(valor),
        ),
    ],
  );
}

class _ChipPorcentaje extends StatelessWidget {
  const _ChipPorcentaje({
    required this.valor,
    required this.activo,
    required this.onTap,
  });

  final int valor;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: activo,
    child: Material(
      color: activo ? BarroTheme.primary : _rosaSuave,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        key: ValueKey('porcentaje-rapido-$valor'),
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minWidth: 56, minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Text(
            '$valor %',
            style: BarroTheme.type(
              14,
              20,
              weight: FontWeight.w700,
              color: activo ? Colors.white : BarroTheme.primary,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Resumen del ahorro: precio normal tachado, ahorro y precio final.
class ResumenDescuento extends StatelessWidget {
  const ResumenDescuento({
    required this.importe,
    required this.porcentaje,
    this.detalle,
    super.key,
  });

  /// Importe sin descuento.
  final num importe;
  final double? porcentaje;

  /// Línea opcional bajo "Precio normal", p. ej. "10 × $50.00 c/u".
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    final total = importeConDescuento(importe, porcentaje);
    final ahorro = importe - total;
    final conDescuento = porcentaje != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: conDescuento ? _verdeSuave : _rosaSuave,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sin descuento no se repite el importe: basta con el total.
          if (conDescuento) ...[
            _FilaResumen(
              icono: Icons.payments_outlined,
              etiqueta: 'Precio normal',
              detalle: detalle,
              valor: _dinero(importe),
              tachado: true,
            ),
            const SizedBox(height: 10),
            _FilaResumen(
              icono: Icons.sell_outlined,
              etiqueta: 'Ahorro (${textoPorcentaje(porcentaje!)} %)',
              valor: '−${_dinero(ahorro)}',
              color: BarroTheme.success,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0x2257423D)),
            ),
          ],
          Row(
            children: [
              if (!conDescuento) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.payments_outlined,
                    size: 17,
                    color: BarroTheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conDescuento ? 'Total con descuento' : 'Total',
                      style: BarroTheme.type(14, 20, weight: FontWeight.w700),
                    ),
                    if (!conDescuento && detalle != null)
                      Text(
                        detalle!,
                        style: BarroTheme.type(
                          12,
                          16,
                          color: BarroTheme.placeholder,
                        ),
                      ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (hijo, animacion) =>
                    ScaleTransition(scale: animacion, child: hijo),
                child: Text(
                  _dinero(total),
                  key: ValueKey(total),
                  style: BarroTheme.type(
                    24,
                    30,
                    weight: FontWeight.w800,
                    color: conDescuento
                        ? BarroTheme.success
                        : BarroTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilaResumen extends StatelessWidget {
  const _FilaResumen({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    this.detalle,
    this.tachado = false,
    this.color = BarroTheme.secondary,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;
  final String? detalle;
  final bool tachado;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(icono, size: 17, color: color),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              etiqueta,
              style: BarroTheme.type(
                13,
                18,
                weight: FontWeight.w600,
                color: color,
              ),
            ),
            if (detalle case final texto?)
              Text(
                texto,
                style: BarroTheme.type(12, 16, color: BarroTheme.placeholder),
              ),
          ],
        ),
      ),
      Text(
        valor,
        style: BarroTheme.type(
          14,
          20,
          weight: FontWeight.w700,
          color: color,
        ).copyWith(decoration: tachado ? TextDecoration.lineThrough : null),
      ),
    ],
  );
}

class _HojaDescuento extends StatefulWidget {
  const _HojaDescuento({
    required this.producto,
    required this.actual,
    required this.importe,
    required this.puedeQuitar,
  });

  final String producto;
  final num? actual;
  final num? importe;
  final bool puedeQuitar;

  @override
  State<_HojaDescuento> createState() => _HojaDescuentoState();
}

class _HojaDescuentoState extends State<_HojaDescuento> {
  late final _campo = TextEditingController(
    text: widget.actual == null ? '' : textoPorcentaje(widget.actual!),
  );

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  void _elegir(int valor) {
    setState(() {
      _campo.text = '$valor';
      _campo.selection = TextSelection.collapsed(offset: _campo.text.length);
    });
  }

  Future<void> _guardar() async {
    final valor = leerPorcentajeManual(_campo.text);
    if (valor == null || !await confirmarDescuentoAlto(context, valor)) return;
    if (mounted) Navigator.of(context).pop((porcentaje: valor));
  }

  @override
  Widget build(BuildContext context) {
    final valor = leerPorcentajeManual(_campo.text);
    final vacio = _campo.text.trim().isEmpty;
    final error = vacio || valor != null
        ? null
        : 'Escribe un porcentaje entre 1 y 100.';
    final alto = valor != null && valor > umbralDescuentoAlto;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFD9694C), BarroTheme.primary],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33B84D34),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.sell_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.actual == null
                          ? 'Agregar descuento'
                          : 'Editar descuento',
                      style: BarroTheme.type(22, 28, weight: FontWeight.w800),
                    ),
                    Text(
                      widget.producto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BarroTheme.type(
                        14,
                        20,
                        color: BarroTheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          TextField(
            key: const ValueKey('campo-descuento-manual'),
            controller: _campo,
            autofocus: true,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [formatoPorcentajeManual],
            style: BarroTheme.type(
              40,
              48,
              weight: FontWeight.w800,
              color: BarroTheme.primary,
            ),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: BarroTheme.type(
                40,
                48,
                weight: FontWeight.w800,
                color: BarroTheme.border,
              ),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 18),
                child: Text(
                  '%',
                  style: BarroTheme.type(
                    28,
                    48,
                    weight: FontWeight.w700,
                    color: BarroTheme.primary,
                  ),
                ),
              ),
              suffixIconConstraints: const BoxConstraints(minWidth: 0),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 18),
                child: Icon(
                  Icons.percent_rounded,
                  color: BarroTheme.placeholder,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0),
              errorText: error,
              filled: true,
              fillColor: _rosaSuave.withValues(alpha: 0.5),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: BarroTheme.primary,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: BarroTheme.error),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: BarroTheme.error, width: 2),
              ),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _guardar(),
          ),
          const SizedBox(height: 14),
          Text(
            'Porcentajes rápidos',
            style: BarroTheme.type(
              12,
              16,
              weight: FontWeight.w600,
              color: BarroTheme.placeholder,
            ),
          ),
          const SizedBox(height: 8),
          ChipsPorcentaje(seleccionado: valor, onSeleccionar: _elegir),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: alto
                ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _ambarSuave,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: _ambar,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Descuento mayor a $umbralDescuentoAlto %: '
                              'te pediremos confirmarlo.',
                              style: BarroTheme.type(
                                12,
                                17,
                                weight: FontWeight.w600,
                                color: _ambar,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          if (widget.importe case final importe?) ...[
            const SizedBox(height: 18),
            ResumenDescuento(importe: importe, porcentaje: valor),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: valor == null ? null : _guardar,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Aplicar descuento'),
            style: FilledButton.styleFrom(
              backgroundColor: BarroTheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: BarroTheme.type(15, 20, weight: FontWeight.w700),
            ),
          ),
          if (widget.puedeQuitar)
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop((porcentaje: null)),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Quitar descuento'),
              style: TextButton.styleFrom(
                foregroundColor: BarroTheme.error,
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: BarroTheme.secondary,
              minimumSize: const Size.fromHeight(44),
            ),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}

class _AlertaDescuentoAlto extends StatelessWidget {
  const _AlertaDescuentoAlto({required this.porcentaje});

  final double porcentaje;

  @override
  Widget build(BuildContext context) {
    final texto = textoPorcentaje(porcentaje);
    final paga = textoPorcentaje(100 - porcentaje);
    final flexDescuento = (porcentaje * 100).round();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: _ambar.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 66,
                        height: 66,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x55D97706),
                              blurRadius: 16,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.priority_high_rounded,
                          size: 38,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '¡Atención!',
                    textAlign: TextAlign.center,
                    style: BarroTheme.type(22, 28, weight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text:
                              'El descuento es muy alto. El cliente pagará solo el ',
                        ),
                        TextSpan(
                          text: '$paga%',
                          style: BarroTheme.type(
                            15,
                            22,
                            weight: FontWeight.w800,
                            color: _ambar,
                          ),
                        ),
                        const TextSpan(
                          text:
                              ' del precio. Revisa que el porcentaje sea '
                              'correcto antes de aplicarlo.',
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: BarroTheme.type(15, 22, color: BarroTheme.secondary),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBF5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFDE3BC)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _DatoBarra(
                                icono: Icons.sell_rounded,
                                etiqueta: 'Descuento',
                                valor: '$texto %',
                                color: _ambar,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _DatoBarra(
                                icono: Icons.payments_rounded,
                                etiqueta: 'Cliente paga',
                                valor: '$paga %',
                                color: BarroTheme.success,
                                alFinal: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: SizedBox(
                            height: 12,
                            child: Row(
                              children: [
                                Expanded(
                                  flex: flexDescuento,
                                  child: const DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFFFBBF24),
                                          Color(0xFFD97706),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                if (flexDescuento < 10000)
                                  Expanded(
                                    flex: 10000 - flexDescuento,
                                    child: const ColoredBox(
                                      color: Color(0xFF6FBF94),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    key: const ValueKey('confirmar-descuento-alto'),
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.check_rounded),
                    label: Text('Sí, aplicar $texto %'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: BarroTheme.type(
                        15,
                        20,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    key: const ValueKey('revisar-descuento-alto'),
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Revisar porcentaje'),
                    style: TextButton.styleFrom(
                      foregroundColor: BarroTheme.secondary,
                      minimumSize: const Size.fromHeight(48),
                      textStyle: BarroTheme.type(
                        14,
                        20,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Etiqueta pequeña con el porcentaje grande debajo, sobre la barra.
class _DatoBarra extends StatelessWidget {
  const _DatoBarra({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    required this.color,
    this.alFinal = false,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;
  final Color color;
  final bool alFinal;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alFinal
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 15, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                etiqueta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BarroTheme.type(
                  12,
                  16,
                  weight: FontWeight.w600,
                  color: BarroTheme.secondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            valor,
            style: BarroTheme.type(
              22,
              28,
              weight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
