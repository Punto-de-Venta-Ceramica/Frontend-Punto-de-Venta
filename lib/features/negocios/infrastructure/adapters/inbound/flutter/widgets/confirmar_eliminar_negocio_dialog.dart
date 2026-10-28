import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'negocios_scaffold.dart';

class ConfirmarEliminarNegocioDialog extends StatelessWidget {
  const ConfirmarEliminarNegocioDialog({
    required this.nombreNegocio,
    this.onConfirmar,
    this.onCancelar,
    super.key,
  });

  final String nombreNegocio;
  final VoidCallback? onConfirmar;
  final VoidCallback? onCancelar;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 334),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0ED),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.priority_high_rounded,
                  size: 28,
                  color: BarroTheme.error,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '¿Eliminar negocio?',
              style: BarroTheme.type(22, 28, weight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Text(
              'Confirma que deseas eliminar:',
              style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
            ),
            const SizedBox(height: 8),
            Text(
              nombreNegocio,
              style: BarroTheme.type(16, 22, weight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Negocio seleccionado',
              style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
            ),
            const SizedBox(height: 24),
            NegociosPrimaryButton(
              label: 'Eliminar negocio',
              destructivo: true,
              onPressed: onConfirmar,
            ),
            const SizedBox(height: 12),
            Center(
              child: NegociosTextButton(
                label: 'Cancelar',
                onPressed: onCancelar,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
