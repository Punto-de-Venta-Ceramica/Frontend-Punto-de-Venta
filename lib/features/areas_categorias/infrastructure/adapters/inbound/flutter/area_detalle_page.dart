import 'package:flutter/material.dart';
import 'widgets/clasificacion_cards.dart';
import 'widgets/clasificacion_estado.dart';
import 'widgets/clasificacion_scaffold.dart';
import 'widgets/clasificacion_vista.dart';
import 'widgets/clasificacion_widgets.dart';

class AreaDetallePage extends StatelessWidget {
  const AreaDetallePage({
    required this.negocio,
    required this.area,
    this.categorias = const [],
    this.cargando = false,
    this.error,
    this.onVolver,
    this.onEditarArea,
    this.onRegistrarCategoria,
    this.onEditarCategoria,
    this.onEliminarArea,
    this.onEliminarCategoria,
    this.onReintentar,
    this.onActualizar,
    this.mostrarEliminar = true,
    super.key,
  });
  final String negocio;
  final AreaVista area;
  final List<CategoriaVista> categorias;
  final bool cargando;
  final String? error;
  final VoidCallback? onVolver;
  final VoidCallback? onEditarArea;
  final VoidCallback? onRegistrarCategoria;
  final ValueChanged<int>? onEditarCategoria;
  final VoidCallback? onEliminarArea;
  final ValueChanged<int>? onEliminarCategoria;
  final VoidCallback? onReintentar;
  final Future<void> Function()? onActualizar;
  final bool mostrarEliminar;

  @override
  Widget build(BuildContext context) => ClasificacionScaffold(
    negocio: negocio,
    volver: 'Áreas',
    onVolver: onVolver,
    onActualizar: onActualizar,
    footer: cargando || error != null
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClasificacionBoton(
                'Editar área',
                icono: Icons.edit_outlined,
                onPressed: onEditarArea,
              ),
              if (mostrarEliminar) ...[
                const SizedBox(height: 12),
                ClasificacionBoton(
                  'Eliminar área',
                  icono: Icons.delete_outline,
                  destructivo: true,
                  outlined: true,
                  onPressed: onEliminarArea,
                ),
              ],
            ],
          ),
    children: [
      const ClasificacionTitulo(
        'Detalle del área',
        icono: iconoArea,
        descripcion: 'Consulta el área y administra sus categorías.',
      ),
      const SizedBox(height: 24),
      if (cargando || error != null)
        ClasificacionEstado(
          cargando: cargando,
          error: error,
          onReintentar: onReintentar,
        )
      else ...[
        AreaCard(area: area, mostrarAcceso: false),
        const SizedBox(height: 28),
        ClasificacionSeccion(
          'Categorías',
          icono: iconoCategoria,
          contador: categorias.length,
        ),
        const SizedBox(height: 12),
        if (categorias.isEmpty)
          ClasificacionEmptyState(
            compacto: true,
            icono: iconoCategoria,
            titulo: 'Sin categorías todavía',
            descripcion: 'Agrega categorías para clasificar tus productos.',
            accion: 'Registrar categoría',
            onAccion: onRegistrarCategoria,
          )
        else ...[
          ClasificacionBoton(
            'Registrar categoría',
            icono: Icons.add_rounded,
            outlined: true,
            onPressed: onRegistrarCategoria,
          ),
          const SizedBox(height: 16),
        ],
        for (var i = 0; i < categorias.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          CategoriaCard(
            categoria: categorias[i],
            mostrarEliminar: mostrarEliminar,
            onEditar: onEditarCategoria == null || categorias[i].id == null
                ? null
                : () => onEditarCategoria!(categorias[i].id!),
            onEliminar: onEliminarCategoria == null || categorias[i].id == null
                ? null
                : () => onEliminarCategoria!(categorias[i].id!),
          ),
        ],
      ],
    ],
  );
}
