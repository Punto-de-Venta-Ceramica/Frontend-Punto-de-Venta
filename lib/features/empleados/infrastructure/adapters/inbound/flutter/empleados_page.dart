import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/sucursal/domain/sucursal.dart';
import 'package:punto_de_venta/features/sucursal/infrastructure/adapters/inbound/flutter/sucursal_widgets.dart';
import '../../../../application/ports/inbound/gestion_empleados_use_case.dart';
import '../../../../domain/empleado.dart';
import 'nuevo_empleado_page.dart';
import 'asignar_sucursales_page.dart';
import 'widgets/eliminar_empleado_dialog.dart';
import 'widgets/empleado_card.dart';

class EmpleadosPage extends StatefulWidget {
  const EmpleadosPage({
    required this.gestion,
    required this.negocioInicial,
    required this.onSesionExpirada,
    this.onInicio,
    this.onPedidos,
    this.onInventario,
    this.sucursalNombre,
    this.sucursalId,
    super.key,
  });

  /// Con valor, el encabezado muestra la sucursal en lugar del negocio.
  final String? sucursalNombre;

  /// Con valor, solo se listan los empleados de esa sucursal (vista de
  /// sucursal). Sin valor, se administran todos los empleados del negocio.
  final int? sucursalId;

  final GestionEmpleadosUseCase gestion;
  final NegocioEmpleado negocioInicial;
  final VoidCallback onSesionExpirada;
  final VoidCallback? onInicio;
  final VoidCallback? onPedidos;
  final VoidCallback? onInventario;

  @override
  State<EmpleadosPage> createState() => _EmpleadosPageState();
}

class _EmpleadosPageState extends State<EmpleadosPage> {
  late NegocioEmpleado _negocio;
  List<NegocioEmpleado> _negocios = [];
  List<Empleado> _empleados = [];

  bool _ocupado = true;
  String? _error;
  String? _mensajeExito;

  bool get _porSucursal => widget.sucursalId != null;

  @override
  void initState() {
    super.initState();
    _negocio = widget.negocioInicial;
    _iniciar();
  }

  void _fallo(EmpleadoFailure e) {
    if (e.sesionExpirada) {
      widget.onSesionExpirada();
      return;
    }
    setState(() {
      _error = e.message;
      _ocupado = false;
    });
  }

  Future<void> _iniciar() async {
    try {
      final negocios = await widget.gestion.negocios();
      if (!mounted) return;
      setState(() {
        _negocios = negocios;
        if (negocios.any((n) => n.id == _negocio.id)) {
          _negocio = negocios.firstWhere((n) => n.id == _negocio.id);
        } else if (negocios.isNotEmpty) {
          _negocio = negocios.first;
        }
      });
      await _cargarEmpleados();
    } on EmpleadoFailure catch (e) {
      if (mounted) _fallo(e);
    } catch (_) {
      await _cargarEmpleados();
    }
  }

