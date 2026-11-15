import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/authentication/application/ports/outbound/authentication_gateway.dart';
import 'package:punto_de_venta/features/authentication/domain/auth_session.dart';

/// Flujo de recuperación de contraseña en 2 pasos:
///  1. El usuario ingresa su correo y recibe un código de 6 dígitos.
///  2. Ingresa el código + nueva contraseña + confirmación.
class RecuperarPasswordPage extends StatefulWidget {
  const RecuperarPasswordPage({required this.gateway, super.key});

  final AuthenticationGateway gateway;

  @override
  State<RecuperarPasswordPage> createState() => _RecuperarPasswordPageState();
}

class _RecuperarPasswordPageState extends State<RecuperarPasswordPage> {
  // ── Paso 1 ────────────────────────────────────────────────────────
  final _correoCtrl = TextEditingController();
  final _correoFocus = FocusNode();

  // ── Paso 2 ────────────────────────────────────────────────────────
  final _codigoCtrl = TextEditingController();
  final _nuevaCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();
  final _codigoFocus = FocusNode();
  final _nuevaFocus = FocusNode();
  final _confirmarFocus = FocusNode();

  bool _ocultarNueva = true;
  bool _ocultarConfirmar = true;

  bool _paso2 = false; // false = paso 1; true = paso 2
  bool _busy = false;
  String? _error;
  String? _mensajeExito;

  @override
  void dispose() {
    _correoCtrl.dispose();
    _codigoCtrl.dispose();
    _nuevaCtrl.dispose();
    _confirmarCtrl.dispose();
    _correoFocus.dispose();
    _codigoFocus.dispose();
    _nuevaFocus.dispose();
    _confirmarFocus.dispose();
    super.dispose();
  }

