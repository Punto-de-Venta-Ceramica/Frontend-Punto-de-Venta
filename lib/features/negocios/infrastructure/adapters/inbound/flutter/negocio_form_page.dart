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
        if (editando && mostrarEliminar) ...[
          OutlinedButton(
            onPressed: ocupado ? null : onEliminar,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              disabledForegroundColor: BarroTheme.error,
              foregroundColor: BarroTheme.error,
              side: const BorderSide(color: BarroTheme.error),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: BarroTheme.type(14, 20, weight: FontWeight.w600),
            ),
            child: const Text('Eliminar negocio'),
          ),
          const SizedBox(height: 12),
        ],
        NegociosPrimaryButton(
          label: ocupado
              ? 'Procesando…'
              : editando
              ? 'Guardar cambios'
              : 'Registrar negocio',
          onPressed: ocupado ? null : onGuardar,
        ),
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
      const SizedBox(height: 8),
      Text(
        editando ? 'Editar negocio' : 'Registrar negocio',
        style: BarroTheme.type(30, 36, weight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Text(
        editando
            ? 'Actualiza el nombre y el logo de tu negocio.'
            : 'Agrega un negocio a tu cuenta.',
        style: BarroTheme.type(14, 20, color: BarroTheme.secondary),
      ),
      const SizedBox(height: 24),
      if (error != null) ...[
        Text(error!, style: BarroTheme.type(14, 20, color: BarroTheme.error)),
        const SizedBox(height: 16),
      ],
      Text('Nombre del negocio *', style: BarroTheme.type(13, 18)),
      const SizedBox(height: 6),
      TextFormField(
        key: ValueKey(nombreInicial),
        initialValue: nombreInicial,
        readOnly: onNombreChanged == null,
        enabled: !ocupado,
        onChanged: onNombreChanged,
        onFieldSubmitted: (_) => ocupado ? null : onGuardar?.call(),
        textInputAction: TextInputAction.done,
        maxLength: 150,
        style: BarroTheme.type(14, 20),
        decoration: InputDecoration(
          hintText: 'Ej. Cerámica del Centro',
          counterText: '',
          hintStyle: BarroTheme.type(14, 20, color: BarroTheme.placeholder),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          enabledBorder: _border(
            errorNombre == null ? BarroTheme.border : BarroTheme.error,
          ),
          focusedBorder: _border(
            errorNombre == null ? BarroTheme.primary : BarroTheme.error,
          ),
        ),
      ),
      if (errorNombre != null) ...[
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.error_outline,
                size: 14,
                color: BarroTheme.error,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                errorNombre!,
                style: BarroTheme.type(12, 17, color: BarroTheme.error),
              ),
            ),
          ],
        ),
      ],
      const SizedBox(height: 24),
      NegocioLogoPicker(
        iniciales: inicialesLogo,
        logo: logo,
        contenido: contenidoLogo,
        onSeleccionar: ocupado ? null : onSeleccionarLogo,
        onQuitar: ocupado ? null : onQuitarLogo,
      ),
      if (errorLogo != null) ...[
        const SizedBox(height: 6),
        Text(
          errorLogo!,
          style: BarroTheme.type(12, 17, color: BarroTheme.error),
        ),
      ],
      const SizedBox(height: 24),
      Text(
        '* Campo obligatorio. Puedes continuar sin logo.',
        style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
      ),
    ],
  );

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color),
  );
}
