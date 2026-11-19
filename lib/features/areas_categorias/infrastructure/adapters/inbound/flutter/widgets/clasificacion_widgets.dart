import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'clasificacion_vista.dart';

const clasificacionSuave = Color(0xFFF8E7DF);
const clasificacionBorde = Color(0xFFE8DAD3);

/// Iconos compartidos para que áreas y categorías se reconozcan igual en
/// listados, formularios y estados vacíos.
const iconoArea = Icons.space_dashboard_outlined;
const iconoCategoria = Icons.sell_outlined;

/// Cuadro de color suave con un icono al centro.
class ClasificacionIcono extends StatelessWidget {
  const ClasificacionIcono(
    this.icono, {
    this.tamano = 44,
    this.color = BarroTheme.primary,
    this.fondo = clasificacionSuave,
    super.key,
  });
  final IconData icono;
  final double tamano;
  final Color color;
  final Color fondo;
  @override
  Widget build(BuildContext context) => Container(
    width: tamano,
    height: tamano,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: fondo,
      borderRadius: BorderRadius.circular(tamano * 0.28),
    ),
    child: Icon(icono, color: color, size: tamano * 0.5),
  );
}

class ClasificacionTitulo extends StatelessWidget {
  const ClasificacionTitulo(
    this.titulo, {
    this.descripcion,
    this.icono,
    super.key,
  });
  final String titulo;
  final String? descripcion;
  final IconData? icono;
  @override
  Widget build(BuildContext context) {
    final textos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: BarroTheme.type(26, 33, weight: FontWeight.w700)),
        if (descripcion != null) ...[
          const SizedBox(height: 4),
          Text(
            descripcion!,
            style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
          ),
        ],
      ],
    );
    if (icono == null) return textos;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClasificacionIcono(icono!, tamano: 52),
        const SizedBox(width: 14),
        Expanded(child: textos),
      ],
    );
  }
}

/// Encabezado de una sección con contador opcional, p. ej. "Categorías  3".
class ClasificacionSeccion extends StatelessWidget {
  const ClasificacionSeccion(
    this.titulo, {
    this.icono,
    this.contador,
    super.key,
  });
  final String titulo;
  final IconData? icono;
  final int? contador;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (icono != null) ...[
        Icon(icono, size: 20, color: BarroTheme.primary),
        const SizedBox(width: 8),
      ],
      Flexible(
        child: Text(
          titulo,
          style: BarroTheme.type(19, 26, weight: FontWeight.w700),
        ),
      ),
      if (contador != null) ...[
        const SizedBox(width: 8),
        ClasificacionChip('$contador'),
      ],
    ],
  );
}

