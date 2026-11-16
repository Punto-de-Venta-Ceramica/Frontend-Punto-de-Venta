import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/core/infrastructure/widgets/barro_header.dart';
import 'clasificacion_widgets.dart';

class ClasificacionScaffold extends StatelessWidget {
  const ClasificacionScaffold({
    required this.negocio,
    required this.children,
    this.volver,
    this.footer,
    this.onVolver,
    this.onActualizar,
    super.key,
  });
  final String negocio;
  final String? volver;
  final List<Widget> children;
  final Widget? footer;
  final VoidCallback? onVolver;
  final Future<void> Function()? onActualizar;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: RefreshIndicator(
              onRefresh: onActualizar ?? () async {},
              notificationPredicate: (_) => onActualizar != null,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const BarroHeader(),
                          const SizedBox(height: 16),
                          if (volver != null) ...[
                            Align(
                              alignment: Alignment.centerLeft,
                              child: ClasificacionEnlace(
                                texto: volver!,
                                icono: Icons.arrow_back,
                                onPressed: onVolver,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: clasificacionSuave,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'NEGOCIO',
                                  style: BarroTheme.type(
                                    10,
                                    15,
                                    weight: FontWeight.w700,
                                    color: BarroTheme.secondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  negocio,
                                  style: BarroTheme.type(
                                    14,
                                    21,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          ...children,
                          if (footer != null) ...[
                            const SizedBox(height: 32),
                            const Spacer(),
                            footer!,
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
