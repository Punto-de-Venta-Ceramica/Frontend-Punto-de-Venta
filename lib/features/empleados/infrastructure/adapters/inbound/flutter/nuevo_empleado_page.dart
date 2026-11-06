import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/sucursal/infrastructure/adapters/inbound/flutter/sucursal_widgets.dart';
import '../../../../application/ports/inbound/gestion_empleados_use_case.dart';
import '../../../../domain/empleado.dart';
import 'widgets/credenciales_empleado_dialog.dart';

class NuevoEmpleadoPage extends StatefulWidget {
  const NuevoEmpleadoPage({
    required this.gestion,
    required this.negocio,
    required this.onSesionExpirada,
    super.key,
  });

  final GestionEmpleadosUseCase gestion;
  final NegocioEmpleado negocio;
  final VoidCallback onSesionExpirada;

  @override
  State<NuevoEmpleadoPage> createState() => _NuevoEmpleadoPageState();
}

class _NuevoEmpleadoPageState extends State<NuevoEmpleadoPage> {
  final _nombreCtrl = TextEditingController();
  final _apellidoPCtrl = TextEditingController();
  final _apellidoMCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();

  List<SucursalEmpleado> _sucursales = [];
  int? _sucursalSeleccionadaId;

  bool _ocupado = false;
  String? _errorGeneral;
  Map<String, String> _errores = {};

  @override
  void initState() {
    super.initState();
    _cargarSucursales();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoPCtrl.dispose();
    _apellidoMCtrl.dispose();
    _correoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarSucursales() async {
    try {
      final sucursales = await widget.gestion.sucursales(widget.negocio.id);
      if (mounted) {
        setState(() => _sucursales = sucursales);
      }
    } catch (_) {
      // Si falla la carga de sucursales, el formulario sigue funcionando sin asignar sucursal.
    }
  }

  Future<void> _guardar() async {
    setState(() {
      _ocupado = true;
      _errorGeneral = null;
      _errores = {};
    });

    final datos = NuevoEmpleado(
      negocioId: widget.negocio.id,
      nombre: _nombreCtrl.text,
      apellidoP: _apellidoPCtrl.text,
      apellidoM: _apellidoMCtrl.text,
      correoElectronico: _correoCtrl.text,
      sucursalId: _sucursalSeleccionadaId,
    );

    final erroresLocales = datos.validar();
    if (erroresLocales.isNotEmpty) {
      setState(() {
        _errores = erroresLocales;
        _ocupado = false;
      });
      return;
    }

    try {
      final creado = await widget.gestion.registrar(datos);
      if (!mounted) return;
      setState(() => _ocupado = false);

      // Mostrar diálogo con credenciales generadas
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CredencialesEmpleadoDialog(empleadoCreado: creado),
      );

      if (mounted) {
        Navigator.pop(context, true); // Devuelve true para recargar lista
      }
    } on EmpleadoFailure catch (e) {
      if (!mounted) return;
      if (e.sesionExpirada) {
        widget.onSesionExpirada();
        return;
      }
      setState(() {
        _errorGeneral = e.message;
        _errores = e.fieldErrors;
        _ocupado = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorGeneral = 'Ocurrió un error inesperado al registrar el empleado.';
        _ocupado = false;
      });
    }
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    String? errorText,
    bool obligatorio = false,
    TextInputType keyboardType = TextInputType.text,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: BarroTheme.type(14, 20, weight: FontWeight.w600),
      ),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: BarroTheme.type(14, 20, color: BarroTheme.text),
        cursorColor: BarroTheme.primary,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: BarroTheme.type(14, 20, color: BarroTheme.placeholder),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: BarroTheme.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: errorText != null ? BarroTheme.error : BarroTheme.border,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: errorText != null
                  ? BarroTheme.error
                  : BarroTheme.primary,
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: BarroTheme.error),
          ),
        ),
      ),
      if (errorText != null) ...[
        const SizedBox(height: 4),
        Text(
          errorText,
          style: BarroTheme.type(12, 16, color: BarroTheme.error),
        ),
      ],
      const SizedBox(height: 16),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BarroTheme.background,
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: BarroTheme.text),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Volver',
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Nuevo empleado',
                        style: BarroTheme.type(28, 34, weight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 48, bottom: 20),
                  child: Text(
                    'Registra a una persona para tu equipo',
                    style: BarroTheme.type(14, 20, color: BarroTheme.secondary),
                  ),
                ),
                if (_errorGeneral != null) ...[
                  SucursalAviso(_errorGeneral!, error: true),
                  const SizedBox(height: 20),
                ],
                _buildTextField(
                  label: 'Nombre *',
                  hint: 'Escribe el nombre',
                  controller: _nombreCtrl,
                  obligatorio: true,
                  errorText: _errores['nombre'],
                ),
                _buildTextField(
                  label: 'Apellido Paterno (Opcional)',
                  hint: 'Escribe el apellido paterno',
                  controller: _apellidoPCtrl,
                  errorText: _errores['apellidoP'],
                ),
                _buildTextField(
                  label: 'Apellido Materno (Opcional)',
                  hint: 'Escribe el apellido materno',
                  controller: _apellidoMCtrl,
                  errorText: _errores['apellidoM'],
                ),
                _buildTextField(
                  label: 'Correo Electrónico *',
                  hint: 'nombre@correo.com',
                  controller: _correoCtrl,
                  obligatorio: true,
                  keyboardType: TextInputType.emailAddress,
                  errorText: _errores['correoElectronico'],
                ),
                if (_sucursales.isNotEmpty) ...[
                  Text(
                    'Sucursal Asignada (Opcional)',
                    style: BarroTheme.type(14, 20, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: BarroTheme.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: _sucursalSeleccionadaId,
                        isExpanded: true,
                        hint: Text(
                          'Sin sucursal asignada',
                          style: BarroTheme.type(
                            14,
                            20,
                            color: BarroTheme.placeholder,
                          ),
                        ),
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text(
                              'Sin sucursal asignada',
                              style: BarroTheme.type(
                                14,
                                20,
                                color: BarroTheme.placeholder,
                              ),
                            ),
                          ),
                          ..._sucursales.map(
                            (s) => DropdownMenuItem<int?>(
                              value: s.id,
                              child: Text(
                                s.nombre,
                                style: BarroTheme.type(14, 20),
                              ),
                            ),
                          ),
                        ],
                        onChanged: (id) =>
                            setState(() => _sucursalSeleccionadaId = id),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7EBE6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: BarroTheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'La contraseña de acceso se generará automáticamente y se mostrará al completar el registro para que puedas compartirla.',
                          style: BarroTheme.type(
                            13,
                            19,
                            color: BarroTheme.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: BarroTheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _ocupado ? null : _guardar,
                    child: _ocupado
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Registrar empleado',
                            style: BarroTheme.type(
                              15,
                              22,
                              weight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
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
