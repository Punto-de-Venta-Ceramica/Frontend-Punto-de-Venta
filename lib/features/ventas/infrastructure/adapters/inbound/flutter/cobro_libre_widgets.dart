import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/core/infrastructure/widgets/descuento_manual_dialog.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_widgets.dart'
    show productoSuave;

import '../../../../domain/venta.dart';
import 'ventas_widgets.dart';

/// Lo que el cajero captura para cobrar algo que no está en el catálogo.
class CobroLibre {
  const CobroLibre({
    required this.cantidad,
    required this.precio,
    this.nombre,
    this.descuento,
  });

  final int cantidad;
  final num precio;

  /// Descripción opcional; sin ella la venta usa el nombre del producto.
  final String? nombre;

  /// Porcentaje de descuento opcional (1 a 100).
  final double? descuento;
}

/// Resultado de la hoja: un cobro guardado o la orden de quitar el actual.
class ResultadoCobroLibre {
  const ResultadoCobroLibre.guardar(CobroLibre this.cobro) : quitar = false;
  const ResultadoCobroLibre.quitar() : cobro = null, quitar = true;

  final CobroLibre? cobro;
  final bool quitar;
}

/// Abre la hoja para capturar (o corregir, si ya hay [actual]) el cobro libre.
Future<ResultadoCobroLibre?> mostrarCobroLibre(
  BuildContext context, {
  required String nombrePorDefecto,
  SeleccionVenta? actual,
}) => showModalBottomSheet<ResultadoCobroLibre>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: Colors.white,
  builder: (_) =>
      _HojaCobroLibre(actual: actual, nombrePorDefecto: nombrePorDefecto),
);

/// Acceso al cobro libre dentro de la lista de productos: invita a capturarlo
/// y, ya capturado, resume la línea con sus acciones de editar y quitar.
class TarjetaCobroLibre extends StatelessWidget {
  const TarjetaCobroLibre({
    required this.seleccion,
    required this.cargando,
    required this.onAbrir,
    this.onQuitar,
    super.key,
  });

  final SeleccionVenta? seleccion;

  /// Mientras se obtiene el producto de cobro libre del servidor.
  final bool cargando;
  final VoidCallback onAbrir;
  final VoidCallback? onQuitar;

  @override
  Widget build(BuildContext context) {
    final linea = seleccion;
    return linea == null ? _invitacion() : _resumen(linea);
  }

