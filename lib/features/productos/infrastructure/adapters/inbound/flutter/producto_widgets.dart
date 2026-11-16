import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:material_ui/material_ui.dart'
    as mui
    show InputDecoration, ListTile, Material, MaterialType, OutlineInputBorder;
import 'package:punto_de_venta/core/infrastructure/services/notificacion_servicio.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/core/infrastructure/widgets/barro_header.dart';
import '../../../../domain/producto.dart';
import '../../outbound/imagenes/cloudinary_url.dart';

const productoSuave = Color(0xFFF7E7DF);
const productoErrorSuave = Color(0xFFFFF0EE);

String formatoPrecio(double valor) => '\$${valor.toStringAsFixed(2)}';

String formatoPiezas(int cantidad) =>
    '$cantidad ${cantidad == 1 ? 'pieza' : 'piezas'}';

/// Nivel de existencia de un producto en una sucursal, para decidir de un
/// vistazo si conviene reabastecerlo.
enum NivelExistencia {
  /// Más de [NivelExistencia.limiteModerado] piezas.
  suficiente(
    etiqueta: 'Existencia suficiente',
    icono: Icons.check_circle_rounded,
    color: BarroTheme.success,
    fondo: Color(0xFFECF7F0),
  ),

  /// Entre [NivelExistencia.limiteBajo] + 1 y [NivelExistencia.limiteModerado].
  moderado(
    etiqueta: 'Existencia moderada',
    icono: Icons.warning_amber_rounded,
    color: Color(0xFF8A5A00),
    fondo: Color(0xFFFFF3DC),
  ),

  /// [NivelExistencia.limiteBajo] piezas o menos: hay que reabastecer.
  bajo(
    etiqueta: 'Reabastecer pronto',
    icono: Icons.production_quantity_limits_rounded,
    color: BarroTheme.error,
    fondo: productoErrorSuave,
  ),

  /// Sin piezas.
  agotado(
    etiqueta: 'Agotado',
    icono: Icons.remove_shopping_cart_rounded,
    color: BarroTheme.error,
    fondo: productoErrorSuave,
  );

  const NivelExistencia({
    required this.etiqueta,
    required this.icono,
    required this.color,
    required this.fondo,
  });

  final String etiqueta;
  final IconData icono;
  final Color color;
  final Color fondo;

  static const limiteBajo = 10;
  static const limiteModerado = 25;

  static NivelExistencia de(int existencia) {
    if (existencia <= 0) return agotado;
    if (existencia <= limiteBajo) return bajo;
    if (existencia <= limiteModerado) return moderado;
    return suficiente;
  }

  /// Llenado de la barra: se considera llena a partir de 1.5 veces el límite
  /// moderado, para que "suficiente" se distinga de "apenas suficiente".
  static double llenado(int existencia) =>
      (existencia / (limiteModerado * 1.5)).clamp(0, 1).toDouble();
}

/// Ícono del nivel de existencia dentro de un círculo de su color.
class ExistenciaIcono extends StatelessWidget {
  const ExistenciaIcono(this.existencia, {this.tamano = 36, super.key});
  final int existencia;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final nivel = NivelExistencia.de(existencia);
    return Tooltip(
      message: nivel.etiqueta,
      child: Container(
        width: tamano,
        height: tamano,
        decoration: BoxDecoration(color: nivel.fondo, shape: BoxShape.circle),
        child: Icon(nivel.icono, size: tamano * 0.56, color: nivel.color),
      ),
    );
  }
}

/// Etiqueta compacta con ícono y texto del nivel ("Reabastecer pronto").
class ExistenciaEtiqueta extends StatelessWidget {
  const ExistenciaEtiqueta(this.existencia, {super.key});
  final int existencia;

  @override
  Widget build(BuildContext context) {
    final nivel = NivelExistencia.de(existencia);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: nivel.fondo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(nivel.icono, size: 13, color: nivel.color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              nivel.etiqueta,
              overflow: TextOverflow.ellipsis,
              style: BarroTheme.type(
                11,
                16,
                weight: FontWeight.w700,
                color: nivel.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra delgada que muestra qué tan surtida está la sucursal.
class ExistenciaBarra extends StatelessWidget {
  const ExistenciaBarra(this.existencia, {super.key});
  final int existencia;

  @override
  Widget build(BuildContext context) {
    final nivel = NivelExistencia.de(existencia);
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: NivelExistencia.llenado(existencia)),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          builder: (_, valor, _) => LinearProgressIndicator(
            value: valor,
            minHeight: 6,
            color: nivel.color,
            backgroundColor: nivel.fondo,
          ),
        ),
      ),
    );
  }
}

