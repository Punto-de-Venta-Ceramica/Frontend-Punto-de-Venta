import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/empleados/domain/empleado.dart';
import 'empleados_vacio.dart';

class EmpleadoCard extends StatelessWidget {
  const EmpleadoCard({
    required this.empleado,
    required this.onEliminar,
    this.onCambiarSucursal,
    super.key,
  });

  final Empleado empleado;
  final VoidCallback onEliminar;

  /// Con valor, se muestra la acción para gestionar sus sucursales.
  final VoidCallback? onCambiarSucursal;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(21),
      border: Border.all(color: BarroTheme.border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A1E1B19),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Row(
            children: [
              EmpleadoAvatar(empleado.inicial),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      empleado.nombreCompleto,
                      style: BarroTheme.type(17, 23, weight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.mail_outline_rounded,
                          size: 14,
                          color: BarroTheme.placeholder,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            empleado.correoElectronico,
                            style: BarroTheme.type(
                              13,
                              18,
                              color: BarroTheme.placeholder,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: const Color(0xFFFCF4F0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.storefront_outlined,
                    size: 15,
                    color: BarroTheme.secondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'SUCURSALES',
                    style: BarroTheme.type(
                      11,
                      16,
                      weight: FontWeight.w700,
                      color: BarroTheme.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: empleado.asignado
                    ? [
                        for (final s in empleado.sucursales)
                          _Etiqueta(s.nombre, asignada: true),
                      ]
                    : const [
                        _Etiqueta('Sin sucursal asignada', asignada: false),
                      ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              if (onCambiarSucursal != null)
                TextButton.icon(
                  key: ValueKey('empleado-sucursales-${empleado.id}'),
                  onPressed: onCambiarSucursal,
                  style: TextButton.styleFrom(
                    foregroundColor: BarroTheme.primary,
                  ),
                  icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                  label: const Text('Sucursales'),
                ),
              const Spacer(),
              TextButton.icon(
                key: ValueKey('empleado-eliminar-${empleado.id}'),
                onPressed: onEliminar,
                style: TextButton.styleFrom(foregroundColor: BarroTheme.error),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Eliminar'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto, {required this.asignada});
  final String texto;
  final bool asignada;

  @override
  Widget build(BuildContext context) {
    final color = asignada ? BarroTheme.success : BarroTheme.placeholder;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: asignada ? const Color(0xFFE6F4EC) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: asignada ? const Color(0xFFBFE0CD) : BarroTheme.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            asignada ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BarroTheme.type(
                12,
                16,
                weight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
