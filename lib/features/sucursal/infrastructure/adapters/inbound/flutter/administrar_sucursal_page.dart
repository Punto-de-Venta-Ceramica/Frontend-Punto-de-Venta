import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import '../../../../domain/sucursal.dart';
import 'sucursal_widgets.dart';

/// Inicio de una sucursal: accesos a empleados y productos.
/// Los destinos se inyectan; sin callback se avisa que el módulo no está disponible.
class AdministrarSucursalPage extends StatelessWidget {
  const AdministrarSucursalPage({
    required this.sucursal,
    this.onEmpleados,
    this.onProductos,
    this.onInventario,
    this.onPedidos,
    super.key,
  });
  final Sucursal sucursal;
  final VoidCallback? onEmpleados;
  final VoidCallback? onProductos;
  final VoidCallback? onInventario;
  final VoidCallback? onPedidos;

  void _noDisponible(BuildContext context, String modulo) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('El módulo de $modulo aún no está disponible.')),
      );

  Widget _opcion(
    BuildContext context, {
    required IconData icono,
    required String titulo,
    String? descripcion,
    required VoidCallback? onTap,
    required String modulo,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(21),
        side: const BorderSide(color: BarroTheme.border),
      ),
      child: InkWell(
        key: ValueKey('administrar-$modulo'),
        borderRadius: BorderRadius.circular(21),
        onTap: onTap ?? () => _noDisponible(context, modulo),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: sucursalSuave,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icono, size: 36, color: BarroTheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: BarroTheme.type(20, 28, weight: FontWeight.w700),
                    ),
                    if (descripcion != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        descripcion,
                        style: BarroTheme.type(
                          14,
                          22,
                          color: BarroTheme.secondary,
                        ),
                      ),
                    ],
                    if (descripcion == null) const SizedBox(height: 40),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 18),
                child: Icon(Icons.chevron_right, color: BarroTheme.primary),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: SucursalNavegacion(
      onInventario: onInventario,
      onPedidos: onPedidos,
    ),
    body: SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SucursalCabecera(),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: sucursalSuave,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sucursal',
                        style: BarroTheme.type(
                          11,
                          16,
                          weight: FontWeight.w700,
                          color: BarroTheme.secondary,
                        ),
                      ),
                      Text(
                        sucursal.nombre,
                        style: BarroTheme.type(16, 23, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Administrar Sucursal',
                  style: BarroTheme.type(34, 43, weight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Gestiona lo que pertenece a tu sucursal.',
                  style: BarroTheme.type(14, 22, color: BarroTheme.secondary),
                ),
                const SizedBox(height: 24),
                _opcion(
                  context,
                  icono: Icons.groups_outlined,
                  titulo: 'Empleados',
                  descripcion: 'Gestiona a las personas\nde tu equipo',
                  onTap: onEmpleados,
                  modulo: 'empleados',
                ),
                _opcion(
                  context,
                  icono: Icons.receipt_long_outlined,
                  titulo: 'Pedidos',
                  descripcion: 'Registra y consulta los pedidos',
                  onTap: onPedidos,
                  modulo: 'pedidos',
                ),
                _opcion(
                  context,
                  icono: Icons.storefront_outlined,
                  titulo: 'Productos',
                  onTap: onProductos,
                  modulo: 'productos',
                ),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Volver a sucursales'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