class ProductoImagen extends StatelessWidget {
  const ProductoImagen({
    required this.size,
    this.ancho,
    this.url,
    this.bytes,
    this.conservarProporcion = false,
    super.key,
  });

  /// Alto del recuadro y ancho por defecto cuando el recuadro es fijo.
  final double size;
  final double? ancho;
  final String? url;
  final Uint8List? bytes;

  /// Ajusta el ancho según la foto y el espacio disponible.
  final bool conservarProporcion;

  BoxFit get _ajuste => conservarProporcion ? BoxFit.contain : BoxFit.cover;
  Alignment get _alineacion =>
      conservarProporcion ? Alignment.topLeft : Alignment.center;

  @override
  Widget build(BuildContext context) {
    final radio = BorderRadius.circular(14);
    if (conservarProporcion) {
      return ClipRRect(
        borderRadius: radio,
        child: SizedBox(height: size, child: _contenido()),
      );
    }
    return Container(
      width: ancho ?? size,
      height: size,
      decoration: BoxDecoration(
        color: productoSuave,
        borderRadius: radio,
        border: Border.all(color: BarroTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: _contenido(),
    );
  }

  Widget _contenido() {
    final seleccionada = bytes;
    if (seleccionada != null) {
      return Image.memory(
        seleccionada,
        fit: _ajuste,
        alignment: _alineacion,
        // Se decodifica al tamaño que se muestra, no la foto completa.
        cacheWidth: tamaniosImagenCloudinary.last,
        errorBuilder: (_, _, _) => _placeholder(error: true),
      );
    }
    final direccion = url?.trim();
    if (direccion == null || direccion.isEmpty) return _placeholder();
    // Se pide a Cloudinary solo el tamaño que ocupa el recuadro en pantalla.
    return LayoutBuilder(
      builder: (context, restricciones) {
        final ancho = restricciones.maxWidth.isFinite
            ? restricciones.maxWidth
            : size;
        final ladoPx =
            math.max(ancho, size) * MediaQuery.devicePixelRatioOf(context);
        return CachedNetworkImage(
          imageUrl: urlImagenCloudinary(direccion, ladoPx),
          fit: _ajuste,
          alignment: _alineacion,
          placeholder: (_, _) => _placeholder(cargando: true),
          errorWidget: (_, _, _) => _placeholder(error: true),
        );
      },
    );
  }

  Widget _placeholder({bool cargando = false, bool error = false}) => Container(
    width: conservarProporcion ? size : null,
    color: productoSuave,
    alignment: Alignment.center,
    child: cargando
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(
            error ? Icons.broken_image_outlined : Icons.image_outlined,
            color: BarroTheme.secondary,
            size: size * 0.38,
          ),
  );
}

class ProductoCabecera extends StatelessWidget {
  const ProductoCabecera({this.rol = 'Propietario', super.key});
  final String rol;
  @override
  Widget build(BuildContext context) => const BarroHeader();
}

class ProductoNegocioPanel extends StatelessWidget {
  const ProductoNegocioPanel({
    required this.negocio,
    this.negocios = const [],
    this.onChanged,
    this.sucursal,
    super.key,
  });
  final NegocioProducto negocio;
  final List<NegocioProducto> negocios;
  final ValueChanged<NegocioProducto>? onChanged;

  /// Nombre de la sucursal que se administra: sustituye al del negocio.
  final String? sucursal;
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
          sucursal != null ? 'SUCURSAL' : 'NEGOCIO',
          style: BarroTheme.type(
            11,
            16,
            weight: FontWeight.w700,
            color: BarroTheme.secondary,
          ),
        ),
        if (sucursal != null)
          Text(
            sucursal!,
            style: BarroTheme.type(16, 23, weight: FontWeight.w700),
          )
        else if (negocios.length > 1)
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
    this.barraInferior,
    this.onRefresh,
    this.rol = 'Propietario',
    super.key,
  });
  final List<Widget> children;
  final bool navegacion;
  final Widget? barraInferior;
  final Future<void> Function()? onRefresh;
  final String rol;
  @override
  Widget build(BuildContext context) {
    Widget contenido = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProductoCabecera(rol: rol),
          ...children,
        ],
      ),
    );
    if (onRefresh != null) {
      contenido = RefreshIndicator(onRefresh: onRefresh!, child: contenido);
    }
    return Scaffold(
      bottomNavigationBar:
          barraInferior ?? (navegacion ? const ProductoNavegacion() : null),
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
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
  const ProductoEnlaceVolver({
    required this.onPressed,
    this.texto = 'Productos',
    super.key,
  });
  final VoidCallback? onPressed;
  final String texto;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      padding: EdgeInsets.zero,
      alignment: Alignment.centerLeft,
    ),
    icon: const Icon(Icons.arrow_back, size: 18),
    label: Text(texto),
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

