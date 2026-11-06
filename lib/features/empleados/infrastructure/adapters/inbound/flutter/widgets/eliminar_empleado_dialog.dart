import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/empleados/domain/empleado.dart';

class EliminarEmpleadoDialog extends StatelessWidget {
  const EliminarEmpleadoDialog({
    required this.empleado,
    required this.onConfirmar,
    this.ocupado = false,
    super.key,
  });

  final Empleado empleado;
  final VoidCallback onConfirmar;
  final bool ocupado;

  @override
  Widget build(BuildContext context) => Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    backgroundColor: Colors.white,
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFF9ECE8),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: BarroTheme.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '¿Eliminar empleado?',
              textAlign: TextAlign.center,
              style: BarroTheme.type(22, 28, weight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              empleado.nombreCompleto,
              textAlign: TextAlign.center,
              style: BarroTheme.type(
                18,
                24,
                weight: FontWeight.w600,
                color: BarroTheme.text,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${empleado.nombreCompleto} ya no podrá acceder al negocio después de eliminar su cuenta.',
              textAlign: TextAlign.center,
              style: BarroTheme.type(14, 21, color: BarroTheme.secondary),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: BarroTheme.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        foregroundColor: BarroTheme.text,
                      ),
                      onPressed: ocupado ? null : () => Navigator.pop(context),
                      child: Text(
                        'Cancelar',
                        style: BarroTheme.type(
                          14,
                          20,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: BarroTheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: ocupado ? null : onConfirmar,
                      child: ocupado
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Eliminar empleado',
                              textAlign: TextAlign.center,
                              style: BarroTheme.type(
                                14,
                                20,
                                weight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
