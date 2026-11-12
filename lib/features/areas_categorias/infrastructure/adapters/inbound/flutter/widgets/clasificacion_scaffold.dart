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
    this.mostrarNavegacion = false,
    this.onVolver,
    this.onActualizar,
    super.key,
  });
  final String negocio;
  final String? volver;
  final List<Widget> children;
  final Widget? footer;
  final bool mostrarNavegacion;
  final VoidCallback? onVolver;
  final Future<void> Function()? onActualizar;

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: mostrarNavegacion ? const _NavegacionCatalogo() : null,
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

class _NavegacionCatalogo extends StatelessWidget {
  const _NavegacionCatalogo();
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: clasificacionBorde)),
    ),
    child: SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final item in const [
                  (Icons.home_outlined, 'Inicio'),
                  (Icons.receipt_long_outlined, 'Pedidos'),
                  (Icons.point_of_sale_outlined, 'Caja'),
                  (Icons.inventory_2_outlined, 'Catálogo'),
                  (Icons.apps_rounded, 'Más'),
                ])
                  IconButton(
                    onPressed: null,
                    tooltip: item.$2,
                    style: IconButton.styleFrom(
                      disabledForegroundColor: item.$2 == 'Catálogo'
                          ? Colors.white
                          : BarroTheme.secondary,
                      disabledBackgroundColor: item.$2 == 'Catálogo'
                          ? BarroTheme.primary
                          : Colors.transparent,
                    ),
                    icon: Icon(item.$1, size: 23),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
