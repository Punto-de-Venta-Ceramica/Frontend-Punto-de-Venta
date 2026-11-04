import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'clasificacion_vista.dart';
import 'clasificacion_widgets.dart';

class ConfirmarEliminarClasificacionDialog extends StatelessWidget {
  const ConfirmarEliminarClasificacionDialog({
    required this.tipo,
    required this.nombre,
    required this.negocio,
    this.onConfirmar,
    this.onCancelar,
    this.ocupado = false,
    this.error,
    super.key,
  });
  final TipoClasificacion tipo;
  final String nombre;
  final String negocio;
  final VoidCallback? onConfirmar;
  final VoidCallback? onCancelar;
  final bool ocupado;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final esArea = tipo == TipoClasificacion.area;
    final recurso = esArea ? 'área' : 'categoría';
    return Dialog(
      backgroundColor: BarroTheme.background,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEDE8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.priority_high,
                    color: BarroTheme.error,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '¿Eliminar $recurso?',
                style: BarroTheme.type(23, 30, weight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                esArea
                    ? 'Se eliminará esta área y sus categorías del negocio $negocio.'
                    : 'Se eliminará esta categoría del negocio $negocio.',
                style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
              ),
              const SizedBox(height: 12),
              Text(
                nombre,
                style: BarroTheme.type(15, 22, weight: FontWeight.w700),
              ),
              if (error != null) ...[
                const SizedBox(height: 16),
                ClasificacionAviso(error!, error: true),
              ],
              const SizedBox(height: 24),
              ClasificacionBoton(
                'Eliminar $recurso',
                destructivo: true,
                ocupado: ocupado,
                onPressed: onConfirmar,
              ),
              const SizedBox(height: 8),
              Center(
                child: ClasificacionEnlace(
                  texto: 'Cancelar',
                  onPressed: ocupado ? null : onCancelar,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
