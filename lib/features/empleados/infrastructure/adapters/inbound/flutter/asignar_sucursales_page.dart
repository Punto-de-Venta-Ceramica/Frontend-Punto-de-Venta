import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/services/notificacion_servicio.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/sucursal/domain/sucursal.dart';
import 'package:punto_de_venta/features/sucursal/infrastructure/adapters/inbound/flutter/sucursal_widgets.dart';
import '../../../../application/ports/inbound/gestion_empleados_use_case.dart';
import '../../../../domain/empleado.dart';
import 'widgets/empleados_vacio.dart';

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
  final Set<int> _guardandoEmpleados = {};
  bool _huboCambios = false;

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

  Future<void> _alternarSucursal(
    Empleado empleado,
    SucursalEmpleado sucursal,
  ) async {
    final ids = empleado.sucursales.map((s) => s.id).toList();
    final quitar = ids.contains(sucursal.id);
    if (quitar) {
      ids.remove(sucursal.id);
    } else {
      ids.add(sucursal.id);
    }

    setState(() => _guardandoEmpleados.add(empleado.id));

    try {
      final actualizado = await widget.gestion.asignarSucursales(
        negocioId: widget.negocio.id,
        empleadoId: empleado.id,
        sucursalIds: ids,
      );

      if (!mounted) return;

      setState(() {
        _guardandoEmpleados.remove(empleado.id);
        final index = _empleados.indexWhere((e) => e.id == empleado.id);
        if (index != -1) {
          _empleados[index] = actualizado;
        }
      });
      NotificacionServicio.actualizacion(
        context,
        quitar
            ? '${empleado.nombreCompleto} ya no trabaja en ${sucursal.nombre}.'
            : '${empleado.nombreCompleto} ahora trabaja en ${sucursal.nombre}.',
      );
      _huboCambios = true;
    } on EmpleadoFailure catch (e) {
      if (!mounted) return;
      setState(() => _guardandoEmpleados.remove(empleado.id));
      if (e.sesionExpirada) {
        widget.onSesionExpirada();
        return;
      }
      NotificacionServicio.error(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardandoEmpleados.remove(empleado.id));
      NotificacionServicio.error(
        context,
        'No se pudo actualizar la asignación.',
      );
    }
  }

  Widget _buildItemEmpleado(Empleado emp) {
    final guardando = _guardandoEmpleados.contains(emp.id);
    final seleccionado = widget.empleadoSeleccionadoId == emp.id;
    final total = emp.sucursales.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: seleccionado ? BarroTheme.primary : BarroTheme.border,
          width: seleccionado ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1E1B19),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              EmpleadoAvatar(emp.inicial, tamano: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp.nombreCompleto,
                      style: BarroTheme.type(16, 22, weight: FontWeight.w700),
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
              const SizedBox(width: 8),
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
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: total > 0
                        ? const Color(0xFFE6F4EC)
                        : const Color(0xFFF4EDE9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    total > 0
                        ? '$total ${total == 1 ? 'sucursal' : 'sucursales'}'
                        : 'Sin asignar',
                    style: BarroTheme.type(
                      12,
                      16,
                      weight: FontWeight.w700,
                      color: total > 0
                          ? BarroTheme.success
                          : BarroTheme.secondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (_sucursales.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Este negocio aún no tiene sucursales.',
                style: BarroTheme.type(13, 18, color: BarroTheme.placeholder),
              ),
            )
          else
            for (final suc in _sucursales)
              _OpcionSucursal(
                key: ValueKey('asignar-${emp.id}-${suc.id}'),
                nombre: suc.nombre,
                seleccionada: emp.trabajaEn(suc.id),
                onTap: guardando ? null : () => _alternarSucursal(emp, suc),
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
                        onPressed: () => Navigator.pop(context, _huboCambios),
                        tooltip: 'Volver',
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Asignar sucursales',
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
                      'Un empleado puede trabajar en varias sucursales',
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
                      color: Colors.white,
                      border: Border.all(color: BarroTheme.border),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: empleadoSuave,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(
                            Icons.touch_app_outlined,
                            color: BarroTheme.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Toca una sucursal para asignarla o quitarla. El cambio se guarda al instante.',
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
                    const EmpleadosVacio(
                      mensaje:
                          'Registra empleados para poder asignarlos a tus sucursales.',
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

/// Sucursal que se puede asignar o quitar a un empleado con un toque.
class _OpcionSucursal extends StatelessWidget {
  const _OpcionSucursal({
    required this.nombre,
    required this.seleccionada,
    required this.onTap,
    super.key,
  });
  final String nombre;
  final bool seleccionada;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Semantics(
      checked: seleccionada,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: seleccionada ? empleadoSuave : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: seleccionada ? BarroTheme.primary : BarroTheme.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: seleccionada
                        ? Colors.white
                        : const Color(0xFFF7F1EE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.storefront_outlined,
                    size: 19,
                    color: seleccionada
                        ? BarroTheme.primary
                        : BarroTheme.placeholder,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BarroTheme.type(
                      14,
                      20,
                      weight: seleccionada ? FontWeight.w700 : FontWeight.w500,
                      color: seleccionada
                          ? BarroTheme.text
                          : BarroTheme.secondary,
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    seleccionada
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    key: ValueKey(seleccionada),
                    size: 24,
                    color: seleccionada
                        ? BarroTheme.primary
                        : BarroTheme.border,
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
