import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/services/notificacion_servicio.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/authentication/application/ports/outbound/authentication_gateway.dart';
import 'package:punto_de_venta/features/authentication/domain/auth_session.dart';

/// Pantalla completa para cambiar la contraseña del usuario autenticado.
class CambiarPasswordPage extends StatefulWidget {
  const CambiarPasswordPage({
    required this.gateway,
    this.obligatorio = false,
    this.onExito,
    super.key,
  });

  final AuthenticationGateway gateway;
  final bool obligatorio;
  final VoidCallback? onExito;

  static MaterialPageRoute<void> route({
    required AuthenticationGateway gateway,
    bool obligatorio = false,
    VoidCallback? onExito,
  }) => MaterialPageRoute<void>(
    builder: (_) => CambiarPasswordPage(
      gateway: gateway,
      obligatorio: obligatorio,
      onExito: onExito,
    ),
  );

  @override
  State<CambiarPasswordPage> createState() => _CambiarPasswordPageState();
}

class _CambiarPasswordPageState extends State<CambiarPasswordPage> {
  final _actualCtrl = TextEditingController();
  final _nuevaCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();
  final _actualFocus = FocusNode();
  final _nuevaFocus = FocusNode();
  final _confirmarFocus = FocusNode();

  bool _ocultarActual = true;
  bool _ocultarNueva = true;
  bool _ocultarConfirmar = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _actualCtrl.dispose();
    _nuevaCtrl.dispose();
    _confirmarCtrl.dispose();
    _actualFocus.dispose();
    _nuevaFocus.dispose();
    _confirmarFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final actual = _actualCtrl.text.trim();
    final nueva = _nuevaCtrl.text;
    final confirmar = _confirmarCtrl.text;

    if (actual.isEmpty || nueva.isEmpty || confirmar.isEmpty) {
      setState(() => _error = 'Todos los campos son obligatorios.');
      return;
    }
    if (nueva.length < 8) {
      setState(
        () => _error = 'La nueva contraseña debe tener al menos 8 caracteres.',
      );
      return;
    }
    if (nueva != confirmar) {
      setState(
        () => _error = 'La nueva contraseña y su confirmación no coinciden.',
      );
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.gateway.cambiarPassword(
        passwordActual: actual,
        nuevaPassword: nueva,
        confirmarPassword: confirmar,
      );

      if (!mounted) return;
      NotificacionServicio.actualizacion(
        context,
        'Tu contraseña se cambió correctamente.',
      );
      widget.onExito?.call();
      if (!widget.obligatorio) {
        Navigator.of(context).pop();
      }
    } on AuthenticationFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Error inesperado al cambiar contraseña.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _campo({
    required String label,
    required String hint,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool ocultar,
    required VoidCallback onToggle,
    TextInputAction action = TextInputAction.next,
    VoidCallback? onSubmitted,
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
            color: Colors.white,
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
              const Icon(
                Icons.lock_outline_rounded,
                color: BarroTheme.secondary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  obscureText: ocultar,
                  textInputAction: action,
                  onSubmitted: (_) => onSubmitted?.call(),
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
              IconButton(
                icon: Icon(
                  ocultar
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: BarroTheme.secondary,
                ),
                onPressed: onToggle,
                splashRadius: 20,
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
        leading: widget.obligatorio
            ? null
            : IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: BarroTheme.primary,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: Text(
          'Cambiar Contraseña',
          style: BarroTheme.type(20, 26, weight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: BarroTheme.border),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxStyle.shadow],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7E7DF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.lock_reset_rounded,
                                color: BarroTheme.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.obligatorio
                                        ? 'Cambio de contraseña requerido'
                                        : 'Actualizar contraseña',
                                    style: BarroTheme.type(
                                      17,
                                      22,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.obligatorio
                                        ? 'Por seguridad debes definir tu contraseña definitiva.'
                                        : 'Ingresa tu contraseña actual y la nueva que deseas usar.',
                                    style: BarroTheme.type(
                                      12,
                                      17,
                                      color: BarroTheme.secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
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
                        _campo(
                          label: 'Contraseña actual',
                          hint: 'Ingresa tu contraseña actual',
                          controller: _actualCtrl,
                          focusNode: _actualFocus,
                          ocultar: _ocultarActual,
                          onToggle: () =>
                              setState(() => _ocultarActual = !_ocultarActual),
                        ),
                        const SizedBox(height: 16),
                        _campo(
                          label: 'Nueva contraseña',
                          hint: 'Mínimo 8 caracteres',
                          controller: _nuevaCtrl,
                          focusNode: _nuevaFocus,
                          ocultar: _ocultarNueva,
                          onToggle: () =>
                              setState(() => _ocultarNueva = !_ocultarNueva),
                        ),
                        const SizedBox(height: 16),
                        _campo(
                          label: 'Confirmar nueva contraseña',
                          hint: 'Repite la contraseña',
                          controller: _confirmarCtrl,
                          focusNode: _confirmarFocus,
                          ocultar: _ocultarConfirmar,
                          action: TextInputAction.done,
                          onSubmitted: _submit,
                          onToggle: () => setState(
                            () => _ocultarConfirmar = !_ocultarConfirmar,
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: BarroTheme.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
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
                                  'Guardar contraseña',
                                  style: BarroTheme.type(
                                    15,
                                    20,
                                    weight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                        if (!widget.obligatorio) ...[
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              'Cancelar',
                              style: BarroTheme.type(
                                14,
                                18,
                                color: BarroTheme.secondary,
                              ),
                            ),
                          ),
                        ],
                      ],
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
}

class BoxStyle {
  static final shadow = BoxShadow(
    color: Colors.black.withValues(alpha: 0.04),
    blurRadius: 10,
    offset: const Offset(0, 4),
  );
}
