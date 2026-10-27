import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'negocios_scaffold.dart';
import 'negocio_avatar.dart';

class NegocioCard extends StatelessWidget {
  const NegocioCard({
    required this.nombre,
    required this.iniciales,
    this.logo,
    this.onAdministrar,
    this.onEditar,
    super.key,
  });

  final String nombre;
  final String iniciales;
  final String? logo;
  final VoidCallback? onAdministrar;
  final VoidCallback? onEditar;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFF0E5E0)),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            NegocioAvatar(iniciales: iniciales, logo: logo),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: BarroTheme.type(18, 24, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Negocio registrado',
                    style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: NegociosTextButton(
                label: 'Administrar',
                onPressed: onAdministrar,
              ),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: NegociosTextButton(label: 'Editar', onPressed: onEditar),
            ),
          ],
        ),
      ],
    ),
  );
}
