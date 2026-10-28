import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/core/infrastructure/widgets/barro_input.dart';
import 'package:punto_de_venta/features/login/application/ports/inbound/validate_login_use_case.dart';
import 'package:punto_de_venta/features/login/domain/login_input.dart';
import 'package:punto_de_venta/features/authentication/application/ports/inbound/authentication_use_cases.dart';
import 'package:punto_de_venta/features/authentication/domain/auth_session.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    required this.validateLogin,
    required this.signIn,
    this.initialEmail = '',
    super.key,
  });
  final ValidateLoginUseCase validateLogin;
  final SignInUseCase signIn;
  final String initialEmail;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _emailTouched = false;
  bool _passwordTouched = false;
  bool _busy = false;
  String? _error;
  String? _emailServerError;
  String? _passwordServerError;

  LoginValidation get _validation => widget.validateLogin.execute(
    LoginInput(email: _email.text, password: _password.text),
  );

  @override
  void initState() {
    super.initState();
    _email.text = widget.initialEmail;
    _emailFocus.addListener(() {
      if (!mounted) return;
      setState(() {
        if (!_emailFocus.hasFocus) _emailTouched = true;
      });
    });
    _passwordFocus.addListener(() {
      if (!mounted) return;
      setState(() {
        if (!_passwordFocus.hasFocus) _passwordTouched = true;
      });
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _recoveryNotice() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recuperar contraseña'),
        content: const Text(
          'La recuperación de contraseña estará disponible próximamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _emailTouched = true;
      _passwordTouched = true;
      _emailServerError = null;
      _passwordServerError = null;
      _error = null;
    });
    if (!_validation.isValid) {
      (_validation.emailError != null ? _emailFocus : _passwordFocus)
          .requestFocus();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await widget.signIn.execute(
        LoginInput(email: _email.text, password: _password.text),
      );
      if (!mounted) return;
      _password.clear();
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/session', (_) => false, arguments: session);
    } on AuthenticationFailure catch (error) {
      if (mounted) {
        setState(() {
          _emailServerError = error.fieldErrors['email'];
          _passwordServerError = error.fieldErrors['password'];
          _error = _emailServerError == null && _passwordServerError == null
              ? error.message
              : null;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _link(String label, VoidCallback onTap) => Semantics(
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Text(
        label,
        style: BarroTheme.type(
          14,
          20,
          weight: FontWeight.w600,
          color: BarroTheme.primary,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final validation = _validation;
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
              child: AbsorbPointer(
                absorbing: _busy,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          SvgPicture.asset(
                            'assets/icons/brand.svg',
                            width: 32,
                            height: 32,
                            excludeFromSemantics: true,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'BarroControl',
                            style: BarroTheme.type(
                              18,
                              26,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Bienvenido de nuevo',
                        style: BarroTheme.type(30, 36, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Inicia sesión para administrar tu negocio.',
                        style: BarroTheme.type(
                          14,
                          20,
                          color: BarroTheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      BarroInput(
                        fieldKey: 'login-email',
                        label: 'Correo electrónico',
                        hint: 'correo@ejemplo.com',
                        icon: 'mail',
                        controller: _email,
                        focusNode: _emailFocus,
                        onChanged: () => setState(() {
                          _emailServerError = null;
                          _error = null;
                        }),
                        errors: _emailServerError != null
                            ? [_emailServerError!]
                            : _emailTouched && validation.emailError != null
                            ? [validation.emailError!]
                            : const [],
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username],
                      ),
                      const SizedBox(height: 16),
                      BarroInput(
                        fieldKey: 'login-password',
                        label: 'Contraseña',
                        hint: 'Introduce tu contraseña',
                        icon: 'lock',
                        controller: _password,
                        focusNode: _passwordFocus,
                        onChanged: () => setState(() {
                          _passwordServerError = null;
                          _error = null;
                        }),
                        errors: _passwordServerError != null
                            ? [_passwordServerError!]
                            : _passwordTouched &&
                                  validation.passwordError != null
                            ? [validation.passwordError!]
                            : const [],
                        password: true,
                        last: true,
                        onSubmitted: _submit,
                        autofillHints: const [AutofillHints.password],
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _link(
                          '¿Olvidaste tu contraseña?',
                          _recoveryNotice,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              _error!,
                              style: BarroTheme.type(
                                14,
                                20,
                                color: BarroTheme.error,
                              ),
                            ),
                          ),
                        ),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          key: const ValueKey('login-submit'),
                          onPressed: _busy ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: BarroTheme.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
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
                                  'Iniciar sesión',
                                  style: BarroTheme.type(
                                    14,
                                    20,
                                    weight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        children: [
                          Text(
                            '¿No tienes cuenta?',
                            style: BarroTheme.type(
                              12,
                              17,
                              color: BarroTheme.secondary,
                            ),
                          ),
                          _link(
                            'Crear cuenta',
                            () => Navigator.pushNamed(context, '/register'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