  Widget _invitacion() => Semantics(
    button: true,
    label: 'Cobro libre. Cobra algo que no está en el catálogo.',
    child: CustomPaint(
      painter: const _BordeDiscontinuo(BarroTheme.primary, 20),
      child: Material(
        color: productoSuave.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: cargando ? null : onAbrir,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const _IconoRedondo(Icons.edit_note_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cobro libre',
                        style: BarroTheme.type(15, 21, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '¿No está en el catálogo? Escribe el precio y cóbralo.',
                        style: BarroTheme.type(
                          12,
                          17,
                          color: BarroTheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                cargando
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          semanticsLabel: 'Preparando cobro libre',
                        ),
                      )
                    : const Icon(
                        Icons.add_circle_rounded,
                        color: BarroTheme.primary,
                        size: 28,
                      ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _resumen(SeleccionVenta linea) => Material(
    color: const Color(0xFFFFFCFA),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: BarroTheme.primary, width: 1.5),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onAbrir,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const _IconoRedondo(Icons.check_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        linea.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: BarroTheme.type(15, 21, weight: FontWeight.w700),
                      ),
                      Text(
                        'Cobro libre · ${linea.cantidad} × ${dineroVenta(linea.precio)} c/u'
                        '${linea.descuentoManual == null ? '' : ' · ${textoPorcentaje(linea.descuentoManual!)} % desc.'}',
                        style: BarroTheme.type(
                          12,
                          17,
                          color: BarroTheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  dineroVenta(linea.importe),
                  style: BarroTheme.type(18, 24, weight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onQuitar != null)
                  TextButton.icon(
                    onPressed: onQuitar,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Quitar'),
                    style: TextButton.styleFrom(
                      foregroundColor: BarroTheme.error,
                      minimumSize: const Size(48, 44),
                    ),
                  ),
                const SizedBox(width: 4),
                OutlinedButton.icon(
                  onPressed: onAbrir,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BarroTheme.primary,
                    minimumSize: const Size(48, 44),
                    side: const BorderSide(color: BarroTheme.border),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _IconoRedondo extends StatelessWidget {
  const _IconoRedondo(this.icono);

  final IconData icono;

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: const BoxDecoration(
      color: productoSuave,
      shape: BoxShape.circle,
    ),
    child: Icon(icono, color: BarroTheme.primary, size: 24),
  );
}

class _BordeDiscontinuo extends CustomPainter {
  const _BordeDiscontinuo(this.color, this.radio);

  final Color color;
  final double radio;

  @override
  void paint(Canvas canvas, Size size) {
    final contorno = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radio)),
      );
    final pincel = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final tramo in contorno.computeMetrics()) {
      for (var inicio = 0.0; inicio < tramo.length; inicio += 10) {
        canvas.drawPath(tramo.extractPath(inicio, inicio + 6), pincel);
      }
    }
  }

  @override
  bool shouldRepaint(_BordeDiscontinuo anterior) =>
      anterior.color != color || anterior.radio != radio;
}

/// Aviso bajo el campo de descripción: qué nombre se registra si queda vacío.
class _NotaNombre extends StatelessWidget {
  const _NotaNombre({required this.nombre});

  final String nombre;

  static const _fondo = Color(0xFFFFF6E3);
  static const _borde = Color(0xFFF0D9A6);
  static const _acento = Color(0xFF9A6700);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: _fondo,
      border: Border.all(color: _borde),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.lightbulb_outline_rounded, size: 20, color: _acento),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: BarroTheme.type(13, 19, color: BarroTheme.text),
              children: [
                TextSpan(
                  text: 'Nota: ',
                  style: BarroTheme.type(
                    13,
                    19,
                    weight: FontWeight.w800,
                    color: _acento,
                  ),
                ),
                const TextSpan(
                  text: 'Si dejas el nombre vacío, se registrará como ',
                ),
                TextSpan(
                  text: '«$nombre»',
                  style: BarroTheme.type(13, 19, weight: FontWeight.w700),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _HojaCobroLibre extends StatefulWidget {
  const _HojaCobroLibre({required this.nombrePorDefecto, this.actual});

  final SeleccionVenta? actual;

  /// Nombre con el que se registra el cobro si la descripción queda vacía.
  final String nombrePorDefecto;

  @override
  State<_HojaCobroLibre> createState() => _HojaCobroLibreState();
}

class _HojaCobroLibreState extends State<_HojaCobroLibre> {
  static final _formatoPrecio = RegExp(r'^\d{0,6}([.,]\d{0,2})?$');
  static final _entero = RegExp(r'^\d{0,4}$');

  late final _precio = TextEditingController(
    text: widget.actual == null ? '' : _texto(widget.actual!.precio),
  );
  late final _cantidad = TextEditingController(
    text: '${widget.actual?.cantidad ?? 1}',
  );
  late final _nombre = TextEditingController(
    text: widget.actual?.nombreLibre ?? '',
  );
  late final _descuento = TextEditingController(
    text: widget.actual?.descuentoManual == null
        ? ''
        : textoPorcentaje(widget.actual!.descuentoManual!),
  );

  bool get _descuentoVacio => _descuento.text.trim().isEmpty;

  bool get _editando => widget.actual != null;

  static String _texto(num valor) =>
      valor == valor.roundToDouble()
      ? valor.toInt().toString()
      : valor.toStringAsFixed(2);

  num? get _precioValido {
    final valor = num.tryParse(_precio.text.trim().replaceAll(',', '.'));
    return valor == null ||
            valor <= 0 ||
            valor > SeleccionVenta.precioLibreMaximo
        ? null
        : valor;
  }

  int? get _cantidadValida {
    final valor = int.tryParse(_cantidad.text.trim());
    return valor == null || valor < 1 ? null : valor;
  }

  @override
  void dispose() {
    _precio.dispose();
    _cantidad.dispose();
    _nombre.dispose();
    _descuento.dispose();
    super.dispose();
  }

  void _sumar(int delta) {
    final nueva = ((_cantidadValida ?? 0) + delta).clamp(
      1,
      SeleccionVenta.cantidadLibreMaxima,
    );
    setState(() => _cantidad.text = '$nueva');
  }

  Future<void> _guardar() async {
    final precio = _precioValido;
    final cantidad = _cantidadValida;
    final descuento = leerPorcentajeManual(_descuento.text);
    if (precio == null || cantidad == null) return;
    if (!_descuentoVacio && descuento == null) return;
    if (descuento != null && !await confirmarDescuentoAlto(context, descuento)) {
      return;
    }
    if (!mounted) return;
    final nombre = _nombre.text.trim();
    Navigator.of(context).pop(
      ResultadoCobroLibre.guardar(
        CobroLibre(
          cantidad: cantidad,
          precio: precio,
          nombre: nombre.isEmpty ? null : nombre,
          descuento: descuento,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final precio = _precioValido;
    final cantidad = _cantidadValida;
    final descuento = leerPorcentajeManual(_descuento.text);
    final errorDescuento = !_descuentoVacio && descuento == null
        ? 'Escribe un porcentaje entre 1 y 100.'
        : null;
    final total = precio == null || cantidad == null || errorDescuento != null
        ? null
        // Mismo redondeo por línea que SeleccionVenta.importe y el servidor.
        : ((BigInt.from((precio * 100).round()) *
                          BigInt.from(cantidad) *
                          BigInt.from(10000 - ((descuento ?? 0) * 100).round()) +
                      BigInt.from(5000)) ~/
                  BigInt.from(10000))
              .toDouble() /
          100;
    final errorPrecio = _precio.text.trim().isNotEmpty && precio == null
        ? 'Escribe un precio entre \$0.01 y \$999,999.99.'
        : null;

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
          Text(
            'Cobro libre',
            style: BarroTheme.type(22, 28, weight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Para algo que no está en el catálogo. No descuenta inventario.',
            style: BarroTheme.type(13, 19, color: BarroTheme.secondary),
          ),
          const SizedBox(height: 20),
          VentaCampo(
            etiqueta: 'Precio por pieza (MXN) *',
            child: TextField(
              controller: _precio,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                TextInputFormatter.withFunction(
                  (anterior, nuevo) =>
                      _formatoPrecio.hasMatch(nuevo.text) ? nuevo : anterior,
                ),
              ],
              decoration: decoracionCampoVenta(
                indicacion: '0.00',
                error: errorPrecio,
              ).copyWith(
                prefixIcon: const Icon(
                  Icons.attach_money_rounded,
                  color: BarroTheme.primary,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 16),
          VentaCampo(
            etiqueta: 'Cantidad *',
            child: Row(
              children: [
                IconButton.outlined(
                  tooltip: 'Quitar una pieza',
                  icon: const Icon(Icons.remove_rounded),
                  onPressed: (cantidad ?? 0) > 1 ? () => _sumar(-1) : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _cantidad,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    style: BarroTheme.type(18, 24, weight: FontWeight.w700),
                    inputFormatters: [
                      TextInputFormatter.withFunction(
                        (anterior, nuevo) =>
                            _entero.hasMatch(nuevo.text) ? nuevo : anterior,
                      ),
                    ],
                    decoration: decoracionCampoVenta(),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  tooltip: 'Agregar una pieza',
                  icon: const Icon(Icons.add_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: BarroTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: (cantidad ?? 0) < SeleccionVenta.cantidadLibreMaxima
                      ? () => _sumar(1)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          VentaCampo(
            etiqueta: 'Descripción (opcional)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nombre,
                  maxLength: 150,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: decoracionCampoVenta(
                    indicacion: 'Ej. Servilletas',
                  ).copyWith(counterText: ''),
                ),
                const SizedBox(height: 10),
                _NotaNombre(nombre: widget.nombrePorDefecto),
              ],
            ),
          ),
          const SizedBox(height: 16),
          VentaCampo(
            etiqueta: 'Descuento % (opcional)',
            child: TextField(
              key: const ValueKey('descuento-cobro-libre'),
              controller: _descuento,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [formatoPorcentajeManual],
              decoration: decoracionCampoVenta(
                indicacion: 'Ej. 10',
                error: errorDescuento,
              ).copyWith(suffixText: '%'),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: productoSuave,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    total == null
                        ? 'Escribe el precio para ver el total'
                        : '$cantidad × ${dineroVenta(precio!)} c/u'
                              '${descuento == null ? '' : ' − ${textoPorcentaje(descuento)} %'}',
                    style: BarroTheme.type(
                      14,
                      20,
                      weight: FontWeight.w600,
                      color: total == null
                          ? BarroTheme.secondary
                          : BarroTheme.text,
                    ),
                  ),
                ),
                if (total != null)
                  Text(
                    dineroVenta(total),
                    style: BarroTheme.type(
                      22,
                      28,
                      weight: FontWeight.w800,
                      color: BarroTheme.primary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: total == null ? null : _guardar,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: BarroTheme.type(14, 20, weight: FontWeight.w600),
            ),
            child: Text(_editando ? 'Actualizar' : 'Agregar al cobro'),
          ),
          if (_editando)
            TextButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(const ResultadoCobroLibre.quitar()),
              style: TextButton.styleFrom(
                foregroundColor: BarroTheme.error,
                minimumSize: const Size.fromHeight(44),
              ),
              child: const Text('Quitar de la venta'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}
