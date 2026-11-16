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
  Widget build(BuildContext context) {
    final contenido = Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ClasificacionIcono(iconoArea),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  area.nombre,
                  style: BarroTheme.type(17, 24, weight: FontWeight.w700),
                ),
                if (area.descripcion.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    area.descripcion,
                    maxLines: mostrarAcceso ? 2 : null,
                    overflow: mostrarAcceso ? TextOverflow.ellipsis : null,
                    style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
                  ),
                ] else if (!mostrarAcceso) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Sin descripción',
                    style: BarroTheme.type(
                      13,
                      20,
                      color: BarroTheme.placeholder,
                    ),
                  ),
                ],
                if (mostrarAcceso) ...[
                  const SizedBox(height: 10),
                  ClasificacionChip(
                    '${area.categorias} ${area.categorias == 1 ? 'categoría' : 'categorías'}',
                    icono: iconoCategoria,
                  ),
                ],
              ],
            ),
          ),
          if (mostrarAcceso) ...[
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Icon(
                Icons.chevron_right_rounded,
                color: onVer == null
                    ? BarroTheme.placeholder
                    : BarroTheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
    final forma = RoundedRectangleBorder(
      side: const BorderSide(color: clasificacionBorde),
      borderRadius: BorderRadius.circular(16),
    );
    return Semantics(
      button: mostrarAcceso,
      label: mostrarAcceso ? 'Ver área ${area.nombre}' : null,
      child: Material(
        color: Colors.white,
        shape: forma,
        clipBehavior: Clip.antiAlias,
        child: mostrarAcceso
            ? InkWell(onTap: onVer, child: contenido)
            : contenido,
      ),
    );
  }
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
    padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: clasificacionBorde),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ClasificacionIcono(iconoCategoria, tamano: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                categoria.nombre,
                style: BarroTheme.type(16, 23, weight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                categoria.descripcion.trim().isEmpty
                    ? 'Sin descripción'
                    : categoria.descripcion,
                style: BarroTheme.type(
                  13,
                  20,
                  color: categoria.descripcion.trim().isEmpty
                      ? BarroTheme.placeholder
                      : BarroTheme.secondary,
                ),
              ),
            ],
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
            destructivo: true,
            onPressed: onEliminar,
          ),
        ],
      ],
    ),
  );
}

class _AccionCategoria extends StatelessWidget {
  const _AccionCategoria({
    required this.icono,
    required this.etiqueta,
    this.destructivo = false,
    this.onPressed,
  });
  final IconData icono;
  final String etiqueta;
  final bool destructivo;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: etiqueta,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      minimumSize: const Size(40, 40),
      disabledBackgroundColor: clasificacionSuave,
      disabledForegroundColor: BarroTheme.placeholder,
      backgroundColor: destructivo
          ? const Color(0xFFFFF0EE)
          : clasificacionSuave,
      foregroundColor: destructivo ? BarroTheme.error : BarroTheme.primary,
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
