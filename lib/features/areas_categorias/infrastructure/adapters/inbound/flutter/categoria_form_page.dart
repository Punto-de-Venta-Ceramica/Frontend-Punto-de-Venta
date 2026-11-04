import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'widgets/clasificacion_scaffold.dart';
import 'widgets/clasificacion_widgets.dart';

class CategoriaFormPage extends StatelessWidget {
  const CategoriaFormPage({
    required this.negocio,
    this.editando = false,
    this.nombre = '',
    this.descripcion = '',
    this.errorNombre,
    this.errorDescripcion,
    this.error,
    this.areaNombre,
    this.nombreController,
    this.descripcionController,
    this.onNombreChanged,
    this.onDescripcionChanged,
    this.onGuardar,
    this.onCancelar,
    this.ocupado = false,
    super.key,
  });
  final String negocio;
  final bool editando;
  final String nombre;
  final String descripcion;
  final String? errorNombre;
  final String? errorDescripcion;
  final String? error;
  final String? areaNombre;
  final TextEditingController? nombreController;
  final TextEditingController? descripcionController;
  final ValueChanged<String>? onNombreChanged;
  final ValueChanged<String>? onDescripcionChanged;
  final VoidCallback? onGuardar;
  final VoidCallback? onCancelar;
  final bool ocupado;

  @override
  Widget build(BuildContext context) => ClasificacionScaffold(
    negocio: negocio,
    volver: 'Categorías',
    onVolver: ocupado ? null : onCancelar,
    footer: ClasificacionPie(
      accion: 'Guardar',
      onContinuar: onGuardar,
      onCancelar: onCancelar,
      ocupado: ocupado,
    ),
    children: [
      ClasificacionTitulo(
        editando ? 'Editar categoría' : 'Registrar categoría',
        descripcion: editando
            ? 'Actualiza tu categoría.'
            : 'Agrega una categoría a tu negocio.',
      ),
      if (areaNombre != null) ...[
        const SizedBox(height: 12),
        Text(
          'Área: $areaNombre',
          style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
        ),
      ],
      const SizedBox(height: 24),
      if (error != null) ...[
        ClasificacionAviso(error!, error: true),
        const SizedBox(height: 16),
      ],
      ClasificacionCampo(
        etiqueta: 'Nombre de la categoría *',
        hint: 'Ej. Maceta',
        valor: nombre,
        controller: nombreController,
        onChanged: onNombreChanged,
        error: errorNombre,
        enabled: !ocupado,
        maxLength: 100,
      ),
      const SizedBox(height: 20),
      ClasificacionCampo(
        etiqueta: 'Descripción',
        hint: 'Ej. Categoría enfocada a artículos de tipo maceta.',
        valor: descripcion,
        controller: descripcionController,
        onChanged: onDescripcionChanged,
        error: errorDescripcion,
        enabled: !ocupado,
        multilinea: true,
      ),
    ],
  );
}
