import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'clasificacion_widgets.dart';

class AccesoAreasCategorias extends StatelessWidget {
  const AccesoAreasCategorias({
    this.onPressed,
    this.icono = Icons.category_outlined,
    this.titulo = 'Áreas y categorías',
    this.descripcion = 'Organiza el catálogo de tu negocio.',
    super.key,
  });
  final VoidCallback? onPressed;
  final IconData icono;
  final String titulo;
  final String descripcion;
  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.all(16),
      disabledForegroundColor: BarroTheme.text,
      foregroundColor: BarroTheme.text,
      backgroundColor: Colors.white,
      disabledBackgroundColor: Colors.white,
      side: const BorderSide(color: clasificacionBorde),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      alignment: Alignment.centerLeft,
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: clasificacionSuave,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icono, color: BarroTheme.primary, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: BarroTheme.type(17, 24, weight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                descripcion,
                style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right, color: BarroTheme.primary),
      ],
    ),
  );
}
