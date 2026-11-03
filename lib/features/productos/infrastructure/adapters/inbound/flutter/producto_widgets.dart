import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import '../../../../domain/producto.dart';

const productoSuave = Color(0xFFF7E7DF);
const productoErrorSuave = Color(0xFFFFF0EE);

String formatoPrecio(double valor) => '\$${valor.toStringAsFixed(2)}';

String formatoPiezas(int cantidad) =>
    '$cantidad ${cantidad == 1 ? 'pieza' : 'piezas'}';

class ProductoCabecera extends StatelessWidget {
  const ProductoCabecera({super.key});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      SvgPicture.asset(
        'assets/icons/brand.svg',
        width: 36,
        height: 36,
        semanticsLabel: 'Logo de BarroControl',
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          'BarroControl',
          style: BarroTheme.type(21, 28, weight: FontWeight.w700),
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: productoSuave,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'Propietario',
          style: BarroTheme.type(12, 17, color: BarroTheme.primary),
        ),
      ),
    ],
  );
}

class ProductoNegocioPanel extends StatelessWidget {
  const ProductoNegocioPanel({
    required this.negocio,
    this.negocios = const [],
    this.onChanged,
    super.key,
  });
  final NegocioProducto negocio;
  final List<NegocioProducto> negocios;
  final ValueChanged<NegocioProducto>? onChanged;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: productoSuave,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NEGOCIO',
          style: BarroTheme.type(
            11,
            16,
            weight: FontWeight.w700,
            color: BarroTheme.secondary,
          ),
        ),
        if (negocios.length > 1)
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: negocio.id,
              isExpanded: true,
              isDense: true,
              style: BarroTheme.type(16, 23, weight: FontWeight.w700),
              items: [
                for (final n in negocios)
                  DropdownMenuItem(
                    value: n.id,
                    child: Text(n.nombre, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: onChanged == null
                  ? null
                  : (id) => onChanged!(negocios.firstWhere((n) => n.id == id)),
            ),
          )
        else
          Text(
            negocio.nombre,
            style: BarroTheme.type(16, 23, weight: FontWeight.w700),
          ),
      ],
    ),
  );
}

class ProductoAviso extends StatelessWidget {
  const ProductoAviso(this.mensaje, {this.error = false, super.key});
  final String mensaje;
  final bool error;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: error ? productoErrorSuave : const Color(0xFFECF7F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        mensaje,
        style: BarroTheme.type(
          13,
          19,
          color: error ? BarroTheme.error : BarroTheme.success,
        ),
      ),
    ),
  );
}

class ProductoBoton extends StatelessWidget {
  const ProductoBoton({
    required this.texto,
    required this.onPressed,
    this.busy = false,
    this.destructivo = false,
    super.key,
  });
  final String texto;
  final VoidCallback? onPressed;
  final bool busy;
  final bool destructivo;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: destructivo
            ? const Color(0xFFB91F16)
            : BarroTheme.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        textStyle: BarroTheme.type(14, 20, weight: FontWeight.w700),
      ),
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(texto, textAlign: TextAlign.center),
    ),
  );
}

class ProductoBotonPeligro extends StatelessWidget {
  const ProductoBotonPeligro({
    required this.texto,
    required this.onPressed,
    super.key,
  });
  final String texto;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: BarroTheme.error,
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: BarroTheme.error),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: BarroTheme.type(14, 20, weight: FontWeight.w700),
      ),
      child: Text(texto),
    ),
  );
}

/// Marco de pantalla compartido: ancho móvil, cabecera y scroll.
class ProductoScaffold extends StatelessWidget {
  const ProductoScaffold({
    required this.children,
    this.navegacion = false,
    this.onRefresh,
    super.key,
  });
  final List<Widget> children;
  final bool navegacion;
  final Future<void> Function()? onRefresh;
  @override
  Widget build(BuildContext context) {
    Widget contenido = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [const ProductoCabecera(), ...children],
      ),
    );
    if (onRefresh != null) {
      contenido = RefreshIndicator(onRefresh: onRefresh!, child: contenido);
    }
    return Scaffold(
      bottomNavigationBar: navegacion ? const ProductoNavegacion() : null,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: contenido,
          ),
        ),
      ),
    );
  }
}

