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

  void _abrirPerfil() {
    if (BarroHeader.accionPerfilGlobal != null) {
      BarroHeader.accionPerfilGlobal!(context);
    }
  }

  Widget _tarjetaSucursal(SucursalAsignada s) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFF0E5E0)),
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _elegir(s),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7E7DF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      size: 28,
                      color: BarroTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.sucursal,
                          style: BarroTheme.type(
                            18,
                            24,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.business_rounded,
                              size: 14,
                              color: BarroTheme.secondary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                s.negocio,
                                overflow: TextOverflow.ellipsis,
                                style: BarroTheme.type(
                                  13,
                                  18,
                                  color: BarroTheme.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: BarroTheme.primary,
                    size: 26,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECF7F1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Sucursal asignada',
                      style: BarroTheme.type(
                        11,
                        16,
                        weight: FontWeight.w600,
                        color: const Color(0xFF1B6A3E),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ingresar',
                        style: BarroTheme.type(
                          13,
                          18,
                          weight: FontWeight.w700,
                          color: BarroTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: BarroTheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
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
        backgroundColor: BarroTheme.background,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                children: [
                  const BarroHeader(),
                  const SizedBox(height: 28),
                  Text(
                    '¿En qué sucursal trabajas hoy?',
                    style: BarroTheme.type(26, 34, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Selecciona la sucursal para registrar pedidos, caja e inventario.',
                    style: BarroTheme.type(14, 20, color: BarroTheme.secondary),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '${_sucursales.length} ${_sucursales.length == 1 ? 'sucursal asignada' : 'sucursales asignadas'}',
                    style: BarroTheme.type(
                      13,
                      18,
                      weight: FontWeight.w600,
                      color: BarroTheme.secondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (final s in _sucursales) _tarjetaSucursal(s),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: widget.onCerrarSesion,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Cerrar sesión'),
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
