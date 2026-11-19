import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'widgets/negocio_logo_picker.dart';
import 'widgets/negocios_scaffold.dart';

class NegocioFormPage extends StatelessWidget {
  const NegocioFormPage({
    this.editando = false,
    this.nombreInicial = '',
    this.inicialesLogo,
    this.errorNombre,
    this.esloganInicial = '',
    this.errorEslogan,
    this.onEsloganChanged,
    this.mostrarEliminar = false,
    this.logo,
    this.contenidoLogo,
    this.error,
    this.errorLogo,
    this.ocupado = false,
    this.onNombreChanged,
    this.onGuardar,
    this.onCancelar,
    this.onEliminar,
    this.onSeleccionarLogo,
    this.onQuitarLogo,
    super.key,
  });

  final bool editando;
  final String nombreInicial;
  final String? inicialesLogo;
  final String? errorNombre;
  final String esloganInicial;
  final String? errorEslogan;
  final ValueChanged<String>? onEsloganChanged;
  final bool mostrarEliminar;
  final String? logo;
  final Uint8List? contenidoLogo;
  final String? error;
  final String? errorLogo;
  final bool ocupado;
  final ValueChanged<String>? onNombreChanged;
  final VoidCallback? onGuardar;
  final VoidCallback? onCancelar;
  final VoidCallback? onEliminar;
  final VoidCallback? onSeleccionarLogo;
  final VoidCallback? onQuitarLogo;

  @override
  Widget build(BuildContext context) => NegociosScaffold(
    footer: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NegociosPrimaryButton(
          label: ocupado
              ? 'Procesando…'
              : editando
              ? 'Guardar cambios'
              : 'Registrar negocio',
          icon: ocupado
              ? null
              : editando
              ? Icons.check_rounded
              : Icons.add_business_outlined,
          cargando: ocupado,
          onPressed: ocupado ? null : onGuardar,
        ),
        if (editando && mostrarEliminar) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: ocupado ? null : onEliminar,
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            label: const Text('Eliminar negocio'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              disabledForegroundColor: BarroTheme.error.withValues(alpha: 0.5),
              foregroundColor: BarroTheme.error,
              side: BorderSide(color: BarroTheme.error.withValues(alpha: 0.6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: BarroTheme.type(14, 20, weight: FontWeight.w600),
            ),
          ),
        ],
        const SizedBox(height: 4),
        Center(
          child: NegociosTextButton(
            label: 'Cancelar',
            onPressed: ocupado ? null : onCancelar,
          ),
        ),
      ],
    ),
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: NegociosTextButton(
          label: 'Mis negocios',
          icon: Icons.arrow_back,
          onPressed: ocupado ? null : onCancelar,
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: negociosSuave,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              editando ? Icons.edit_note_rounded : Icons.storefront_outlined,
              size: 28,
              color: BarroTheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              editando ? 'Editar negocio' : 'Registrar negocio',
              style: BarroTheme.type(28, 34, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        editando
            ? 'Actualiza el nombre, el eslogan y el logo de tu negocio.'
            : 'Agrega un negocio a tu cuenta.',
        style: BarroTheme.type(14, 20, color: BarroTheme.secondary),
      ),
      const SizedBox(height: 24),
      if (error != null) ...[
        _ErrorBanner(mensaje: error!),
        const SizedBox(height: 16),
      ],
      _Seccion(
        icono: Icons.info_outline_rounded,
        titulo: 'Información general',
        children: [
          _Etiqueta('Nombre del negocio', obligatorio: true),
          const SizedBox(height: 6),
          TextFormField(
            key: ValueKey(nombreInicial),
            initialValue: nombreInicial,
            readOnly: onNombreChanged == null,
            enabled: !ocupado,
            onChanged: onNombreChanged,
            onFieldSubmitted: (_) => ocupado ? null : onGuardar?.call(),
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.words,
            maxLength: 150,
            style: BarroTheme.type(14, 20),
            decoration: _decoracion(
              hint: 'Ej. Cerámica del Centro',
              icono: Icons.storefront_outlined,
              conError: errorNombre != null,
            ).copyWith(counterText: ''),
          ),
          if (errorNombre != null) ...[
            const SizedBox(height: 6),
            _MensajeError(errorNombre!),
          ],
          const SizedBox(height: 18),
          _Etiqueta('Eslogan'),
          const SizedBox(height: 6),
          TextFormField(
            key: ValueKey('eslogan-$esloganInicial'),
            initialValue: esloganInicial,
            readOnly: onEsloganChanged == null,
            enabled: !ocupado,
            onChanged: onEsloganChanged,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 150,
            minLines: 1,
            maxLines: 3,
            style: BarroTheme.type(14, 20),
            decoration:
                _decoracion(
                  hint: 'Ej. La mejor calidad al mejor precio',
                  icono: Icons.format_quote_rounded,
                  conError: errorEslogan != null,
                ).copyWith(
                  helperText: 'Se imprime al pie de los tickets.',
                  helperStyle: BarroTheme.type(
                    12,
                    17,
                    color: BarroTheme.secondary,
                  ),
                  counterStyle: BarroTheme.type(
                    12,
                    17,
                    color: BarroTheme.secondary,
                  ),
                ),
          ),
          if (errorEslogan != null) ...[
            const SizedBox(height: 6),
            _MensajeError(errorEslogan!),
          ],
        ],
      ),
      const SizedBox(height: 16),
      _Seccion(
        icono: Icons.image_outlined,
        titulo: 'Identidad visual',
        children: [
          NegocioLogoPicker(
            iniciales: inicialesLogo,
            logo: logo,
            contenido: contenidoLogo,
            onSeleccionar: ocupado ? null : onSeleccionarLogo,
            onQuitar: ocupado ? null : onQuitarLogo,
          ),
          if (errorLogo != null) ...[
            const SizedBox(height: 6),
            _MensajeError(errorLogo!),
          ],
        ],
      ),
      const SizedBox(height: 16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.lightbulb_outline_rounded,
              size: 16,
              color: BarroTheme.secondary,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '* Campo obligatorio. Puedes continuar sin eslogan ni logo.',
              style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
            ),
          ),
        ],
      ),
    ],
  );

  InputDecoration _decoracion({
    required String hint,
    required IconData icono,
    required bool conError,
  }) => InputDecoration(
    hintText: hint,
    hintStyle: BarroTheme.type(14, 20, color: BarroTheme.placeholder),
    prefixIcon: Icon(
      icono,
      size: 20,
      color: conError ? BarroTheme.error : BarroTheme.placeholder,
    ),
    filled: true,
    fillColor: BarroTheme.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    enabledBorder: _border(conError ? BarroTheme.error : BarroTheme.border),
    disabledBorder: _border(BarroTheme.border),
    focusedBorder: _border(
      conError ? BarroTheme.error : BarroTheme.primary,
      ancho: 1.5,
    ),
  );

  OutlineInputBorder _border(Color color, {double ancho = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: ancho),
      );
}

