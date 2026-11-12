import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/empleados/domain/empleado.dart';

class EmpleadoCard extends StatelessWidget {
  const EmpleadoCard({
    required this.empleado,
    required this.onEliminar,
    this.onCambiarSucursal,
    super.key,
  });

  final Empleado empleado;
  final VoidCallback onEliminar;
  final VoidCallback? onCambiarSucursal;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: BarroTheme.border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF9EDE8),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            empleado.inicial,
            style: BarroTheme.type(
              20,
              26,
              weight: FontWeight.w700,
              color: BarroTheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                empleado.nombreCompleto,
                style: BarroTheme.type(16, 22, weight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                empleado.correoElectronico,
                style: BarroTheme.type(13, 18, color: BarroTheme.placeholder),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              _buildSucursalBadge(),
            ],
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onEliminar,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.delete_outline_rounded,
                  color: BarroTheme.primary,
                  size: 24,
                ),
                const SizedBox(height: 2),
                Text(
                  'Eliminar',
                  style: BarroTheme.type(
                    11,
                    15,
                    weight: FontWeight.w600,
                    color: BarroTheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildSucursalBadge() {
    final tieneSucursal = empleado.asignado;
    final color = tieneSucursal ? BarroTheme.success : BarroTheme.secondary;
    final fondo = tieneSucursal
        ? const Color(0xFFECF7F0)
        : const Color(0xFFF4EDE9);

    Widget etiqueta(String texto, {bool editable = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            tieneSucursal ? Icons.store_outlined : Icons.storefront_outlined,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              texto,
              style: BarroTheme.type(
                11,
                15,
                weight: FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (editable) ...[
            const SizedBox(width: 4),
            Icon(Icons.edit_outlined, size: 11, color: color),
          ],
        ],
      ),
    );

    final etiquetas = tieneSucursal
        ? [
            for (var i = 0; i < empleado.sucursales.length; i++)
              etiqueta(
                empleado.sucursales[i].nombre,
                editable:
                    onCambiarSucursal != null &&
                    i == empleado.sucursales.length - 1,
              ),
          ]
        : [
            etiqueta(
              'Sin sucursal asignada',
              editable: onCambiarSucursal != null,
            ),
          ];

    final wrap = Wrap(spacing: 6, runSpacing: 6, children: etiquetas);
    if (onCambiarSucursal == null) return wrap;
    return InkWell(
      onTap: onCambiarSucursal,
      borderRadius: BorderRadius.circular(8),
      child: wrap,
    );
  }
}
