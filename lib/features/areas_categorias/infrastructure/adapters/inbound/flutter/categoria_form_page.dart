import 'package:flutter/material.dart';
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
      accion: editando ? 'Guardar cambios' : 'Guardar categoría',
      iconoAccion: Icons.check_rounded,
      onContinuar: onGuardar,
      onCancelar: onCancelar,
      ocupado: ocupado,
    ),
    children: [
      ClasificacionTitulo(
        editando ? 'Editar categoría' : 'Registrar categoría',
        icono: editando ? Icons.edit_outlined : iconoCategoria,
        descripcion: editando
            ? 'Actualiza el nombre o la descripción de la categoría.'
            : 'Agrega una categoría dentro del área.',
      ),
      if (areaNombre != null) ...[
        const SizedBox(height: 16),
        ClasificacionContexto(
          etiqueta: 'Pertenece al área',
          valor: areaNombre!,
        ),
      ],
      const SizedBox(height: 24),
      if (error != null) ...[
        ClasificacionAviso(error!, error: true),
        const SizedBox(height: 16),
      ],
      ClasificacionCampo(
        etiqueta: 'Nombre de la categoría',
        obligatorio: true,
        icono: iconoCategoria,
        hint: 'Ej. Macetas',
        ayuda: 'Así aparecerá al clasificar tus productos.',
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
        opcional: true,
        hint: 'Ej. Macetas de barro de distintos tamaños.',
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
