import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/core/infrastructure/services/notificacion_servicio.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/authentication/application/ports/outbound/authentication_gateway.dart';
import 'package:punto_de_venta/features/authentication/infrastructure/adapters/inbound/flutter/cambiar_password_dialog.dart';

/// Diálogo modal que muestra y permite editar la información del perfil del usuario,
/// además de acceder al cambio de contraseña y cierre de sesión.
class PerfilUsuarioDialog extends StatefulWidget {
  const PerfilUsuarioDialog({
    required this.api,
    required this.gateway,
    this.onCerrarSesion,
    super.key,
  });

  final ApiClient api;
  final AuthenticationGateway gateway;
  final VoidCallback? onCerrarSesion;

  static Future<void> mostrar(
    BuildContext context, {
    required ApiClient api,
    required AuthenticationGateway gateway,
    VoidCallback? onCerrarSesion,
  }) => showDialog<void>(
    context: context,
    builder: (_) => PerfilUsuarioDialog(
      api: api,
      gateway: gateway,
      onCerrarSesion: onCerrarSesion,
    ),
  );

  @override
  State<PerfilUsuarioDialog> createState() => _PerfilUsuarioDialogState();
}

class _PerfilUsuarioDialogState extends State<PerfilUsuarioDialog> {
  final _correoCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _paternoCtrl = TextEditingController();
  final _maternoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();

  bool _cargando = true;
  bool _guardando = false;
  String? _generalError;
  final Map<String, String> _fieldErrors = {};
  String _rol = '';

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  @override
  void dispose() {
    _correoCtrl.dispose();
    _nombreCtrl.dispose();
    _paternoCtrl.dispose();
    _maternoCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarPerfil() async {
    setState(() {
      _cargando = true;
      _generalError = null;
    });

    try {
      final res = await widget.api.requestJson('GET', 'api/usuarios/perfil');
      if (res is Map<String, dynamic>) {
        if (!mounted) return;
        setState(() {
          _correoCtrl.text = res['correo']?.toString() ?? '';
          _nombreCtrl.text = res['nombre']?.toString() ?? '';
          _paternoCtrl.text = res['apellidoPaterno']?.toString() ?? '';
          _maternoCtrl.text = res['apellidoMaterno']?.toString() ?? '';
          _telefonoCtrl.text = res['telefono']?.toString() ?? '';
          _rol = res['rol']?.toString() ?? '';
          _cargando = false;
        });
      } else {
        throw const FormatException('Respuesta inválida del servidor');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generalError = 'No se pudo cargar la información del perfil.';
        _cargando = false;
      });
    }
  }

  Map<String, String> _validar() {
    final errores = <String, String>{};
    final correo = _correoCtrl.text;
    final nombre = _nombreCtrl.text;
    final paterno = _paternoCtrl.text;
    final materno = _maternoCtrl.text;
    final telefono = _telefonoCtrl.text;

    // 1. Correo electrónico
    if (correo.trim().isEmpty) {
      errores['correo'] = 'El correo electrónico es obligatorio y no puede contener solo espacios.';
    } else if (correo.contains(' ')) {
      errores['correo'] = 'El correo electrónico no debe contener espacios en blanco.';
    } else if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(correo.trim())) {
      errores['correo'] = 'El correo electrónico no tiene un formato válido.';
    } else if (correo.trim().length > 254) {
      errores['correo'] = 'El correo electrónico no debe superar 254 caracteres.';
    }

    // 2. Nombre
    if (nombre.trim().isEmpty) {
      errores['nombre'] = 'El nombre es obligatorio y no puede contener solo espacios.';
    } else if (RegExp(r'[0-9]').hasMatch(nombre)) {
      errores['nombre'] = 'El nombre no debe contener números.';
    } else if (nombre.trim().length > 100) {
      errores['nombre'] = 'El nombre no debe superar 100 caracteres.';
    } else if (nombre != nombre.trim()) {
      errores['nombre'] = 'El nombre no debe tener espacios al inicio ni al final.';
    }

    // 3. Apellido paterno
    if (paterno.trim().isEmpty) {
      errores['apellidoPaterno'] = 'El apellido paterno es obligatorio y no puede contener solo espacios.';
    } else if (RegExp(r'[0-9]').hasMatch(paterno)) {
      errores['apellidoPaterno'] = 'El apellido paterno no debe contener números.';
    } else if (paterno.trim().length > 100) {
      errores['apellidoPaterno'] = 'El apellido paterno no debe superar 100 caracteres.';
    } else if (paterno != paterno.trim()) {
      errores['apellidoPaterno'] = 'El apellido paterno no debe tener espacios al inicio ni al final.';
    }

    // 4. Apellido materno (opcional)
    if (materno.isNotEmpty) {
      if (materno.trim().isEmpty) {
        errores['apellidoMaterno'] = 'El apellido materno no puede contener solo espacios.';
      } else if (RegExp(r'[0-9]').hasMatch(materno)) {
        errores['apellidoMaterno'] = 'El apellido materno no debe contener números.';
      } else if (materno.trim().length > 100) {
        errores['apellidoMaterno'] = 'El apellido materno no debe superar 100 caracteres.';
      } else if (materno != materno.trim()) {
        errores['apellidoMaterno'] = 'El apellido materno no debe tener espacios al inicio ni al final.';
      }
    }

