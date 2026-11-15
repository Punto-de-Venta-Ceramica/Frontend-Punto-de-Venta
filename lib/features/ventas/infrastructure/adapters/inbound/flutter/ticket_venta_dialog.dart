import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';

class TicketVentaDialog extends StatelessWidget {
  const TicketVentaDialog({super.key});

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Ticket'),
    titleTextStyle: BarroTheme.type(18, 24, weight: FontWeight.w600),
    contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
    content: SizedBox(
      width: 260,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              textStyle: BarroTheme.type(15, 20, weight: FontWeight.w600),
            ),
            child: const Text('Imprimir ticket'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: null,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              textStyle: BarroTheme.type(15, 20, weight: FontWeight.w600),
            ),
            child: const Text('Ver ticket'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
        child: const Text('Cancelar'),
      ),
    ],
  );
}
