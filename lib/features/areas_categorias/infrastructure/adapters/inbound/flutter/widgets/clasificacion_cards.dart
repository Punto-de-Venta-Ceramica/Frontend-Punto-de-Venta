import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'clasificacion_vista.dart';
import 'clasificacion_widgets.dart';

class AreaCard extends StatelessWidget {
  const AreaCard({
    required this.area,
    this.mostrarAcceso = true,
    this.onVer,
    super.key,
  });
  final AreaVista area;
  final bool mostrarAcceso;
  final VoidCallback? onVer;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: clasificacionBorde),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          area.nombre,
          style: BarroTheme.type(18, 25, weight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          area.descripcion,
          style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
        ),
        if (mostrarAcceso) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${area.categorias} ${area.categorias == 1 ? 'categoría' : 'categorías'}',
                  style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
                ),
              ),
              ClasificacionEnlace(texto: 'Ver área →', onPressed: onVer),
            ],
          ),
        ],
      ],
    ),
  );
}

class CategoriaCard extends StatelessWidget {
  const CategoriaCard({
    required this.categoria,
    this.onEditar,
    this.onEliminar,
    this.mostrarEliminar = true,
    super.key,
  });
  final CategoriaVista categoria;
  final VoidCallback? onEditar;
  final VoidCallback? onEliminar;
  final bool mostrarEliminar;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 10, 16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: clasificacionBorde),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                categoria.nombre,
                style: BarroTheme.type(17, 24, weight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 6),
            _AccionCategoria(
              icono: Icons.edit_outlined,
              etiqueta: 'Editar categoría',
              onPressed: onEditar,
            ),
            if (mostrarEliminar) ...[
              const SizedBox(width: 4),
              _AccionCategoria(
                icono: Icons.delete_outline,
                etiqueta: 'Eliminar categoría',
                onPressed: onEliminar,
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Text(
            categoria.descripcion,
            style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
          ),
        ),
      ],
    ),
  );
}

class _AccionCategoria extends StatelessWidget {
  const _AccionCategoria({
    required this.icono,
    required this.etiqueta,
    this.onPressed,
  });
  final IconData icono;
  final String etiqueta;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: etiqueta,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      minimumSize: const Size(40, 40),
      disabledBackgroundColor: clasificacionSuave,
      disabledForegroundColor: BarroTheme.primary,
      backgroundColor: clasificacionSuave,
      foregroundColor: BarroTheme.primary,
    ),
    icon: Icon(icono, size: 21),
  );
}

class SucursalClasificacionCard extends StatelessWidget {
  const SucursalClasificacionCard({
    required this.sucursal,
    this.unica = false,
    super.key,
  });
  final SucursalVista sucursal;
  final bool unica;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: BarroTheme.primary),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (!unica) ...[
              Checkbox(
                value: sucursal.seleccionada,
                onChanged: null,
                visualDensity: VisualDensity.compact,
                fillColor: WidgetStatePropertyAll(
                  sucursal.seleccionada ? BarroTheme.primary : Colors.white,
                ),
                checkColor: Colors.white,
                side: const BorderSide(color: BarroTheme.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                sucursal.nombre,
                style: BarroTheme.type(14, 21, weight: FontWeight.w600),
              ),
            ),
          ],
        ),
        if (!sucursal.seleccionada && !unica) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: clasificacionSuave,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Selecciona la sucursal para agregar el área.',
              style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
            ),
          ),
        ],
      ],
    ),
  );
}