  Future<void> _cargarEmpleados() async {
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final lista = await widget.gestion.listar(
        _negocio.id,
        incluirAsignacion: true,
        sucursalId: widget.sucursalId,
      );
      if (!mounted) return;
      setState(() {
        _empleados = lista;
        _ocupado = false;
      });
    } on EmpleadoFailure catch (e) {
      if (mounted) _fallo(e);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No se pudieron cargar los empleados.';
          _ocupado = false;
        });
      }
    }
  }

  Future<void> _abrirRegistro() async {
    final creado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NuevoEmpleadoPage(
          gestion: widget.gestion,
          negocio: _negocio,
          sucursalNombre: widget.sucursalNombre,
          sucursalId: widget.sucursalId,
          onSesionExpirada: widget.onSesionExpirada,
        ),
      ),
    );

    if (creado == true && mounted) {
      setState(() {
        _mensajeExito = 'Empleado registrado correctamente.';
      });
      await _cargarEmpleados();
    }
  }

  Future<void> _abrirAsignacion([int? empleadoId]) async {
    final cambio = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AsignarSucursalesPage(
          gestion: widget.gestion,
          negocio: _negocio,
          sucursalNombre: widget.sucursalNombre,
          onSesionExpirada: widget.onSesionExpirada,
          empleadoSeleccionadoId: empleadoId,
        ),
      ),
    );

    if (cambio == true && mounted) {
      await _cargarEmpleados();
    }
  }

  Future<void> _confirmarEliminar(Empleado empleado) async {
    bool eliminando = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => EliminarEmpleadoDialog(
          empleado: empleado,
          ocupado: eliminando,
          onConfirmar: () async {
            setDialogState(() => eliminando = true);
            try {
              await widget.gestion.eliminar(_negocio.id, empleado.id);
              if (!dialogCtx.mounted) return;
              Navigator.of(dialogCtx).pop();
              if (!mounted) return;
              setState(() {
                _mensajeExito = 'Empleado eliminado correctamente.';
              });
              await _cargarEmpleados();
            } on EmpleadoFailure catch (e) {
              if (!dialogCtx.mounted) return;
              setDialogState(() => eliminando = false);
              if (e.sesionExpirada) {
                Navigator.of(dialogCtx).pop();
                if (mounted) widget.onSesionExpirada();
                return;
              }
              ScaffoldMessenger.of(dialogCtx).showSnackBar(
                SnackBar(
                  content: Text(e.message),
                  backgroundColor: BarroTheme.error,
                ),
              );
            } catch (e) {
              if (!dialogCtx.mounted) return;
              setDialogState(() => eliminando = false);
              ScaffoldMessenger.of(dialogCtx).showSnackBar(
                const SnackBar(
                  content: Text('No se pudo eliminar al empleado.'),
                  backgroundColor: BarroTheme.error,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BarroTheme.background,
    bottomNavigationBar: SucursalNavegacion(
      seleccionada: 'Inicio',
      onInicio: widget.onInicio ?? () => Navigator.pop(context),
      onPedidos: widget.onPedidos,
      onInventario: widget.onInventario,
    ),
    body: SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: RefreshIndicator(
            onRefresh: _cargarEmpleados,
            color: BarroTheme.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SucursalCabecera(),
                  const SizedBox(height: 16),
                  NegocioSucursalPanel(
                    sucursal: widget.sucursalNombre,
                    negocio: NegocioSucursal(
                      id: _negocio.id,
                      nombre: _negocio.nombre,
                    ),
                    negocios: _negocios
                        .map((n) => NegocioSucursal(id: n.id, nombre: n.nombre))
                        .toList(),
                    onChanged: (n) {
                      setState(() {
                        _negocio = NegocioEmpleado(id: n.id, nombre: n.nombre);
                        _mensajeExito = null;
                      });
                      _cargarEmpleados();
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Empleados',
                    style: BarroTheme.type(32, 40, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _empleados.isEmpty
                        ? (_porSucursal
                              ? 'No hay empleados en esta sucursal'
                              : 'No hay empleados registrados en tu negocio')
                        : _porSucursal
                        ? '${_empleados.length} ${_empleados.length == 1 ? 'empleado en esta sucursal' : 'empleados en esta sucursal'}'
                        : '${_empleados.length} ${_empleados.length == 1 ? 'empleado en tu negocio' : 'empleados en tu negocio'}',
                    style: BarroTheme.type(14, 20, color: BarroTheme.secondary),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: BarroTheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _abrirRegistro,
                      child: Text(
                        '+  Registrar empleado',
                        style: BarroTheme.type(
                          15,
                          22,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (!_porSucursal) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: BarroTheme.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          foregroundColor: BarroTheme.primary,
                        ),
                        icon: const Icon(Icons.storefront_outlined, size: 20),
                        label: Text(
                          'Asignar sucursales',
                          style: BarroTheme.type(
                            14,
                            20,
                            weight: FontWeight.w600,
                            color: BarroTheme.primary,
                          ),
                        ),
                        onPressed: _empleados.isEmpty
                            ? null
                            : () => _abrirAsignacion(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (_mensajeExito != null) ...[
                    SucursalAviso(_mensajeExito!),
                    const SizedBox(height: 16),
                  ],
                  if (_error != null) ...[
                    SucursalAviso(_error!, error: true),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: _cargarEmpleados,
                        child: const Text('Reintentar'),
                      ),
                    ),
                  ],
                  if (_ocupado)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: BarroTheme.primary,
                        ),
                      ),
                    )
                  else if (_empleados.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 40,
                        horizontal: 24,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: BarroTheme.border),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF9EDE8),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.people_outline_rounded,
                              size: 32,
                              color: BarroTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Sin empleados registrados',
                            style: BarroTheme.type(
                              18,
                              24,
                              weight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Agrega a los colaboradores de tu negocio para que puedan gestionar pedidos y sucursales.',
                            textAlign: TextAlign.center,
                            style: BarroTheme.type(
                              13,
                              19,
                              color: BarroTheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._empleados.map(
                      (emp) => EmpleadoCard(
                        empleado: emp,
                        onEliminar: () => _confirmarEliminar(emp),
                        onCambiarSucursal: _porSucursal
                            ? null
                            : () => _abrirAsignacion(emp.id),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