/// Desplegable con buscador por nombre (filtra en el cliente la lista completa).
/// Usa `dropdown_search`, que trae su propio `material_ui`: por eso el `Material`
/// y los tipos de decoración son los de ese paquete, y la app declara su
/// delegado de localización en `MaterialApp`.
class ProductoSelectorBuscable extends StatelessWidget {
  const ProductoSelectorBuscable({
    required this.valor,
    required this.opciones,
    required this.onChanged,
    this.hint,
    this.textoBuscador = 'Buscar...',
    this.error,
    super.key,
  });
  final int? valor;
  final List<(int, String)> opciones;
  final ValueChanged<int?>? onChanged;
  final String? hint;
  final String textoBuscador;
  final String? error;

  mui.OutlineInputBorder _borde(Color color) => mui.OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color),
  );

  @override
  Widget build(BuildContext context) {
    (int, String)? seleccionado;
    for (final o in opciones) {
      if (o.$1 == valor) seleccionado = o;
    }
    return mui.Material(
      type: mui.MaterialType.transparency,
      child: DropdownSearch<(int, String)>(
        items: (filtro, _) => opciones,
        selectedItem: seleccionado,
        itemAsString: (o) => o.$2,
        compareFn: (a, b) => a.$1 == b.$1,
        filterFn: (o, filtro) =>
            o.$2.toLowerCase().contains(filtro.trim().toLowerCase()),
        enabled: onChanged != null,
        onSelected: (o) => onChanged?.call(o?.$1),
        decoratorProps: DropDownDecoratorProps(
          baseStyle: BarroTheme.type(14, 21),
          decoration: mui.InputDecoration(
            hintText: hint,
            hintStyle: BarroTheme.type(14, 21, color: BarroTheme.placeholder),
            errorText: error,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: _borde(BarroTheme.border),
            enabledBorder: _borde(BarroTheme.border),
            disabledBorder: _borde(BarroTheme.border),
            focusedBorder: _borde(BarroTheme.primary),
            errorBorder: _borde(BarroTheme.error),
          ),
        ),
        suffixProps: const DropdownSuffixProps(
          dropdownButtonProps: DropdownButtonProps(
            iconClosed: Icon(Icons.keyboard_arrow_down),
            iconOpened: Icon(Icons.keyboard_arrow_up),
          ),
        ),
        popupProps: PopupProps.menu(
          showSearchBox: true,
          fit: FlexFit.loose,
          constraints: const BoxConstraints(maxHeight: 320),
          menuProps: MenuProps(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
          searchFieldProps: TextFieldProps(
            style: BarroTheme.type(14, 21),
            decoration: mui.InputDecoration(
              hintText: textoBuscador,
              hintStyle: BarroTheme.type(14, 21, color: BarroTheme.placeholder),
              prefixIcon: const Icon(
                Icons.search,
                size: 20,
                color: BarroTheme.primary,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: _borde(BarroTheme.border),
              enabledBorder: _borde(BarroTheme.border),
              focusedBorder: _borde(BarroTheme.primary),
            ),
          ),
          itemBuilder: (context, o, deshabilitado, activo) => mui.ListTile(
            dense: true,
            selected: activo,
            selectedTileColor: productoSuave,
            title: Text(
              o.$2,
              style: BarroTheme.type(
                14,
                20,
                weight: activo ? FontWeight.w700 : FontWeight.w400,
                color: activo ? BarroTheme.primary : BarroTheme.text,
              ),
            ),
            trailing: activo
                ? const Icon(Icons.check, size: 18, color: BarroTheme.primary)
                : null,
          ),
          emptyBuilder: (context, busqueda) => Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              busqueda.isNotEmpty
                  ? 'Sin resultados para "$busqueda"'
                  : 'Sin opciones disponibles',
              textAlign: TextAlign.center,
              style: BarroTheme.type(13, 18, color: BarroTheme.secondary),
            ),
          ),
        ),
      ),
    );
  }
}

