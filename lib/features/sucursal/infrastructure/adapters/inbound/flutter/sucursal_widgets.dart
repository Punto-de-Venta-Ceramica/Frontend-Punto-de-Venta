import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/core/infrastructure/widgets/barro_header.dart';
import 'package:punto_de_venta/core/infrastructure/services/notificacion_servicio.dart';
import '../../../../domain/sucursal.dart';

const sucursalSuave = Color(0xFFF7E7DF);

class SucursalCabecera extends StatelessWidget {
  const SucursalCabecera({super.key});
  @override
  Widget build(BuildContext context) => const BarroHeader();
}

class NegocioSucursalPanel extends StatelessWidget {
  const NegocioSucursalPanel({
    required this.negocio,
    this.negocios = const [],
    this.onChanged,
    this.sucursal,
    super.key,
  });
  final NegocioSucursal negocio;
  final List<NegocioSucursal> negocios;
  final ValueChanged<NegocioSucursal>? onChanged;

  /// Nombre de la sucursal que se administra: sustituye al del negocio.
  final String? sucursal;
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
          sucursal != null ? 'SUCURSAL' : 'NEGOCIO',
          style: BarroTheme.type(
            11,
            16,
            weight: FontWeight.w700,
            color: BarroTheme.secondary,
          ),
        ),
        if (sucursal != null)
          Text(
            sucursal!,
            style: BarroTheme.type(16, 23, weight: FontWeight.w700),
          )
        else if (negocios.length > 1)
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
    this.icono,
    super.key,
  });
  final String texto;
  final VoidCallback? onPressed;
  final bool busy;
  final bool destructivo;

  /// Icono opcional a la izquierda del texto.
  final IconData? icono;
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
          : icono == null
          ? Text(texto, textAlign: TextAlign.center)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icono, size: 20),
                const SizedBox(width: 8),
                Flexible(child: Text(texto, textAlign: TextAlign.center)),
              ],
            ),
    ),
  );
}

/// Tarjeta blanca con encabezado de icono, usada para agrupar campos.
class SucursalSeccion extends StatelessWidget {
  const SucursalSeccion({
    required this.icono,
    required this.titulo,
    required this.children,
    this.subtitulo,
    super.key,
  });
  final IconData icono;
  final String titulo;
  final String? subtitulo;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: BarroTheme.border),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: sucursalSuave,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icono, size: 20, color: BarroTheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: BarroTheme.type(15, 21, weight: FontWeight.w700),
                  ),
                  if (subtitulo != null)
                    Text(
                      subtitulo!,
                      style: BarroTheme.type(
                        12,
                        18,
                        color: BarroTheme.secondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    ),
  );
}

class SucursalNavegacion extends StatelessWidget {
  const SucursalNavegacion({
    this.onInventario,
    this.onPedidos,
    this.onInicio,
    this.onCaja,
    this.onDatosContables,
    this.esEmpleado = false,
    this.seleccionada = 'Inicio',
    super.key,
  });
  final VoidCallback? onInventario;
  final VoidCallback? onPedidos;
  final VoidCallback? onInicio;
  final VoidCallback? onCaja;
  final VoidCallback? onDatosContables;

  /// El empleado solo ve Pedidos, Caja e Inventario.
  final bool esEmpleado;
  final String seleccionada;

  Future<void> _abrirMas(BuildContext context) async {
    final abrirReporte = onDatosContables;
    if (abrirReporte == null) return;
    final elegido = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 480),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: ListTile(
            leading: const Icon(
              Icons.bar_chart_rounded,
              color: BarroTheme.primary,
            ),
            title: const Text('Datos contables'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(sheetContext).pop(true),
          ),
        ),
      ),
    );
    if (context.mounted && elegido == true) abrirReporte();
  }

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
              // Con solo tres botones (empleado) se reparten con espacios
              // iguales, como space-evenly, para que no queden tan separados.
              mainAxisAlignment: esEmpleado
                  ? MainAxisAlignment.spaceEvenly
                  : MainAxisAlignment.spaceBetween,
              children: [
                for (final item
                    in esEmpleado
                        ? const [
                            (Icons.receipt_long_outlined, 'Pedidos'),
                            (Icons.point_of_sale_outlined, 'Caja'),
                            (Icons.inventory_2_outlined, 'Inventario'),
                          ]
                        : const [
                            (Icons.home_outlined, 'Inicio'),
                            (Icons.receipt_long_outlined, 'Pedidos'),
                            (Icons.point_of_sale_outlined, 'Caja'),
                            (Icons.inventory_2_outlined, 'Inventario'),
                            (Icons.apps_rounded, 'Más'),
                          ])
                  IconButton(
                    tooltip: item.$2,
                    isSelected: item.$2 == seleccionada,
                    style: IconButton.styleFrom(
                      backgroundColor: item.$2 == seleccionada
                          ? const Color(0xFFA93A21)
                          : Colors.transparent,
                      foregroundColor: item.$2 == seleccionada
                          ? Colors.white
                          : BarroTheme.secondary,
                      minimumSize: const Size(46, 46),
                    ),
                    onPressed: () {
                      if (esEmpleado) {
                        switch (item.$2) {
                          case 'Pedidos':
                            onPedidos?.call();
                          case 'Caja':
                            onCaja?.call();
                          case 'Inventario':
                            onInventario?.call();
                        }
                        return;
                      }
                      if (item.$2 == 'Inicio' && onInicio != null) {
                        onInicio!();
                        return;
                      }
                      if (item.$2 == seleccionada && item.$2 != 'Pedidos') {
                        return;
                      }
                      if (item.$2 == 'Pedidos' && onPedidos != null) {
                        onPedidos!();
                        return;
                      }
                      if (item.$2 == 'Inventario' && onInventario != null) {
                        onInventario!();
                        return;
                      }
                      if (item.$2 == 'Caja' && onCaja != null) {
                        onCaja!();
                        return;
                      }
                      if (item.$2 == 'Más' && onDatosContables != null) {
                        _abrirMas(context);
                        return;
                      }
                      NotificacionServicio.info(
                        context,
                        'El módulo de ${item.$2.toLowerCase()} aún no está disponible.',
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
