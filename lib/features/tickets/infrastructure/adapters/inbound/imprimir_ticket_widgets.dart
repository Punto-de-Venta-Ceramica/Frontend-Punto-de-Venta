import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';

import '../../../domain/ticket.dart';

const _suave = Color(0xFFFBEFEA);

/// Tarjeta del ticket: impresora elegida y botón de imprimir con su propio
/// estado de carga.
class TarjetaImprimirTicket extends StatelessWidget {
  const TarjetaImprimirTicket({
    required this.impresora,
    required this.imprimiendo,
    required this.onImprimir,
    required this.onCambiarImpresora,
    super.key,
  });
  final ImpresoraTicket? impresora;
  final bool imprimiendo;

  /// null = deshabilitado (otra acción en curso).
  final VoidCallback? onImprimir, onCambiarImpresora;

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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: imprimiendo ? null : onCambiarImpresora,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _suave,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  impresora == null
                      ? Icons.print_disabled_outlined
                      : Icons.print_outlined,
                  color: BarroTheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        impresora == null
                            ? 'Sin impresora elegida'
                            : impresora!.nombre,
                        style: BarroTheme.type(14, 20, weight: FontWeight.w700),
                      ),
                      Text(
                        impresora == null
                            ? 'Se te pedirá al imprimir'
                            : 'Impresora Bluetooth',
                        style: BarroTheme.type(
                          12,
                          18,
                          color: BarroTheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  impresora == null ? 'Elegir' : 'Cambiar',
                  style: BarroTheme.type(
                    13,
                    19,
                    weight: FontWeight.w700,
                    color: BarroTheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: imprimiendo ? null : onImprimir,
          style: FilledButton.styleFrom(
            backgroundColor: BarroTheme.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: BarroTheme.primary.withValues(
              alpha: imprimiendo ? 0.85 : 0.4,
            ),
            disabledForegroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: BarroTheme.type(15, 22, weight: FontWeight.w700),
          ),
          icon: imprimiendo
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.receipt_long_outlined),
          label: Text(imprimiendo ? 'Imprimiendo…' : 'Imprimir ticket'),
        ),
      ],
    ),
  );
}

/// Aviso flotante del resultado de imprimir, con icono y color según éxito.
void avisoImpresion(
  BuildContext context,
  String texto, {
  bool error = false,
  VoidCallback? onReintentar,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? BarroTheme.error : BarroTheme.success,
        duration: Duration(seconds: error ? 6 : 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                texto,
                style: BarroTheme.type(14, 20, color: Colors.white),
              ),
            ),
          ],
        ),
        action: onReintentar == null
            ? null
            : SnackBarAction(
                label: 'Reintentar',
                textColor: Colors.white,
                onPressed: onReintentar,
              ),
      ),
    );
}
