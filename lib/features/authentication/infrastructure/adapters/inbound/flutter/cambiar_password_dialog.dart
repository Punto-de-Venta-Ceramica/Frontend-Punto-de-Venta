import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/authentication/application/ports/outbound/authentication_gateway.dart';
import 'package:punto_de_venta/features/authentication/domain/auth_session.dart';

/// Diálogo para cambiar la contraseña del usuario autenticado.
/// Puede ser obligatorio (primer login) o voluntario.
class CambiarPasswordDialog extends StatefulWidget {
  const CambiarPasswordDialog({
    required this.gateway,
    this.obligatorio = false,
    this.onExito,
    super.key,
  });

  final AuthenticationGateway gateway;

  /// Si es verdadero el usuario no puede cerrar el diálogo sin cambiar la contraseña.
  final bool obligatorio;

  /// Callback ejecutado cuando la contraseña se cambia con éxito.
  final VoidCallback? onExito;

  @override
  State<CambiarPasswordDialog> createState() => _CambiarPasswordDialogState();
}

class _CambiarPasswordDialogState extends State<CambiarPasswordDialog> {
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
      Navigator.of(context).pop();
      widget.onExito?.call();
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
    return PopScope(
      canPop: !widget.obligatorio,
      child: AlertDialog(
        title: Text(
          widget.obligatorio ? 'Crea tu contraseña' : 'Cambiar contraseña',
          style: BarroTheme.type(20, 28, weight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.obligatorio)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFC107)),
                  ),
                  child: const Text(
                    'Por seguridad, debes cambiar tu contraseña temporal antes de continuar.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              _campoPassword(
                controller: _actualCtrl,
                focusNode: _actualFocus,
                label: 'Contraseña actual',
                ocultar: _ocultarActual,
                onToggle: () =>
                    setState(() => _ocultarActual = !_ocultarActual),
                onSubmitted: () => _nuevaFocus.requestFocus(),
              ),
              const SizedBox(height: 12),
              _campoPassword(
                controller: _nuevaCtrl,
                focusNode: _nuevaFocus,
                label: 'Nueva contraseña',
                ocultar: _ocultarNueva,
                onToggle: () => setState(() => _ocultarNueva = !_ocultarNueva),
                onSubmitted: () => _confirmarFocus.requestFocus(),
              ),
              const SizedBox(height: 12),
              _campoPassword(
                controller: _confirmarCtrl,
                focusNode: _confirmarFocus,
                label: 'Confirmar nueva contraseña',
                ocultar: _ocultarConfirmar,
                onToggle: () =>
                    setState(() => _ocultarConfirmar = !_ocultarConfirmar),
                onSubmitted: _busy ? null : _submit,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
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
        actions: [
          if (!widget.obligatorio)
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          FilledButton(
            onPressed: _busy ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: BarroTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Widget _campoPassword({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required bool ocultar,
    required VoidCallback onToggle,
    void Function()? onSubmitted,
  }) => TextField(
    controller: controller,
    focusNode: focusNode,
    obscureText: ocultar,
    onSubmitted: onSubmitted == null ? null : (_) => onSubmitted(),
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      suffixIcon: IconButton(
        icon: Icon(ocultar ? Icons.visibility_off : Icons.visibility),
        onPressed: onToggle,
      ),
    ),
  );
}
