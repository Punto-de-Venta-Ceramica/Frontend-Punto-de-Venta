import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import '../../../../domain/sucursal.dart';

const sucursalSuave = Color(0xFFF7E7DF);

class SucursalCabecera extends StatelessWidget {
  const SucursalCabecera({super.key});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      SvgPicture.asset(
        'assets/icons/brand.svg',
        width: 36,
        height: 36,
        semanticsLabel: 'Logo de BarroControl',
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          'BarroControl',
          style: BarroTheme.type(21, 28, weight: FontWeight.w700),
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: sucursalSuave,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'Propietario',
          style: BarroTheme.type(12, 17, color: BarroTheme.primary),
        ),
      ),
    ],
  );
}

class NegocioSucursalPanel extends StatelessWidget {
  const NegocioSucursalPanel({
    required this.negocio,
    this.negocios = const [],
    this.onChanged,
    super.key,
  });
  final NegocioSucursal negocio;
  final List<NegocioSucursal> negocios;
  final ValueChanged<NegocioSucursal>? onChanged;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: sucursalSuave,
      borderRadius: BorderRadius.circular(15),
    ),
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
        if (negocios.length > 1)
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: negocio.id,
              isExpanded: true,
              isDense: true,
              style: BarroTheme.type(16, 23, weight: FontWeight.w700),
              items: negocios
                  .map(
                    (n) => DropdownMenuItem(
                      value: n.id,
                      child: Text(n.nombre, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: onChanged == null
                  ? null
                  : (id) => onChanged!(negocios.firstWhere((n) => n.id == id)),
            ),
          )
        else
          Text(
            negocio.nombre,
            style: BarroTheme.type(16, 23, weight: FontWeight.w700),
          ),
      ],
    ),
  );
}

class SucursalAviso extends StatelessWidget {
  const SucursalAviso(this.mensaje, {this.error = false, super.key});
  final String mensaje;
  final bool error;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: error ? const Color(0xFFFFF0EE) : const Color(0xFFECF7F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        mensaje,
        style: BarroTheme.type(
          13,
          19,
          color: error ? BarroTheme.error : BarroTheme.success,
        ),
      ),
    ),
  );
}

class SucursalBoton extends StatelessWidget {
  const SucursalBoton({
    required this.texto,
    required this.onPressed,
    this.busy = false,
    this.destructivo = false,
    super.key,
  });
  final String texto;
  final VoidCallback? onPressed;
  final bool busy;
  final bool destructivo;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: destructivo
            ? const Color(0xFFB91F16)
            : BarroTheme.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        textStyle: BarroTheme.type(14, 20, weight: FontWeight.w700),
      ),
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(texto, textAlign: TextAlign.center),
    ),
  );
}

class SucursalNavegacion extends StatelessWidget {
  const SucursalNavegacion({super.key});
  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    child: SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final item in const [
                  (Icons.home_outlined, 'Inicio'),
                  (Icons.receipt_long_outlined, 'Pedidos'),
                  (Icons.point_of_sale_outlined, 'Caja'),
                  (Icons.inventory_2_outlined, 'Inventario'),
                  (Icons.apps_rounded, 'Más'),
                ])
                  IconButton(
                    tooltip: item.$2,
                    isSelected: item.$2 == 'Inicio',
                    style: IconButton.styleFrom(
                      backgroundColor: item.$2 == 'Inicio'
                          ? const Color(0xFFA93A21)
                          : Colors.transparent,
                      foregroundColor: item.$2 == 'Inicio'
                          ? Colors.white
                          : BarroTheme.secondary,
                      minimumSize: const Size(46, 46),
                    ),
                    onPressed: () {
                      if (item.$2 == 'Inicio') return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'El módulo de ${item.$2.toLowerCase()} aún no está disponible.',
                          ),
                        ),
                      );
                    },
                    icon: Icon(item.$1, size: 25),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