    // 5. Teléfono
    if (telefono.trim().isEmpty) {
      errores['telefono'] = 'El teléfono es obligatorio y no puede contener solo espacios.';
    } else if (telefono.contains(' ')) {
      errores['telefono'] = 'El teléfono no debe contener espacios en blanco.';
    } else if (!RegExp(r'^[0-9]{10}$').hasMatch(telefono.trim())) {
      errores['telefono'] = 'El teléfono debe contener exactamente 10 dígitos numéricos.';
    }

    return errores;
  }

  Future<void> _guardar() async {
    final errores = _validar();
    if (errores.isNotEmpty) {
      setState(() {
        _fieldErrors
          ..clear()
          ..addAll(errores);
        _generalError = null;
      });
      return;
    }

    setState(() {
      _guardando = true;
      _fieldErrors.clear();
      _generalError = null;
    });

    try {
      await widget.api.putJson('api/usuarios/perfil', {
        'nombre': _nombreCtrl.text.trim(),
        'apellidoPaterno': _paternoCtrl.text.trim(),
        'apellidoMaterno': _maternoCtrl.text.trim().isEmpty
            ? null
            : _maternoCtrl.text.trim(),
        'telefono': _telefonoCtrl.text.trim(),
        'correo': _correoCtrl.text.trim(),
      });

      if (!mounted) return;
      Navigator.of(context).pop();
      NotificacionServicio.actualizacion(
        context,
        'Tus datos de perfil se actualizaron con éxito.',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.fieldErrors.isNotEmpty) {
          _fieldErrors.addAll(e.fieldErrors);
        } else {
          final msg = e.message;
          final msgLower = msg.toLowerCase();
          if (msgLower.contains('correo') || msgLower.contains('email')) {
            _fieldErrors['correo'] = msg;
          } else if (msgLower.contains('nombre')) {
            _fieldErrors['nombre'] = msg;
          } else if (msgLower.contains('apellido')) {
            _fieldErrors['apellidoPaterno'] = msg;
          } else if (msgLower.contains('teléfono') || msgLower.contains('telefono')) {
            _fieldErrors['telefono'] = msg;
          } else {
            _generalError = msg;
          }
        }
      });
    } catch (_) {
      if (mounted) setState(() => _generalError = 'Error al actualizar el perfil.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _abrirCambiarPassword() {
    showDialog<void>(
      context: context,
      builder: (_) => CambiarPasswordDialog(
        gateway: widget.gateway,
        obligatorio: false,
        onExito: () {
          NotificacionServicio.actualizacion(
            context,
            'Tu contraseña se cambió correctamente.',
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF7E7DF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: BarroTheme.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mi perfil',
                          style: BarroTheme.type(
                            20,
                            26,
                            weight: FontWeight.w700,
                          ),
                        ),
                        if (_rol.isNotEmpty)
                          Text(
                            'Rol: $_rol',
                            style: BarroTheme.type(
                              12,
                              16,
                              weight: FontWeight.w600,
                              color: BarroTheme.secondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_cargando)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: BarroTheme.primary),
                  ),
                )
              else ...[
                TextField(
                  controller: _correoCtrl,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) {
                    if (_fieldErrors.containsKey('correo')) {
                      setState(() => _fieldErrors.remove('correo'));
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Correo electrónico *',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: const OutlineInputBorder(),
                    errorText: _fieldErrors['correo'],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _nombreCtrl,
                  onChanged: (_) {
                    if (_fieldErrors.containsKey('nombre')) {
                      setState(() => _fieldErrors.remove('nombre'));
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Nombre *',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: const OutlineInputBorder(),
                    errorText: _fieldErrors['nombre'],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _paternoCtrl,
                  onChanged: (_) {
                    if (_fieldErrors.containsKey('apellidoPaterno')) {
                      setState(() => _fieldErrors.remove('apellidoPaterno'));
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Apellido paterno *',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: const OutlineInputBorder(),
                    errorText: _fieldErrors['apellidoPaterno'],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _maternoCtrl,
                  onChanged: (_) {
                    if (_fieldErrors.containsKey('apellidoMaterno')) {
                      setState(() => _fieldErrors.remove('apellidoMaterno'));
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Apellido materno',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: const OutlineInputBorder(),
                    errorText: _fieldErrors['apellidoMaterno'],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _telefonoCtrl,
                  keyboardType: TextInputType.phone,
                  onChanged: (_) {
                    if (_fieldErrors.containsKey('telefono')) {
                      setState(() => _fieldErrors.remove('telefono'));
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Teléfono *',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: const OutlineInputBorder(),
                    errorText: _fieldErrors['telefono'],
                  ),
                ),
                if (_generalError != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _generalError!,
                    style: BarroTheme.type(13, 18, color: BarroTheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _guardando ? null : _guardar,
                  style: FilledButton.styleFrom(
                    backgroundColor: BarroTheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _guardando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Actualizar datos'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _abrirCambiarPassword,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.lock_reset_rounded),
                  label: const Text('Cambiar contraseña'),
                ),
                if (widget.onCerrarSesion != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onCerrarSesion!();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: BarroTheme.error,
                      minimumSize: const Size.fromHeight(42),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Cerrar sesión'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
