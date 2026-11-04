import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'widgets/clasificacion_cards.dart';
import 'widgets/clasificacion_estado.dart';
import 'widgets/clasificacion_scaffold.dart';
import 'widgets/clasificacion_vista.dart';
import 'widgets/clasificacion_widgets.dart';

class AreasPage extends StatelessWidget {
  const AreasPage({
    required this.negocio,
    this.areas = const [],
    this.mensaje,
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
  final String? mensaje;
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
    mostrarNavegacion: true,
    volver: onVolver == null ? null : 'Mi negocio',
    onVolver: onVolver,
    onActualizar: onActualizar,
    children: [
      if (cargando || error != null) ...[
        const ClasificacionTitulo(
          'Áreas',
          descripcion: 'Administra las áreas de tu negocio.',
        ),
        ClasificacionEstado(
          cargando: cargando,
          error: error,
          onReintentar: onReintentar,
        ),
      ] else if (areas.isEmpty && !filtrando) ...[
        Text(
          'Tus áreas, organizadas por negocio.',
          style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
        ),
        if (mensaje != null) ...[
          const SizedBox(height: 16),
          ClasificacionAviso(mensaje!),
        ],
        ClasificacionEmptyState(
          simbolo: 'Á',
          titulo: 'Agrega tu primera área',
          descripcion: 'Registra su nombre y descripción.',
          accion: 'Registrar mi primera área',
          onAccion: onRegistrar,
        ),
      ] else ...[
        const ClasificacionTitulo(
          'Áreas',
          descripcion: 'Administra las áreas de tu negocio.',
        ),
        if (mensaje != null) ...[
          const SizedBox(height: 16),
          ClasificacionAviso(mensaje!),
        ],
        const SizedBox(height: 20),
        ClasificacionCampo(
          etiqueta: 'Buscar área',
          hint: 'Buscar área…',
          controller: busquedaController,
          onChanged: onBuscar,
        ),
        const SizedBox(height: 16),
        ClasificacionBoton('+ Registrar área', onPressed: onRegistrar),
        const SizedBox(height: 24),
        Text(
          '${areas.length} ${filtrando ? (areas.length == 1 ? 'resultado' : 'resultados') : (areas.length == 1 ? 'área registrada' : 'áreas registradas')}',
          style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
        ),
        const SizedBox(height: 12),
        if (areas.isEmpty)
          const ClasificacionEmptyState(
            simbolo: '?',
            titulo: 'No se encontraron áreas',
            descripcion: 'Prueba con otro nombre o descripción.',
          ),
        for (var i = 0; i < areas.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
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
