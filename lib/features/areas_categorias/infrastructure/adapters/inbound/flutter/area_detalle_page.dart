import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
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
    this.mensaje,
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
  final String? mensaje;
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
              ClasificacionBoton('Editar área', onPressed: onEditarArea),
              if (mostrarEliminar) ...[
                const SizedBox(height: 12),
                ClasificacionBoton(
                  'Eliminar área',
                  destructivo: true,
                  outlined: true,
                  onPressed: onEliminarArea,
                ),
              ],
            ],
          ),
    children: [
      const ClasificacionTitulo('Detalle del área'),
      const SizedBox(height: 24),
      if (cargando || error != null)
        ClasificacionEstado(
          cargando: cargando,
          error: error,
          onReintentar: onReintentar,
        )
      else ...[
        if (mensaje != null) ...[
          ClasificacionAviso(mensaje!),
          const SizedBox(height: 12),
        ],
        AreaCard(area: area, mostrarAcceso: false),
        const SizedBox(height: 28),
        Text(
          'Categorías',
          style: BarroTheme.type(21, 28, weight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ClasificacionBoton(
          '+ Registrar categoría',
          onPressed: onRegistrarCategoria,
        ),
        const SizedBox(height: 20),
        Text(
          '${categorias.length} ${categorias.length == 1 ? 'categoría registrada' : 'categorías registradas'}',
          style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < categorias.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
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
