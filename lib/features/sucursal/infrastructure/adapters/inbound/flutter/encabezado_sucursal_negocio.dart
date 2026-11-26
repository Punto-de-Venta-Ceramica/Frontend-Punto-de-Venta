import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/core/infrastructure/widgets/barro_header.dart';
import 'package:punto_de_venta/features/reportes/infrastructure/adapters/inbound/flutter/reporte_widgets.dart';

import '../../../../domain/sucursal.dart';

/// Pantalla de una sección del negocio (Datos contables, Pedidos): cabecera
/// común, enlace "Volver" y el contenido centrado.
class PantallaNegocio extends StatelessWidget {
  const PantallaNegocio({required this.children, this.onRefresh, super.key});
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    Widget lista = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        const BarroHeader(),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Volver'),
          ),
        ),
        ...children,
      ],
    );
    if (onRefresh != null) {
      lista = RefreshIndicator(onRefresh: onRefresh!, child: lista);
    }
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: lista,
          ),
        ),
      ),
    );
  }
}

/// Título de la sección y tarjeta del negocio con el selector de sucursal.
class EncabezadoSucursalNegocio extends StatelessWidget {
  const EncabezadoSucursalNegocio({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.negocio,
    required this.sucursales,
    required this.sucursalId,
    required this.cargando,
    required this.onElegir,
    this.error,
    this.onReintentar,
    this.debajo,
    super.key,
  });

  final IconData icono;
  final String titulo, descripcion, negocio;
  final List<Sucursal> sucursales;
  final int? sucursalId;
  final bool cargando;

  /// null = selector deshabilitado (p. ej. mientras se exporta).
  final ValueChanged<int?>? onElegir;
  final String? error;
  final VoidCallback? onReintentar;

  /// Controles extra dentro de la tarjeta, bajo el selector.
  final Widget? debajo;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: BarroTheme.primary,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: BarroTheme.primary.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icono, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: BarroTheme.type(26, 33, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  descripcion,
                  style: BarroTheme.type(14, 21, color: BarroTheme.secondary),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      PanelReporte(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const IconoReporte(Icons.storefront_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NEGOCIO',
                        style: BarroTheme.type(
                          11,
                          16,
                          weight: FontWeight.w700,
                          color: BarroTheme.secondary,
                        ),
                      ),
                      Text(
                        negocio,
                        style: BarroTheme.type(15, 21, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _selector(),
            if (debajo != null) ...[const SizedBox(height: 14), debajo!],
          ],
        ),
      ),
    ],
  );

  Widget _selector() {
    if (cargando) {
      return const LinearProgressIndicator(
        semanticsLabel: 'Cargando sucursales',
      );
    }
    if (error case final String mensaje) {
      return ErrorReporte(error: mensaje, onReintentar: onReintentar ?? () {});
    }
    if (sucursales.isEmpty) {
      return Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: BarroTheme.secondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Este negocio todavía no tiene sucursales registradas.',
              style: BarroTheme.type(13, 19, color: BarroTheme.secondary),
            ),
          ),
        ],
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: BarroTheme.background,
        border: Border.all(
          color: sucursalId == null ? BarroTheme.primary : BarroTheme.border,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: sucursalId,
            isExpanded: true,
            borderRadius: BorderRadius.circular(14),
            icon: const Icon(
              Icons.expand_more_rounded,
              color: BarroTheme.primary,
            ),
            selectedItemBuilder: (context) => [
              for (final sucursal in sucursales)
                Row(
                  children: [
                    const Icon(
                      Icons.store_mall_directory_outlined,
                      size: 20,
                      color: BarroTheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        sucursal.nombre,
                        overflow: TextOverflow.ellipsis,
                        style: BarroTheme.type(15, 21, weight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
            ],
            hint: const Row(
              children: [
                Icon(
                  Icons.store_mall_directory_outlined,
                  size: 20,
                  color: BarroTheme.placeholder,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Selecciona una sucursal',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            items: [
              for (final sucursal in sucursales)
                DropdownMenuItem(
                  value: sucursal.id,
                  child: Text(sucursal.nombre, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onElegir,
          ),
        ),
      ),
    );
  }
}