/// Filtro desplegable del listado (área, categoría, sucursal): fondo suave,
/// icono al inicio y botón para quitar el filtro. Con [conBuscador] el menú
/// permite buscar entre las opciones.
class ProductoFiltroDesplegable extends StatelessWidget {
  const ProductoFiltroDesplegable({
    required this.texto,
    required this.textoBuscador,
    required this.valor,
    required this.opciones,
    required this.onChanged,
    required this.icono,
    this.conBuscador = false,
    this.habilitado = true,
    this.onAntesDeAbrir,
    super.key,
  });
  final String texto;
  final String textoBuscador;
  final int? valor;
  final List<(int, String)> opciones;
  final ValueChanged<int?> onChanged;
  final IconData icono;
  final bool conBuscador;
  final bool habilitado;

  /// Se llama antes de abrir el menú (p. ej. para soltar el foco del teclado).
  final VoidCallback? onAntesDeAbrir;

  @override
  Widget build(BuildContext context) {
    (int, String)? seleccionado;
    for (final o in opciones) {
      if (o.$1 == valor) seleccionado = o;
    }
    final estilo = BarroTheme.type(13, 18, color: BarroTheme.primary);
    // dropdown_search usa su propio material_ui: necesita un Material de ese
    // paquete como ancestro (el de flutter/material.dart no le sirve).
    return mui.Material(
      type: mui.MaterialType.transparency,
      child: DropdownSearch<(int, String)>(
        items: (filtro, _) => opciones,
        selectedItem: seleccionado,
        itemAsString: (o) => o.$2,
        compareFn: (a, b) => a.$1 == b.$1,
        filterFn: (o, filtro) =>
            o.$2.toLowerCase().contains(filtro.trim().toLowerCase()),
        enabled: habilitado,
        onBeforePopupOpening: (_) {
          onAntesDeAbrir?.call();
          return true;
        },
        onSelected: (o) => onChanged(o?.$1),
        decoratorProps: DropDownDecoratorProps(
          baseStyle: estilo.copyWith(fontWeight: FontWeight.w700),
          decoration: mui.InputDecoration(
            hintText: texto,
            hintStyle: estilo.copyWith(fontWeight: FontWeight.w700),
            prefixIcon: Icon(icono, size: 18, color: BarroTheme.primary),
            filled: true,
            fillColor: productoSuave,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 12,
            ),
            border: mui.OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: mui.OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: mui.OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: BarroTheme.primary),
            ),
          ),
        ),
        suffixProps: const DropdownSuffixProps(
          clearButtonProps: ClearButtonProps(
            isVisible: true,
            icon: Icon(Icons.close, size: 16),
            padding: EdgeInsets.zero,
            tooltip: 'Quitar filtro',
          ),
          dropdownButtonProps: DropdownButtonProps(
            iconClosed: Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: BarroTheme.primary,
            ),
            iconOpened: Icon(
              Icons.keyboard_arrow_up,
              size: 20,
              color: BarroTheme.primary,
            ),
          ),
        ),
        popupProps: PopupProps.menu(
          showSearchBox: conBuscador,
          fit: FlexFit.loose,
          constraints: const BoxConstraints(maxHeight: 320),
          menuProps: MenuProps(
            // Se usa `shape` (no `borderRadius`): MenuProps ya trae un shape por
            // defecto y Material no admite ambos a la vez.
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
          searchFieldProps: TextFieldProps(
            autofocus: false,
            style: BarroTheme.type(14, 21),
            decoration: mui.InputDecoration(
              hintText: textoBuscador,
              hintStyle: BarroTheme.type(14, 21, color: BarroTheme.placeholder),
              prefixIcon: const Icon(
                Icons.search,
                size: 20,
                color: BarroTheme.primary,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: mui.OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: BarroTheme.border),
              ),
              enabledBorder: mui.OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: BarroTheme.border),
              ),
              focusedBorder: mui.OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: BarroTheme.primary),
              ),
            ),
          ),
          itemBuilder: (context, o, deshabilitado, activo) => mui.ListTile(
            dense: true,
            selected: activo,
            selectedTileColor: productoSuave,
            title: Text(
              o.$2,
              style: BarroTheme.type(
                14,
                20,
                weight: activo ? FontWeight.w700 : FontWeight.w400,
                color: activo ? BarroTheme.primary : BarroTheme.text,
              ),
            ),
            trailing: activo
                ? const Icon(Icons.check, size: 18, color: BarroTheme.primary)
                : null,
          ),
          emptyBuilder: (context, busqueda) => Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              conBuscador && busqueda.isNotEmpty
                  ? 'Sin resultados para "$busqueda"'
                  : 'Sin opciones disponibles',
              textAlign: TextAlign.center,
              style: BarroTheme.type(13, 18, color: BarroTheme.secondary),
            ),
          ),
        ),
      ),
    );
  }
}