class _Seccion extends StatelessWidget {
  const _Seccion({
    required this.icono,
    required this.titulo,
    required this.children,
  });

  final IconData icono;
  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: BarroTheme.border.withValues(alpha: 0.7)),
      boxShadow: [
        BoxShadow(
          color: BarroTheme.primary.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: negociosSuave,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icono, size: 18, color: BarroTheme.primary),
            ),
            const SizedBox(width: 10),
            Text(
              titulo,
              style: BarroTheme.type(15, 20, weight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    ),
  );
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto, {this.obligatorio = false});

  final String texto;
  final bool obligatorio;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      text: texto,
      children: [
        if (obligatorio)
          TextSpan(
            text: ' *',
            style: BarroTheme.type(13, 18, color: BarroTheme.primary),
          ),
      ],
    ),
    style: BarroTheme.type(13, 18, weight: FontWeight.w500),
  );
}

class _MensajeError extends StatelessWidget {
  const _MensajeError(this.mensaje);

  final String mensaje;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(top: 1),
        child: Icon(Icons.error_outline, size: 14, color: BarroTheme.error),
      ),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          mensaje,
          style: BarroTheme.type(12, 17, color: BarroTheme.error),
        ),
      ),
    ],
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: BarroTheme.error.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: BarroTheme.error.withValues(alpha: 0.3)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          size: 20,
          color: BarroTheme.error,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            mensaje,
            style: BarroTheme.type(14, 20, color: BarroTheme.error),
          ),
        ),
      ],
    ),
  );
}