class ProductoEnlaceVolver extends StatelessWidget {
  const ProductoEnlaceVolver({required this.onPressed, super.key});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      padding: EdgeInsets.zero,
      alignment: Alignment.centerLeft,
    ),
    icon: const Icon(Icons.arrow_back, size: 18),
    label: const Text('Productos'),
  );
}

class ProductoEtiqueta extends StatelessWidget {
  const ProductoEtiqueta(this.texto, {super.key});
  final String texto;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(texto, style: BarroTheme.type(13, 19, weight: FontWeight.w700)),
  );
}

InputDecoration productoDecoracion({String? hint, String? error}) {
  OutlineInputBorder borde(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: BarroTheme.type(14, 21, color: BarroTheme.placeholder),
    errorText: error,
    errorMaxLines: 3,
    errorStyle: BarroTheme.type(12, 18, color: BarroTheme.error),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: borde(BarroTheme.border),
    enabledBorder: borde(BarroTheme.border),
    disabledBorder: borde(BarroTheme.border),
    focusedBorder: borde(BarroTheme.primary),
    errorBorder: borde(BarroTheme.error),
    focusedErrorBorder: borde(BarroTheme.error),
  );
}

class ProductoSelector<T> extends StatelessWidget {
  const ProductoSelector({
    required this.valor,
    required this.opciones,
    required this.onChanged,
    this.hint,
    this.error,
    super.key,
  });
  final T? valor;
  final List<(T, String)> opciones;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final String? error;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    initialValue: opciones.any((o) => o.$1 == valor) ? valor : null,
    isExpanded: true,
    icon: const Icon(Icons.keyboard_arrow_down),
    style: BarroTheme.type(14, 21),
    decoration: productoDecoracion(hint: hint, error: error),
    items: [
      for (final o in opciones)
        DropdownMenuItem(
          value: o.$1,
          child: Text(o.$2, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: onChanged,
  );
}

class ProductoPasos extends StatelessWidget {
  const ProductoPasos({required this.paso, super.key});
  final int paso;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (i, texto) in const [
        '1. Datos del producto',
        '2. Sucursales',
      ].indexed) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: i == paso ? productoSuave : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              texto,
              style: BarroTheme.type(
                11,
                16,
                weight: FontWeight.w700,
                color: i == paso ? BarroTheme.primary : BarroTheme.secondary,
              ),
            ),
          ),
        ),
      ],
    ],
  );
}

Future<bool> confirmarEliminarProducto(
  BuildContext context, {
  required Producto producto,
  required NegocioProducto negocio,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: productoErrorSuave,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.priority_high,
                    color: BarroTheme.error,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '¿Eliminar producto?',
                  style: BarroTheme.type(23, 30, weight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Text(
                  'Se eliminará este producto del catálogo de ${negocio.nombre}.',
                  style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
                ),
                const SizedBox(height: 8),
                Text(
                  producto.nombre,
                  style: BarroTheme.type(14, 21, weight: FontWeight.w700),
                ),
                const SizedBox(height: 26),
                ProductoBoton(
                  texto: 'Eliminar producto',
                  destructivo: true,
                  onPressed: () => Navigator.pop(context, true),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ) ??
    false;

class ProductoNavegacion extends StatelessWidget {
  const ProductoNavegacion({super.key});
  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    child: SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final item in const [
                  (Icons.home_outlined, 'Inicio'),
                  (Icons.receipt_long_outlined, 'Pedidos'),
                  (Icons.point_of_sale_outlined, 'Caja'),
                  (Icons.inventory_2_outlined, 'Inventario'),
                  (Icons.apps_rounded, 'Más'),
                ])
                  IconButton(
                    tooltip: item.$2,
                    isSelected: item.$2 == 'Inventario',
                    style: IconButton.styleFrom(
                      backgroundColor: item.$2 == 'Inventario'
                          ? const Color(0xFFA93A21)
                          : Colors.transparent,
                      foregroundColor: item.$2 == 'Inventario'
                          ? Colors.white
                          : BarroTheme.secondary,
                      minimumSize: const Size(46, 46),
                    ),
                    onPressed: () {
                      if (item.$2 == 'Inventario') return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'El módulo de ${item.$2.toLowerCase()} aún no está disponible.',
                          ),
                        ),
                      );
                    },
                    icon: Icon(item.$1, size: 25),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
