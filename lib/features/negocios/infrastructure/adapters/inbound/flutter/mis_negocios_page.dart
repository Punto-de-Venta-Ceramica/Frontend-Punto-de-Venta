import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'widgets/negocio_card.dart';
import 'widgets/negocios_empty_state.dart';
import 'widgets/negocios_scaffold.dart';
import '../../../../domain/negocio.dart';

class MisNegociosPage extends StatelessWidget {
  const MisNegociosPage({
    this.negocios = const [],
    this.mensajeExito,
    this.cargando = false,
    this.error,
    this.onRegistrar,
    this.onAdministrar,
    this.onEditar,
    this.onReintentar,
    this.onVolver,
    super.key,
  });

  final List<Negocio> negocios;
  final String? mensajeExito;
  final bool cargando;
  final String? error;
  final VoidCallback? onRegistrar;
  final ValueChanged<Negocio>? onAdministrar;
  final ValueChanged<Negocio>? onEditar;
  final VoidCallback? onReintentar;
  final VoidCallback? onVolver;

  @override
  Widget build(BuildContext context) => NegociosScaffold(
    footer: onVolver == null
        ? null
        : Center(
            child: NegociosTextButton(
              label: 'Volver a mi sesión',
              onPressed: onVolver,
            ),
          ),
    children: [
      if (mensajeExito != null) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFECF7F1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 18,
                color: BarroTheme.success,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mensajeExito!,
                  style: BarroTheme.type(12, 18, color: BarroTheme.success),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
      Text(
        'Mis negocios',
        style: BarroTheme.type(30, 36, weight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Text(
        negocios.isEmpty
            ? 'Todos tus negocios, en un mismo lugar.'
            : 'Elige un negocio para administrarlo.',
        style: BarroTheme.type(14, 20, color: BarroTheme.secondary),
      ),
      if (cargando)
        const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (error != null) ...[
        const SizedBox(height: 24),
        Text(error!, style: BarroTheme.type(14, 20, color: BarroTheme.error)),
        NegociosTextButton(label: 'Reintentar', onPressed: onReintentar),
      ] else if (negocios.isEmpty)
        NegociosEmptyState(onRegistrar: onRegistrar)
      else ...[
        const SizedBox(height: 24),
        NegociosPrimaryButton(
          label: '+  Registrar negocio',
          onPressed: onRegistrar,
        ),
        const SizedBox(height: 24),
        Text(
          '${negocios.length} ${negocios.length == 1 ? 'negocio registrado' : 'negocios registrados'}',
          style: BarroTheme.type(13, 18, color: BarroTheme.secondary),
        ),
        const SizedBox(height: 24),
        for (var i = 0; i < negocios.length; i++) ...[
          if (i > 0) const SizedBox(height: 24),
          NegocioCard(
            nombre: negocios[i].nombre,
            iniciales: negocios[i].iniciales,
            logo: negocios[i].logo,
            onAdministrar: onAdministrar == null
                ? null
                : () => onAdministrar!(negocios[i]),
            onEditar: onEditar == null ? null : () => onEditar!(negocios[i]),
          ),
        ],
      ],
    ],
  );
}
