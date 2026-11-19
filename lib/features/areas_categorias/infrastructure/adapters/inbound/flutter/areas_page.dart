import 'package:flutter/material.dart';
import 'widgets/clasificacion_cards.dart';
import 'widgets/clasificacion_estado.dart';
import 'widgets/clasificacion_scaffold.dart';
import 'widgets/clasificacion_vista.dart';
import 'widgets/clasificacion_widgets.dart';

class AreasPage extends StatelessWidget {
  const AreasPage({
    required this.negocio,
    this.areas = const [],
    this.cargando = false,
    this.error,
    this.filtrando = false,
    this.busquedaController,
    this.onBuscar,
    this.onRegistrar,
    this.onVerArea,
    this.onVolver,
    this.onReintentar,
    this.onActualizar,
    super.key,
  });
  final String negocio;
  final List<AreaVista> areas;
  final bool cargando;
  final String? error;
  final bool filtrando;
  final TextEditingController? busquedaController;
  final ValueChanged<String>? onBuscar;
  final VoidCallback? onRegistrar;
  final ValueChanged<int>? onVerArea;
  final VoidCallback? onVolver;
  final VoidCallback? onReintentar;
  final Future<void> Function()? onActualizar;

  @override
  Widget build(BuildContext context) => ClasificacionScaffold(
    negocio: negocio,
    volver: onVolver == null ? null : 'Mi negocio',
    onVolver: onVolver,
    onActualizar: onActualizar,
    children: [
      if (cargando || error != null) ...[
        const ClasificacionTitulo(
          'Áreas',
          icono: iconoArea,
          descripcion: 'Administra las áreas de tu negocio.',
        ),
        ClasificacionEstado(
          cargando: cargando,
          error: error,
          onReintentar: onReintentar,
        ),
      ] else if (areas.isEmpty && !filtrando) ...[
        const ClasificacionTitulo(
          'Áreas',
          icono: iconoArea,
          descripcion: 'Organiza tu catálogo en áreas y categorías.',
        ),
        ClasificacionEmptyState(
          icono: iconoArea,
          titulo: 'Agrega tu primera área',
          descripcion:
              'Las áreas agrupan tus categorías, por ejemplo Cocina o Jardín.',
          accion: 'Registrar mi primera área',
          onAccion: onRegistrar,
        ),
      ] else ...[
        const ClasificacionTitulo(
          'Áreas',
          icono: iconoArea,
          descripcion: 'Administra las áreas de tu negocio.',
        ),
        const SizedBox(height: 20),
        ClasificacionCampo(
          etiqueta: 'Buscar área',
          hint: 'Buscar por nombre o descripción',
          controller: busquedaController,
          onChanged: onBuscar,
          icono: Icons.search_rounded,
          limpiable: true,
          mostrarEtiqueta: false,
          textInputAction: TextInputAction.search,
        ),
        const SizedBox(height: 16),
        ClasificacionBoton(
          'Registrar área',
          icono: Icons.add_rounded,
          onPressed: onRegistrar,
        ),
        const SizedBox(height: 24),
        ClasificacionSeccion(
          filtrando ? 'Resultados' : 'Tus áreas',
          contador: areas.length,
        ),
        const SizedBox(height: 12),
        if (areas.isEmpty)
          const ClasificacionEmptyState(
            compacto: true,
            icono: Icons.search_off_rounded,
            titulo: 'No se encontraron áreas',
            descripcion: 'Prueba con otro nombre o descripción.',
          ),
        for (var i = 0; i < areas.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          AreaCard(
            area: areas[i],
            onVer: onVerArea == null || areas[i].id == null
                ? null
                : () => onVerArea!(areas[i].id!),
          ),
        ],
      ],
    ],
  );
}
