import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_widgets.dart';
import '../../../../domain/descuento.dart';

/// Enlace de regreso a la lista de descuentos.
class DescuentoEnlaceVolver extends StatelessWidget {
  const DescuentoEnlaceVolver({required this.onPressed, super.key});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      padding: EdgeInsets.zero,
      alignment: Alignment.centerLeft,
    ),
    icon: const Icon(Icons.arrow_back, size: 18),
    label: const Text('Descuentos'),
  );
}

/// Insignia Activo / Inactivo.
class DescuentoEstado extends StatelessWidget {
  const DescuentoEstado({required this.activo, super.key});
  final bool activo;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: activo ? const Color(0xFFECF7F0) : productoSuave,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      activo ? 'Activo' : 'Inactivo',
      style: BarroTheme.type(
        11,
        16,
        weight: FontWeight.w700,
        color: activo ? BarroTheme.success : BarroTheme.secondary,
      ),
    ),
  );
}

/// Botón secundario (contorno) con el estilo de la app.
class DescuentoBotonContorno extends StatelessWidget {
  const DescuentoBotonContorno({
    required this.texto,
    required this.onPressed,
    super.key,
  });
  final String texto;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: BarroTheme.primary,
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: BarroTheme.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: BarroTheme.type(14, 20, weight: FontWeight.w700),
      ),
      child: Text(texto),
    ),
  );
}

/// Resumen del descuento (nombre, porcentaje, rango y estado).
class DescuentoResumen extends StatelessWidget {
  const DescuentoResumen({required this.descuento, super.key});
  final Descuento descuento;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: BarroTheme.border),
      borderRadius: BorderRadius.circular(21),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                descuento.nombre,
                style: BarroTheme.type(16, 23, weight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            DescuentoEstado(activo: descuento.activo),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${descuento.porcentajeTexto} % de descuento',
          style: BarroTheme.type(
            24,
            30,
            weight: FontWeight.w700,
            color: BarroTheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          descuento.rango,
          style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
        ),
      ],
    ),
  );
}

/// Confirmación previa a eliminar un descuento. Devuelve true si se confirma.
Future<bool> confirmarEliminarDescuento(
  BuildContext context, {
  required Descuento descuento,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: productoErrorSuave,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.priority_high,
                    color: BarroTheme.error,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '¿Eliminar descuento?',
                  style: BarroTheme.type(23, 30, weight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Text(
                  'Se eliminará el descuento y sus asignaciones. Los pedidos ya registrados conservan el descuento que se les aplicó.',
                  style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
                ),
                const SizedBox(height: 8),
                Text(
                  descuento.nombre,
                  style: BarroTheme.type(14, 21, weight: FontWeight.w700),
                ),
                const SizedBox(height: 26),
                ProductoBoton(
                  key: const ValueKey('descuento-confirmar-eliminar'),
                  texto: 'Eliminar descuento',
                  destructivo: true,
                  onPressed: () => Navigator.pop(context, true),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ) ??
    false;