/// Etiqueta compacta en forma de píldora.
class ClasificacionChip extends StatelessWidget {
  const ClasificacionChip(this.texto, {this.icono, super.key});
  final String texto;
  final IconData? icono;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: clasificacionSuave,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icono != null) ...[
          Icon(icono, size: 14, color: BarroTheme.primary),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            texto,
            overflow: TextOverflow.ellipsis,
            style: BarroTheme.type(
              12,
              18,
              weight: FontWeight.w600,
              color: BarroTheme.primary,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Recuadro que indica a qué área pertenece lo que se está editando.
class ClasificacionContexto extends StatelessWidget {
  const ClasificacionContexto({
    required this.etiqueta,
    required this.valor,
    this.icono = iconoArea,
    super.key,
  });
  final String etiqueta;
  final String valor;
  final IconData icono;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: clasificacionBorde),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        ClasificacionIcono(icono, tamano: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                etiqueta.toUpperCase(),
                style: BarroTheme.type(
                  10,
                  15,
                  weight: FontWeight.w700,
                  color: BarroTheme.secondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: BarroTheme.type(15, 21, weight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class ClasificacionBoton extends StatelessWidget {
  const ClasificacionBoton(
    this.texto, {
    this.destructivo = false,
    this.outlined = false,
    this.onPressed,
    this.ocupado = false,
    this.icono,
    super.key,
  });
  final String texto;
  final bool destructivo;
  final bool outlined;
  final VoidCallback? onPressed;
  final bool ocupado;
  final IconData? icono;
  @override
  Widget build(BuildContext context) {
    final color = destructivo ? BarroTheme.error : BarroTheme.primary;
    final estilo = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(50)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (estados) => outlined
            ? Colors.transparent
            : estados.contains(WidgetState.disabled) && !ocupado
            ? color.withValues(alpha: 0.45)
            : color,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (estados) => outlined
            ? (estados.contains(WidgetState.disabled)
                  ? color.withValues(alpha: 0.45)
                  : color)
            : Colors.white,
      ),
      side: WidgetStatePropertyAll(
        outlined ? BorderSide(color: color) : BorderSide.none,
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textStyle: WidgetStatePropertyAll(
        BarroTheme.type(14, 20, weight: FontWeight.w600),
      ),
    );
    return FilledButton(
      onPressed: ocupado ? null : onPressed,
      style: estilo,
      child: ocupado
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: outlined ? color : Colors.white,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icono != null) ...[
                  Icon(icono, size: 20),
                  const SizedBox(width: 8),
                ],
                Flexible(child: Text(texto, textAlign: TextAlign.center)),
              ],
            ),
    );
  }
}

class ClasificacionEnlace extends StatelessWidget {
  const ClasificacionEnlace({
    required this.texto,
    this.icono,
    this.onPressed,
    super.key,
  });
  final String texto;
  final IconData? icono;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      disabledForegroundColor: BarroTheme.primary,
      foregroundColor: BarroTheme.primary,
      padding: EdgeInsets.zero,
      minimumSize: const Size(48, 40),
      textStyle: BarroTheme.type(13, 20, weight: FontWeight.w500),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icono != null) ...[Icon(icono, size: 16), const SizedBox(width: 6)],
        Flexible(child: Text(texto)),
      ],
    ),
  );
}

class ClasificacionPie extends StatelessWidget {
  const ClasificacionPie({
    required this.accion,
    this.iconoAccion,
    this.accionSecundaria,
    this.onContinuar,
    this.onCancelar,
    this.ocupado = false,
    this.textoCancelar = 'Cancelar',
    super.key,
  });
  final String accion;
  final IconData? iconoAccion;
  final Widget? accionSecundaria;
  final VoidCallback? onContinuar;
  final VoidCallback? onCancelar;
  final bool ocupado;
  final String textoCancelar;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (accionSecundaria != null) ...[
        accionSecundaria!,
        const SizedBox(height: 12),
      ],
      ClasificacionBoton(
        accion,
        icono: iconoAccion,
        onPressed: onContinuar,
        ocupado: ocupado,
      ),
      const SizedBox(height: 4),
      Center(
        child: ClasificacionEnlace(
          texto: textoCancelar,
          onPressed: ocupado ? null : onCancelar,
        ),
      ),
    ],
  );
}

class ClasificacionAviso extends StatelessWidget {
  const ClasificacionAviso(
    this.mensaje, {
    this.error = false,
    this.informativo = false,
    this.icono,
    super.key,
  });
  final String mensaje;
  final bool error;