  // ── Paso 1: solicitar código ──────────────────────────────────────
  Future<void> _solicitarCodigo() async {
    final correo = _correoCtrl.text.trim();
    if (correo.isEmpty || !correo.contains('@')) {
      setState(() => _error = 'Ingresa un correo electrónico válido.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _mensajeExito = null;
    });
    try {
      await widget.gateway.solicitarCodigo(correo);
      if (!mounted) return;
      setState(() {
        _paso2 = true;
        _mensajeExito =
            'Código enviado a $correo. Revisa tu bandeja de entrada (y la carpeta de spam).';
      });
    } on AuthenticationFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Error inesperado. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Paso 2: restablecer contraseña ────────────────────────────────
  Future<void> _restablecerPassword() async {
    final codigo = _codigoCtrl.text.trim();
    final nueva = _nuevaCtrl.text;
    final confirmar = _confirmarCtrl.text;

    if (codigo.length != 6 || int.tryParse(codigo) == null) {
      setState(() => _error = 'El código debe tener exactamente 6 dígitos.');
      return;
    }
    if (nueva.length < 8) {
      setState(
        () => _error = 'La nueva contraseña debe tener al menos 8 caracteres.',
      );
      return;
    }
    if (nueva != confirmar) {
      setState(() => _error = 'Las contraseñas no coinciden.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _mensajeExito = null;
    });
    try {
      await widget.gateway.restablecerPassword(
        correo: _correoCtrl.text.trim(),
        codigo: codigo,
        nuevaPassword: nueva,
        confirmarPassword: confirmar,
      );
      if (!mounted) return;
      // Regresar al login con mensaje de éxito
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contraseña restablecida. Ya puedes iniciar sesión.'),
          backgroundColor: Color(0xFF388E3C),
        ),
      );
    } on AuthenticationFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Error inesperado. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BarroTheme.background,
      appBar: AppBar(
        backgroundColor: BarroTheme.background,
        elevation: 0,
        leading: const BackButton(color: BarroTheme.primary),
        title: Text(
          'Recuperar contraseña',
          style: BarroTheme.type(18, 24, weight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Indicador de paso
                  _indicadorPasos(),
                  const SizedBox(height: 28),

                  if (!_paso2) ..._paso1() else ..._paso2Widgets(),

                  // Mensaje de éxito
                  if (_mensajeExito != null)
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF81C784)),
                      ),
                      child: Text(
                        _mensajeExito!,
                        style: const TextStyle(
                          color: Color(0xFF388E3C),
                          fontSize: 13,
                        ),
                      ),
                    ),

                  // Mensaje de error
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: BarroTheme.error,
                          fontSize: 13,
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Botón principal
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _busy
                          ? null
                          : (_paso2 ? _restablecerPassword : _solicitarCodigo),
                      style: FilledButton.styleFrom(
                        backgroundColor: BarroTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _paso2 ? 'Cambiar contraseña' : 'Enviar código',
                              style: BarroTheme.type(
                                14,
                                20,
                                weight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),

                  // Reenviar código
                  if (_paso2)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Center(
                        child: TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _paso2 = false;
                                  _error = null;
                                  _mensajeExito = null;
                                  _codigoCtrl.clear();
                                  _nuevaCtrl.clear();
                                  _confirmarCtrl.clear();
                                }),
                          child: Text(
                            '¿No recibiste el código? Volver a enviar',
                            style: BarroTheme.type(
                              13,
                              18,
                              color: BarroTheme.primary,
                              weight: FontWeight.w600,
                            ),
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

  Widget _indicadorPasos() => Row(
    children: [
      _paso(1, 'Correo', activo: true),
      Expanded(
        child: Container(
          height: 2,
          color: _paso2 ? BarroTheme.primary : BarroTheme.border,
        ),
      ),
      _paso(2, 'Código y contraseña', activo: _paso2),
    ],
  );

  Widget _paso(int numero, String label, {required bool activo}) => Column(
    children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: activo ? BarroTheme.primary : BarroTheme.border,
        ),
        child: Center(
          child: Text(
            '$numero',
            style: TextStyle(
              color: activo ? Colors.white : BarroTheme.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: BarroTheme.type(
          11,
          16,
          color: activo ? BarroTheme.primary : BarroTheme.secondary,
        ),
      ),
    ],
  );

  List<Widget> _paso1() => [
    Text(
      'Ingresa tu correo',
      style: BarroTheme.type(24, 32, weight: FontWeight.w700),
    ),
    const SizedBox(height: 8),
    Text(
      'Te enviaremos un código de 6 dígitos para restablecer tu contraseña.',
      style: BarroTheme.type(14, 20, color: BarroTheme.secondary),
    ),
    const SizedBox(height: 24),
    TextField(
      controller: _correoCtrl,
      focusNode: _correoFocus,
      keyboardType: TextInputType.emailAddress,
      onSubmitted: (_) => _busy ? null : _solicitarCodigo(),
      decoration: const InputDecoration(
        labelText: 'Correo electrónico',
        hintText: 'correo@ejemplo.com',
        prefixIcon: Icon(Icons.email_outlined),
        border: OutlineInputBorder(),
      ),
    ),
  ];

  List<Widget> _paso2Widgets() => [
    Text(
      'Revisa tu correo',
      style: BarroTheme.type(24, 32, weight: FontWeight.w700),
    ),
    const SizedBox(height: 8),
    Text(
      'Ingresa el código de 6 dígitos que enviamos a ${_correoCtrl.text.trim()} y tu nueva contraseña.',
      style: BarroTheme.type(14, 20, color: BarroTheme.secondary),
    ),
    const SizedBox(height: 24),
    TextField(
      controller: _codigoCtrl,
      focusNode: _codigoFocus,
      keyboardType: TextInputType.number,
      maxLength: 6,
      onSubmitted: (_) => _nuevaFocus.requestFocus(),
      decoration: const InputDecoration(
        labelText: 'Código de verificación',
        hintText: '000000',
        prefixIcon: Icon(Icons.lock_clock_outlined),
        border: OutlineInputBorder(),
      ),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _nuevaCtrl,
      focusNode: _nuevaFocus,
      obscureText: _ocultarNueva,
      onSubmitted: (_) => _confirmarFocus.requestFocus(),
      decoration: InputDecoration(
        labelText: 'Nueva contraseña',
        prefixIcon: const Icon(Icons.lock_outline),
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(_ocultarNueva ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _ocultarNueva = !_ocultarNueva),
        ),
      ),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _confirmarCtrl,
      focusNode: _confirmarFocus,
      obscureText: _ocultarConfirmar,
      onSubmitted: (_) => _busy ? null : _restablecerPassword(),
      decoration: InputDecoration(
        labelText: 'Confirmar contraseña',
        prefixIcon: const Icon(Icons.lock_outline),
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(
            _ocultarConfirmar ? Icons.visibility_off : Icons.visibility,
          ),
          onPressed: () =>
              setState(() => _ocultarConfirmar = !_ocultarConfirmar),
        ),
      ),
    ),
  ];
}
