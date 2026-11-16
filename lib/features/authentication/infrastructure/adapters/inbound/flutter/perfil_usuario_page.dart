import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/core/infrastructure/services/notificacion_servicio.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/authentication/application/ports/outbound/authentication_gateway.dart';
import 'package:punto_de_venta/features/authentication/infrastructure/adapters/inbound/flutter/cambiar_password_page.dart';

/// Pantalla completa de Perfil del Usuario acorde al estilo visual de BarroControl.
class PerfilUsuarioPage extends StatefulWidget {
  const PerfilUsuarioPage({
    required this.api,
    required this.gateway,
    this.onCerrarSesion,
    super.key,
  });

  final ApiClient api;
  final AuthenticationGateway gateway;
  final VoidCallback? onCerrarSesion;

  static MaterialPageRoute<void> route({
    required ApiClient api,
    required AuthenticationGateway gateway,
    VoidCallback? onCerrarSesion,
  }) => MaterialPageRoute<void>(
    builder: (_) => PerfilUsuarioPage(
      api: api,
      gateway: gateway,
      onCerrarSesion: onCerrarSesion,
    ),
  );

  @override
  State<PerfilUsuarioPage> createState() => _PerfilUsuarioPageState();
}

class _PerfilUsuarioPageState extends State<PerfilUsuarioPage> {
  final _nombreCtrl = TextEditingController();
  final _paternoCtrl = TextEditingController();
  final _maternoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();

  final _nombreFocus = FocusNode();
  final _paternoFocus = FocusNode();
  final _maternoFocus = FocusNode();
  final _telefonoFocus = FocusNode();

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

    _nombreFocus.dispose();
    _paternoFocus.dispose();
    _maternoFocus.dispose();
    _telefonoFocus.dispose();
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
      NotificacionServicio.actualizacion(
        context,
        'Tus datos de perfil se actualizaron con éxito.',
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
    Navigator.of(
      context,
    ).push(CambiarPasswordPage.route(gateway: widget.gateway));
  }

  Widget _campo({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required FocusNode focusNode,
    bool readOnly = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: BarroTheme.type(
            13,
            18,
            weight: FontWeight.w600,
            color: BarroTheme.text,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: readOnly ? const Color(0xFFF7F4F2) : Colors.white,
            border: Border.all(
              color: focusNode.hasFocus
                  ? BarroTheme.primary
                  : BarroTheme.border,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(
                icon,
                color: readOnly ? BarroTheme.placeholder : BarroTheme.secondary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  readOnly: readOnly,
                  keyboardType: keyboardType,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: BarroTheme.type(
                      13,
                      18,
                      color: BarroTheme.placeholder,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BarroTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: BarroTheme.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Mi Perfil',
          style: BarroTheme.type(20, 26, weight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: _cargando
                ? const Center(
                    child: CircularProgressIndicator(color: BarroTheme.primary),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Cabecera con avatar estilizado
                        Center(
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8E7DF),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: BarroTheme.primary.withValues(
                                      alpha: 0.2,
                                    ),
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: BarroTheme.primary,
                                  size: 56,
                                ),
                              ),
                              if (_rol.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: BarroTheme.primary,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.1,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    _rol,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: Text(
                            _nombreCtrl.text.isNotEmpty
                                ? '${_nombreCtrl.text} ${_paternoCtrl.text}'
                                      .trim()
                                : 'Usuario',
                            style: BarroTheme.type(
                              20,
                              26,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (_correo.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Center(
                            child: Text(
                              _correo,
                              style: BarroTheme.type(
                                13,
                                18,
                                color: BarroTheme.secondary,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),

                        if (_error != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDE8E8),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: BarroTheme.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: BarroTheme.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: BarroTheme.error,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Tarjeta de Datos Personales
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: BarroTheme.border),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.badge_outlined,
                                    color: BarroTheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Datos Personales',
                                    style: BarroTheme.type(
                                      16,
                                      22,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              _campo(
                                label: 'Correo electrónico',
                                hint: 'correo@ejemplo.com',
                                icon: Icons.email_outlined,
                                controller: TextEditingController(
                                  text: _correo,
                                ),
                                focusNode: FocusNode(),
                                readOnly: true,
                              ),
                              const SizedBox(height: 14),
                              _campo(
                                label: 'Nombre *',
                                hint: 'Tu nombre',
                                icon: Icons.person_outline,
                                controller: _nombreCtrl,
                                focusNode: _nombreFocus,
                              ),
                              const SizedBox(height: 14),
                              _campo(
                                label: 'Apellido paterno',
                                hint: 'Primer apellido',
                                icon: Icons.person_outline,
                                controller: _paternoCtrl,
                                focusNode: _paternoFocus,
                              ),
                              const SizedBox(height: 14),
                              _campo(
                                label: 'Apellido materno',
                                hint: 'Segundo apellido',
                                icon: Icons.person_outline,
                                controller: _maternoCtrl,
                                focusNode: _maternoFocus,
                              ),
                              const SizedBox(height: 14),
                              _campo(
                                label: 'Teléfono',
                                hint: '10 dígitos',
                                icon: Icons.phone_outlined,
                                controller: _telefonoCtrl,
                                focusNode: _telefonoFocus,
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 22),
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
                                label: Text(
                                  'Actualizar datos',
                                  style: BarroTheme.type(
                                    15,
                                    20,
                                    weight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Tarjeta de Seguridad y Sesión
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: BarroTheme.border),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.security_rounded,
                                    color: BarroTheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Seguridad de la cuenta',
                                    style: BarroTheme.type(
                                      16,
                                      22,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: _abrirCambiarPassword,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: BarroTheme.primary,
                                  side: const BorderSide(
                                    color: BarroTheme.primary,
                                  ),
                                  minimumSize: const Size.fromHeight(46),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.lock_reset_rounded),
                                label: Text(
                                  'Cambiar contraseña',
                                  style: BarroTheme.type(
                                    14,
                                    18,
                                    weight: FontWeight.w600,
                                    color: BarroTheme.primary,
                                  ),
                                ),
                              ),
                              if (widget.onCerrarSesion != null) ...[
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    widget.onCerrarSesion!();
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: BarroTheme.error,
                                    minimumSize: const Size.fromHeight(44),
                                  ),
                                  icon: const Icon(
                                    Icons.logout_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    'Cerrar sesión',
                                    style: BarroTheme.type(
                                      14,
                                      18,
                                      weight: FontWeight.w600,
                                      color: BarroTheme.error,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