/// Indicador de pasos del registro: círculos con icono unidos por una línea.
/// Los pasos ya completados muestran una palomita y, con [onPaso], se pueden
/// tocar para regresar a ellos.
class ProductoPasos extends StatelessWidget {
  const ProductoPasos({
    required this.paso,
    this.pasos = const [
      ('Datos', Icons.inventory_2_outlined),
      ('Sucursales', Icons.storefront_outlined),
    ],
    this.onPaso,
    super.key,
  });
  final int paso;
  final List<(String, IconData)> pasos;
  final ValueChanged<int>? onPaso;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (i, (titulo, icono)) in pasos.indexed) ...[
        if (i > 0)
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.only(top: 21),
              decoration: BoxDecoration(
                color: i <= paso ? BarroTheme.primary : BarroTheme.border,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        _paso(i, titulo, icono),
      ],
    ],
  );

  Widget _paso(int i, String titulo, IconData icono) {
    final completado = i < paso;
    final actual = i == paso;
    final contenido = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: completado || actual ? BarroTheme.primary : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: completado || actual
                  ? BarroTheme.primary
                  : BarroTheme.border,
              width: 1.5,
            ),
            boxShadow: actual
                ? [
                    BoxShadow(
                      color: BarroTheme.primary.withValues(alpha: 0.25),
                      spreadRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            completado ? Icons.check_rounded : icono,
            size: 22,
            color: completado || actual ? Colors.white : BarroTheme.placeholder,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          titulo,
          style: BarroTheme.type(
            12,
            16,
            weight: actual ? FontWeight.w700 : FontWeight.w500,
            color: actual || completado
                ? BarroTheme.primary
                : BarroTheme.placeholder,
          ),
        ),
      ],
    );
    final tocable = completado && onPaso != null;
    return Semantics(
      button: tocable,
      selected: actual,
      label: 'Paso ${i + 1} de ${pasos.length}: $titulo',
      child: tocable
          ? Tooltip(
              message: 'Volver a $titulo',
              child: InkWell(
                key: ValueKey('producto-paso-$i'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => onPaso!(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: contenido,
                ),
              ),
            )
          : Padding(
              key: ValueKey('producto-paso-$i'),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: contenido,
            ),
    );
  }
}

/// Tarjeta con encabezado (icono, título y descripción) para agrupar campos
/// de un formulario.
class ProductoSeccion extends StatelessWidget {
  const ProductoSeccion({
    required this.icono,
    required this.titulo,
    required this.children,
    this.subtitulo,
    this.accion,
    super.key,
  });
  final IconData icono;
  final String titulo;
  final String? subtitulo;
  final Widget? accion;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: BarroTheme.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: productoSuave,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icono, size: 20, color: BarroTheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: BarroTheme.type(16, 22, weight: FontWeight.w700),
                  ),
                  if (subtitulo != null)
                    Text(
                      subtitulo!,
                      style: BarroTheme.type(
                        12,
                        18,
                        color: BarroTheme.secondary,
                      ),
                    ),
                ],
              ),
            ),
            ?accion,
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    ),
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
                      NotificacionServicio.info(
                        context,
                        'El módulo de ${item.$2.toLowerCase()} aún no está disponible.',
                        titulo: 'Próximamente',
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