  /// Aviso neutro (fondo suave de la marca) para orientar al usuario.
  final bool informativo;
  final IconData? icono;
  @override
  Widget build(BuildContext context) {
    final color = error
        ? BarroTheme.error
        : informativo
        ? BarroTheme.secondary
        : BarroTheme.success;
    final fondo = error
        ? const Color(0xFFFFF0EE)
        : informativo
        ? clasificacionSuave
        : const Color(0xFFECF7F0);
    final simbolo =
        icono ??
        (error
            ? Icons.error_outline
            : informativo
            ? Icons.info_outline
            : Icons.check_circle_outline);
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              simbolo,
              size: 18,
              color: informativo ? BarroTheme.primary : color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mensaje,
                style: BarroTheme.type(12, 18, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ClasificacionCampo extends StatelessWidget {
  const ClasificacionCampo({
    required this.etiqueta,
    required this.hint,
    this.valor = '',
    this.error,
    this.multilinea = false,
    this.controller,
    this.onChanged,
    this.enabled = true,
    this.maxLength,
    this.icono,
    this.opcional = false,
    this.obligatorio = false,
    this.ayuda,
    this.limpiable = false,
    this.mostrarEtiqueta = true,
    this.textInputAction,
    super.key,
  });
  final String etiqueta;
  final String hint;
  final String valor;
  final String? error;
  final bool multilinea;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final int? maxLength;
  final IconData? icono;
  final bool opcional;
  final bool obligatorio;
  final String? ayuda;

  /// Muestra un botón para borrar el texto (útil en búsquedas).
  final bool limpiable;
  final bool mostrarEtiqueta;
  final TextInputAction? textInputAction;
  @override
  Widget build(BuildContext context) {
    OutlineInputBorder borde(Color color, [double ancho = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: ancho),
        );
    Widget? limpiar;
    if (limpiable && controller != null) {
      limpiar = ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller!,
        builder: (context, valor, _) => valor.text.isEmpty
            ? const SizedBox.shrink()
            : IconButton(
                tooltip: 'Borrar búsqueda',
                icon: const Icon(Icons.close_rounded, size: 20),
                color: BarroTheme.secondary,
                onPressed: enabled
                    ? () {
                        controller!.clear();
                        onChanged?.call('');
                      }
                    : null,
              ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mostrarEtiqueta) ...[
          Text.rich(
            TextSpan(
              text: etiqueta,
              style: BarroTheme.type(13, 19, weight: FontWeight.w600),
              children: [
                if (obligatorio)
                  TextSpan(
                    text: ' *',
                    style: BarroTheme.type(
                      13,
                      19,
                      weight: FontWeight.w600,
                      color: BarroTheme.primary,
                    ),
                  ),
                if (opcional)
                  TextSpan(
                    text: '  (opcional)',
                    style: BarroTheme.type(
                      12,
                      19,
                      color: BarroTheme.placeholder,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          initialValue: controller == null ? valor : null,
          controller: controller,
          onChanged: onChanged,
          readOnly: controller == null && onChanged == null,
          enabled: enabled,
          maxLength: maxLength,
          minLines: multilinea ? 3 : 1,
          maxLines: multilinea ? 5 : 1,
          textCapitalization: TextCapitalization.sentences,
          textInputAction:
              textInputAction ??
              (multilinea ? TextInputAction.newline : TextInputAction.next),
          style: BarroTheme.type(14, 21),
          decoration: InputDecoration(
            hintText: hint,
            semanticCounterText: maxLength == null ? null : 'caracteres',
            counterStyle: BarroTheme.type(
              11,
              16,
              color: BarroTheme.placeholder,
            ),
            hintStyle: BarroTheme.type(14, 21, color: BarroTheme.placeholder),
            helperText: error == null ? ayuda : null,
            helperStyle: BarroTheme.type(12, 18, color: BarroTheme.secondary),
            helperMaxLines: 3,
            filled: true,
            fillColor: enabled ? Colors.white : const Color(0xFFF7F1EE),
            prefixIcon: icono == null
                ? null
                : Padding(
                    padding: EdgeInsets.only(
                      left: 12,
                      right: 8,
                      bottom: multilinea ? 48 : 0,
                    ),
                    child: Icon(icono, size: 20, color: BarroTheme.secondary),
                  ),
            prefixIconConstraints: const BoxConstraints(minWidth: 40),
            suffixIcon: limpiar,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            enabledBorder: borde(
              error == null ? BarroTheme.border : BarroTheme.error,
            ),
            disabledBorder: borde(clasificacionBorde),
            focusedBorder: borde(
              error == null ? BarroTheme.primary : BarroTheme.error,
              1.6,
            ),
            errorText: error,
            errorStyle: BarroTheme.type(12, 18, color: BarroTheme.error),
            errorMaxLines: 3,
            errorBorder: borde(BarroTheme.error),
            focusedErrorBorder: borde(BarroTheme.error, 1.6),
          ),
        ),
      ],
    );
  }
}

class ClasificacionPasos extends StatelessWidget {
  const ClasificacionPasos({
    required this.paso,
    this.editando = false,
    this.pasosDisponibles,
    super.key,
  });
  final PasoArea paso;
  final bool editando;
  final List<PasoArea>? pasosDisponibles;
  @override
  Widget build(BuildContext context) {
    final pasos =
        pasosDisponibles ??
        [
          PasoArea.datos,
          PasoArea.sucursales,
          if (!editando) PasoArea.categorias,
        ];
    final etiquetas = {
      PasoArea.datos: 'Datos del área',
      PasoArea.sucursales: 'Sucursales',
      PasoArea.categorias: 'Categorías',
    };
    final actual = pasos.indexOf(paso);
    return Semantics(
      label: 'Paso ${actual + 1} de ${pasos.length}: ${etiquetas[paso]}',
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < pasos.length; i++) ...[
              if (i > 0)
                Container(
                  width: 24,
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: i <= actual ? BarroTheme.primary : clasificacionBorde,
                ),
              Flexible(
                child: _Paso(
                  numero: i + 1,
                  etiqueta: etiquetas[pasos[i]]!,
                  completado: i < actual,
                  activo: i == actual,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({
    required this.numero,
    required this.etiqueta,
    required this.completado,
    required this.activo,
  });
  final int numero;
  final String etiqueta;
  final bool completado;
  final bool activo;
  @override
  Widget build(BuildContext context) {
    final resaltado = completado || activo;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: resaltado ? BarroTheme.primary : Colors.white,
            border: Border.all(
              color: resaltado ? BarroTheme.primary : BarroTheme.border,
            ),
          ),
          child: completado
              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
              : Text(
                  '$numero',
                  style: BarroTheme.type(
                    12,
                    16,
                    weight: FontWeight.w700,
                    color: activo ? Colors.white : BarroTheme.secondary,
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            etiqueta,
            overflow: TextOverflow.ellipsis,
            style: BarroTheme.type(
              12,
              18,
              weight: activo ? FontWeight.w700 : FontWeight.w500,
              color: resaltado ? BarroTheme.text : BarroTheme.secondary,
            ),
          ),
        ),
      ],
    );
  }
}

class ClasificacionEmptyState extends StatelessWidget {
  const ClasificacionEmptyState({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    this.accion,
    this.iconoAccion = Icons.add_rounded,
    this.onAccion,
    this.compacto = false,
    super.key,
  });
  final IconData icono;
  final String titulo;
  final String descripcion;
  final String? accion;
  final IconData iconoAccion;
  final VoidCallback? onAccion;

  /// Versión con menos aire, para usarse dentro de una sección.
  final bool compacto;
  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.symmetric(vertical: compacto ? 4 : 28),
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: compacto ? 24 : 32),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: clasificacionBorde),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      children: [
        ClasificacionIcono(icono, tamano: compacto ? 56 : 72),
        SizedBox(height: compacto ? 14 : 20),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: BarroTheme.type(
            compacto ? 16 : 19,
            compacto ? 23 : 27,
            weight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          descripcion,
          textAlign: TextAlign.center,
          style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
        ),
        if (accion != null) ...[
          SizedBox(height: compacto ? 16 : 24),
          ClasificacionBoton(accion!, icono: iconoAccion, onPressed: onAccion),
        ],
      ],
    ),
  );
}
