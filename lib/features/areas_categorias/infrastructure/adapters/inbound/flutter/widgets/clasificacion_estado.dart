import 'package:flutter/material.dart';
import 'clasificacion_widgets.dart';

class ClasificacionEstado extends StatelessWidget {
  const ClasificacionEstado({
    this.cargando = false,
    this.error,
    this.onReintentar,
    super.key,
  });
  final bool cargando;
  final String? error;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: cargando
        ? const Center(child: CircularProgressIndicator())
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClasificacionAviso(
                error ?? 'No se pudo cargar el catálogo.',
                error: true,
              ),
              const SizedBox(height: 12),
              Center(
                child: ClasificacionEnlace(
                  texto: 'Reintentar',
                  onPressed: onReintentar,
                ),
              ),
            ],
          ),
  );
}
