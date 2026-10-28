import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'negocios_scaffold.dart';

class NegociosEmptyState extends StatelessWidget {
  const NegociosEmptyState({this.onRegistrar, super.key});
  final VoidCallback? onRegistrar;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 64),
      Center(
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: negociosSuave,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.storefront_outlined,
            size: 48,
            color: BarroTheme.primary,
          ),
        ),
      ),
      const SizedBox(height: 24),
      Text(
        'Tu primer negocio\nempieza aquí',
        textAlign: TextAlign.center,
        style: BarroTheme.type(18, 26, weight: FontWeight.w600),
      ),
      const SizedBox(height: 16),
      Text(
        'Agrega el nombre de tu negocio y, si quieres,\nun logo para identificarlo.',
        textAlign: TextAlign.center,
        style: BarroTheme.type(14, 20, color: BarroTheme.secondary),
      ),
      const SizedBox(height: 56),
      NegociosPrimaryButton(
        label: 'Registrar mi primer negocio',
        onPressed: onRegistrar,
      ),
      const SizedBox(height: 20),
      Text(
        'Después podrás agregar más negocios.',
        textAlign: TextAlign.center,
        style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
      ),
    ],
  );
}
