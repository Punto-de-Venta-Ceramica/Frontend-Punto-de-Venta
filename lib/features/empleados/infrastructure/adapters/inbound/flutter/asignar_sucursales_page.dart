import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/sucursal/domain/sucursal.dart';
import 'package:punto_de_venta/features/sucursal/infrastructure/adapters/inbound/flutter/sucursal_widgets.dart';
import '../../../../application/ports/inbound/gestion_empleados_use_case.dart';
import '../../../../domain/empleado.dart';

class AsignarSucursalesPage extends StatefulWidget {
  const AsignarSucursalesPage({
    required this.gestion,
    required this.negocio,
    required this.onSesionExpirada,
    this.empleadoSeleccionadoId,
    this.sucursalNombre,
    super.key,
  });

  final String? sucursalNombre;

  final GestionEmpleadosUseCase gestion;
  final NegocioEmpleado negocio;
  final VoidCallback onSesionExpirada;
  final int? empleadoSeleccionadoId;

  @override
  State<AsignarSucursalesPage> createState() => _AsignarSucursalesPageState();
}

class _AsignarSucursalesPageState extends State<AsignarSucursalesPage> {
  List<Empleado> _empleados = [];
  List<SucursalEmpleado> _sucursales = [];

  bool _ocupado = true;
  String? _error;
  String? _mensajeExito;
  final Set<int> _guardandoEmpleados = {};

  @override
  void initState() {
    super.initState();
    _cargarDatos();
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

  Future<void> _cargarDatos() async {
    setState(() {
      _ocupado = true;
      _error = null;
    });

    try {
      final resultados = await Future.wait([
        widget.gestion.listar(widget.negocio.id, incluirAsignacion: true),
        widget.gestion.sucursales(widget.negocio.id),
      ]);

      if (!mounted) return;
      setState(() {
        _empleados = resultados[0] as List<Empleado>;
        _sucursales = resultados[1] as List<SucursalEmpleado>;
        _ocupado = false;
      });
    } on EmpleadoFailure catch (e) {
      if (mounted) _fallo(e);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'No se pudieron cargar los empleados y sucursales.';
          _ocupado = false;
        });
      }
    }
  }

  Future<void> _cambiarAsignacion(
    Empleado empleado,
    int? nuevaSucursalId,
  ) async {
    if (empleado.sucursalId == nuevaSucursalId) return;

    setState(() {
      _guardandoEmpleados.add(empleado.id);
      _mensajeExito = null;
    });

    try {
      final actualizado = await widget.gestion.asignarSucursal(
        negocioId: widget.negocio.id,
        empleadoId: empleado.id,
        sucursalId: nuevaSucursalId,
      );

      if (!mounted) return;

      setState(() {
        _guardandoEmpleados.remove(empleado.id);
        final index = _empleados.indexWhere((e) => e.id == empleado.id);
        if (index != -1) {
          _empleados[index] = actualizado;
        }
        final destino = nuevaSucursalId == null
            ? 'desasignado de sucursal'
            : 'asignado a ${actualizado.sucursalNombre ?? 'la sucursal'}';
        _mensajeExito = '${empleado.nombreCompleto} ha sido $destino.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nuevaSucursalId == null
                ? '${empleado.nombreCompleto} quedó sin sucursal asignada.'
                : 'Sucursal actualizada para ${empleado.nombreCompleto}.',
          ),
          backgroundColor: BarroTheme.success,
          duration: const Duration(seconds: 2),
        ),
      );
    } on EmpleadoFailure catch (e) {
      if (!mounted) return;
      setState(() => _guardandoEmpleados.remove(empleado.id));
      if (e.sesionExpirada) {
        widget.onSesionExpirada();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: BarroTheme.error),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardandoEmpleados.remove(empleado.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar la asignación.'),
          backgroundColor: BarroTheme.error,
        ),
      );
    }
  }

  Widget _buildItemEmpleado(Empleado emp) {
    final guardando = _guardandoEmpleados.contains(emp.id);
    final tieneSucursal =
        emp.asignado &&
        emp.sucursalNombre != null &&
        emp.sucursalNombre!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.empleadoSeleccionadoId == emp.id
              ? BarroTheme.primary
              : BarroTheme.border,
          width: widget.empleadoSeleccionadoId == emp.id ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9EDE8),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  emp.inicial,
                  style: BarroTheme.type(
                    18,
                    24,
                    weight: FontWeight.w700,
                    color: BarroTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp.nombreCompleto,
                      style: BarroTheme.type(15, 21, weight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      emp.correoElectronico,
                      style: BarroTheme.type(
                        12,
                        17,
                        color: BarroTheme.placeholder,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (guardando)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: BarroTheme.primary,
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tieneSucursal
                        ? const Color(0xFFECF7F0)
                        : const Color(0xFFF4EDE9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tieneSucursal ? 'Asignado' : 'Sin asignar',
                    style: BarroTheme.type(
                      11,
                      15,
                      weight: FontWeight.w600,
                      color: tieneSucursal
                          ? BarroTheme.success
                          : BarroTheme.secondary,
                    ),
                  ),
                ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: BarroTheme.border),
          ),
          Row(
            children: [
              Text(
                'Sucursal asignada:',
                style: BarroTheme.type(13, 18, weight: FontWeight.w600),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF6F3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: BarroTheme.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: emp.sucursalId,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: BarroTheme.primary,
                      ),
                      hint: Text(
                        'Sin sucursal asignada',
                        style: BarroTheme.type(
                          13,
                          18,
                          color: BarroTheme.placeholder,
                        ),
                      ),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            '⚪ Sin sucursal asignada',
                            style: BarroTheme.type(
                              13,
                              18,
                              color: BarroTheme.placeholder,
                            ),
                          ),
                        ),
                        ..._sucursales.map(
                          (suc) => DropdownMenuItem<int?>(
                            value: suc.id,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.store_outlined,
                                  size: 16,
                                  color: BarroTheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    suc.nombre,
                                    style: BarroTheme.type(
                                      13,
                                      18,
                                      weight: FontWeight.w600,
                                      color: BarroTheme.text,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      onChanged: guardando
                          ? null
                          : (nuevoId) => _cambiarAsignacion(emp, nuevoId),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BarroTheme.background,
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: RefreshIndicator(
            onRefresh: _cargarDatos,
            color: BarroTheme.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: BarroTheme.text,
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        tooltip: 'Volver',
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Cambiar asignación',
                          style: BarroTheme.type(
                            26,
                            32,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 48, bottom: 16),
                    child: Text(
                      'Asigna o cambia la sucursal de tus empleados',
                      style: BarroTheme.type(
                        14,
                        20,
                        color: BarroTheme.secondary,
                      ),
                    ),
                  ),
                  NegocioSucursalPanel(
                    sucursal: widget.sucursalNombre,
                    negocio: NegocioSucursal(
                      id: widget.negocio.id,
                      nombre: widget.negocio.nombre,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7EBE6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: BarroTheme.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Selecciona la sucursal de cada empleado. El cambio se aplica en tiempo real para sus accesos.',
                            style: BarroTheme.type(
                              12,
                              18,
                              color: BarroTheme.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_mensajeExito != null) ...[
                    SucursalAviso(_mensajeExito!),
                    const SizedBox(height: 16),
                  ],
                  if (_error != null) ...[
                    SucursalAviso(_error!, error: true),
                    const SizedBox(height: 16),
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
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: BarroTheme.border),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.people_outline,
                            size: 40,
                            color: BarroTheme.placeholder,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No hay empleados registrados',
                            style: BarroTheme.type(
                              16,
                              22,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._empleados.map(_buildItemEmpleado),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
