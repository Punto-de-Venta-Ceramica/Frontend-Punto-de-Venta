import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/core/infrastructure/widgets/barro_header.dart';
import 'package:punto_de_venta/features/sucursal/infrastructure/adapters/inbound/flutter/sucursal_widgets.dart';
import '../../../../domain/sucursal_asignada.dart';

/// Pantalla inicial del empleado: elige su sucursal (si trabaja en varias) y
/// muestra Pedidos, Caja (por defecto) e Inventario con una barra de 3 iconos.
class EmpleadoInicioPage extends StatefulWidget {
  const EmpleadoInicioPage({
    required this.cargarSucursales,
    required this.construirPedidos,
    required this.construirCaja,
    required this.construirInventario,
    required this.onCerrarSesion,
    this.onNotificaciones,
    this.conteoNotificaciones,
    super.key,
  });

  final Future<List<SucursalAsignada>> Function() cargarSucursales;
  final Widget Function(SucursalAsignada sucursal) construirPedidos;
  final Widget Function(SucursalAsignada sucursal) construirCaja;
  final Widget Function(SucursalAsignada sucursal) construirInventario;
  final VoidCallback onCerrarSesion;
  final VoidCallback? onNotificaciones;
  final ValueListenable<int?>? conteoNotificaciones;

  @override
  State<EmpleadoInicioPage> createState() => _EmpleadoInicioPageState();
}

class _EmpleadoInicioPageState extends State<EmpleadoInicioPage> {
  static const _pedidos = 0;
  static const _caja = 1;
  static const _inventario = 2;

  List<SucursalAsignada> _sucursales = [];
  SucursalAsignada? _actual;
  bool _cargando = true;
  String? _error;
  int _pestana = _caja;

  /// Las pantallas se crean al visitarlas por primera vez y se conservan.
  final Map<int, Widget> _pantallas = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await widget.cargarSucursales();
      if (!mounted) return;
      setState(() {
        _sucursales = lista;
        _actual = lista.length == 1 ? lista.first : null;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar tu sucursal.';
        _cargando = false;
      });
    }
  }

  void _elegir(SucursalAsignada sucursal) => setState(() {
    _actual = sucursal;
    _pestana = _caja;
    _pantallas.clear();
  });

  void _cambiarSucursal() => setState(() {
    _actual = null;
    _pantallas.clear();
  });

  void _abrirPerfil() => showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_sucursales.length > 1)
            ListTile(
              leading: const Icon(Icons.store_outlined),
              title: const Text('Cambiar de sucursal'),
              onTap: () {
                Navigator.pop(sheetContext);
                _cambiarSucursal();
              },
            ),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Cerrar sesión'),
            onTap: () {
              Navigator.pop(sheetContext);
              widget.onCerrarSesion();
            },
          ),
        ],
      ),
    ),
  );

  Widget _pantalla(int indice, SucursalAsignada sucursal) =>
      _pantallas.putIfAbsent(
        indice,
        () => switch (indice) {
          _pedidos => widget.construirPedidos(sucursal),
          _inventario => widget.construirInventario(sucursal),
          _ => widget.construirCaja(sucursal),
        },
      );

  Widget _mensaje(String texto, {VoidCallback? reintentar}) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                texto,
                textAlign: TextAlign.center,
                style: BarroTheme.type(15, 22),
              ),
              const SizedBox(height: 16),
              if (reintentar != null)
                FilledButton(
                  onPressed: reintentar,
                  child: const Text('Reintentar'),
                ),
              TextButton(
                onPressed: widget.onCerrarSesion,
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) return _mensaje(_error!, reintentar: _cargar);
    if (_sucursales.isEmpty) {
      return _mensaje(
        'No tienes una sucursal asignada. Contacta al propietario.',
      );
    }
    final actual = _actual;
    if (actual == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const BarroHeader(),
                  const SizedBox(height: 32),
                  Text(
                    '¿En qué sucursal trabajas hoy?',
                    style: BarroTheme.type(24, 32, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  for (final s in _sucursales)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.store_outlined),
                        title: Text(s.sucursal),
                        subtitle: Text(s.negocio),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _elegir(s),
                      ),
                    ),
                  TextButton(
                    onPressed: widget.onCerrarSesion,
                    child: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return BarroHeaderScope(
      onPerfil: _abrirPerfil,
      onNotificaciones: widget.onNotificaciones,
      conteoNotificaciones: widget.conteoNotificaciones,
      child: Scaffold(
        body: IndexedStack(
          index: _pestana,
          children: [
            for (final i in const [_pedidos, _caja, _inventario])
              i == _pestana || _pantallas.containsKey(i)
                  ? _pantalla(i, actual)
                  : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: SucursalNavegacion(
          esEmpleado: true,
          seleccionada: const ['Pedidos', 'Caja', 'Inventario'][_pestana],
          onPedidos: () => setState(() => _pestana = _pedidos),
          onCaja: () => setState(() => _pestana = _caja),
          onInventario: () => setState(() => _pestana = _inventario),
        ),
      ),
    );
  }
}
