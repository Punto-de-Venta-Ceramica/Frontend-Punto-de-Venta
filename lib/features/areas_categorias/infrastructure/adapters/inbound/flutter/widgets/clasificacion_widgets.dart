import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'clasificacion_vista.dart';

const clasificacionSuave = Color(0xFFF8E7DF);
const clasificacionBorde = Color(0xFFE8DAD3);

class ClasificacionTitulo extends StatelessWidget {
  const ClasificacionTitulo(this.titulo, {this.descripcion, super.key});
  final String titulo;
  final String? descripcion;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(titulo, style: BarroTheme.type(28, 35, weight: FontWeight.w700)),
      if (descripcion != null) ...[
        const SizedBox(height: 4),
        Text(
          descripcion!,
          style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
        ),
      ],
    ],
  );
}

class ClasificacionBoton extends StatelessWidget {
  const ClasificacionBoton(
    this.texto, {
    this.destructivo = false,
    this.outlined = false,
    this.onPressed,
    this.ocupado = false,
    super.key,
  });
  final String texto;
  final bool destructivo;
  final bool outlined;
  final VoidCallback? onPressed;
  final bool ocupado;
  @override
  Widget build(BuildContext context) {
    final color = destructivo ? BarroTheme.error : BarroTheme.primary;
    final estilo = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      backgroundColor: WidgetStatePropertyAll(
        outlined ? Colors.transparent : color,
      ),
      foregroundColor: WidgetStatePropertyAll(outlined ? color : Colors.white),
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
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(texto, textAlign: TextAlign.center),
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
    this.accionSecundaria,
    this.onContinuar,
    this.onCancelar,
    this.ocupado = false,
    this.textoCancelar = 'Cancelar',
    super.key,
  });
  final String accion;
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
      ClasificacionBoton(accion, onPressed: onContinuar, ocupado: ocupado),
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
  const ClasificacionAviso(this.mensaje, {this.error = false, super.key});
  final String mensaje;
  final bool error;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: error ? const Color(0xFFFFF0EE) : const Color(0xFFECF7F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        mensaje,
        style: BarroTheme.type(
          12,
          18,
          color: error ? BarroTheme.error : BarroTheme.success,
        ),
      ),
    ),
  );
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
  @override
  Widget build(BuildContext context) {
    OutlineInputBorder borde(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: BarroTheme.type(13, 19, weight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: controller == null ? valor : null,
          controller: controller,
          onChanged: onChanged,
          readOnly: controller == null && onChanged == null,
          enabled: enabled,
          maxLength: maxLength,
          minLines: multilinea ? 3 : 1,
          maxLines: multilinea ? 4 : 1,
          style: BarroTheme.type(14, 21),
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            hintStyle: BarroTheme.type(14, 21, color: BarroTheme.placeholder),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            enabledBorder: borde(
              error == null ? BarroTheme.border : BarroTheme.error,
            ),
            focusedBorder: borde(
              error == null ? BarroTheme.border : BarroTheme.error,
            ),
            errorText: error,
            errorStyle: BarroTheme.type(12, 18, color: BarroTheme.error),
            errorMaxLines: 3,
            errorBorder: borde(BarroTheme.error),
            focusedErrorBorder: borde(BarroTheme.error),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < pasos.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
              decoration: BoxDecoration(
                color: pasos[i] == paso ? clasificacionSuave : Colors.white,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                '${i + 1}. ${etiquetas[pasos[i]]}',
                textAlign: TextAlign.center,
                style: BarroTheme.type(
                  10,
                  15,
                  weight: FontWeight.w600,
                  color: pasos[i] == paso
                      ? BarroTheme.primary
                      : BarroTheme.secondary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class ClasificacionEmptyState extends StatelessWidget {
  const ClasificacionEmptyState({
    required this.simbolo,
    required this.titulo,
    required this.descripcion,
    this.accion,
    this.onAccion,
    super.key,
  });
  final String simbolo;
  final String titulo;
  final String descripcion;
  final String? accion;
  final VoidCallback? onAccion;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(
      children: [
        Container(
          width: 76,
          height: 76,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: clasificacionSuave,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            simbolo,
            style: BarroTheme.type(
              38,
              46,
              weight: FontWeight.w600,
              color: BarroTheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: BarroTheme.type(19, 27, weight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          descripcion,
          textAlign: TextAlign.center,
          style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
        ),
        if (accion != null) ...[
          const SizedBox(height: 24),
          ClasificacionBoton(accion!, onPressed: onAccion),
        ],
      ],
    ),
  );
}
