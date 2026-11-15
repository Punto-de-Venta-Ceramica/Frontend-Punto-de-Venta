import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/core/infrastructure/services/alerta_servicio.dart';
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
  final _nombreCtrl = TextEditingController();
  final _paternoCtrl = TextEditingController();
  final _maternoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();

  bool _cargando = true;
  bool _guardando = false;
  String? _error;
  String _correo = '';
  String _rol = '';

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _paternoCtrl.dispose();
    _maternoCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarPerfil() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final res = await widget.api.requestJson('GET', 'api/usuarios/perfil');
      if (res is Map<String, dynamic>) {
        if (!mounted) return;
        setState(() {
          _nombreCtrl.text = res['nombre']?.toString() ?? '';
          _paternoCtrl.text = res['apellidoPaterno']?.toString() ?? '';
          _maternoCtrl.text = res['apellidoMaterno']?.toString() ?? '';
          _telefonoCtrl.text = res['telefono']?.toString() ?? '';
          _correo = res['correo']?.toString() ?? '';
          _rol = res['rol']?.toString() ?? '';
          _cargando = false;
        });
      } else {
        throw const FormatException('Respuesta inválida del servidor');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar la información del perfil.';
        _cargando = false;
      });
    }
  }

  Future<void> _guardar() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'El nombre es obligatorio.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await widget.api.putJson('api/usuarios/perfil', {
        'nombre': nombre,
        'apellidoPaterno': _paternoCtrl.text.trim(),
        'apellidoMaterno': _maternoCtrl.text.trim(),
        'telefono': _telefonoCtrl.text.trim(),
      });

      if (!mounted) return;
      Navigator.of(context).pop();
      AlertaServicio.actualizacion(
        context,
        'Perfil',
        detalle: 'Tus datos de perfil se actualizaron con éxito.',
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Error al actualizar el perfil.');
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
          AlertaServicio.actualizacion(
            context,
            'Contraseña',
            detalle: 'Tu contraseña se cambió correctamente.',
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
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: BarroTheme.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                // Correo (solo lectura)
                TextField(
                  controller: TextEditingController(text: _correo),
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Color(0xFFF5F5F5),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre *',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _paternoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Apellido paterno',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _maternoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Apellido materno',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _telefonoCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
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
