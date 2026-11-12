import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/productos/domain/producto.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_widgets.dart';

/// Pantalla principal del empleado. El corte de caja aún está en desarrollo.
class CajaPage extends StatelessWidget {
  const CajaPage({
    required this.negocio,
    required this.sucursalNombre,
    super.key,
  });

  final NegocioProducto negocio;
  final String sucursalNombre;

  @override
  Widget build(BuildContext context) => ProductoScaffold(
    children: [
      const SizedBox(height: 20),
      ProductoNegocioPanel(negocio: negocio, sucursal: sucursalNombre),
      const SizedBox(height: 20),
      Text('Caja', style: BarroTheme.type(28, 36, weight: FontWeight.w700)),
      const SizedBox(height: 24),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BarroTheme.border),
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFF9EDE8),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.point_of_sale_outlined,
                size: 32,
                color: BarroTheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Corte de caja',
              style: BarroTheme.type(18, 24, weight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Esta pantalla está en desarrollo. Aquí abrirás y cerrarás el corte de caja y consultarás tus ventas.',
              textAlign: TextAlign.center,
              style: BarroTheme.type(13, 19, color: BarroTheme.secondary),
            ),
          ],
        ),
      ),
    ],
  );
}
