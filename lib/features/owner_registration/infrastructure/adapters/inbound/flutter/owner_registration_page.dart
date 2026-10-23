import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/owner_registration/application/ports/inbound/validate_owner_registration_use_case.dart';
import 'package:punto_de_venta/features/owner_registration/domain/owner_registration.dart';
import 'package:punto_de_venta/features/owner_registration/domain/registration_validation.dart';
import 'package:punto_de_venta/core/infrastructure/widgets/barro_input.dart';
import 'package:punto_de_venta/features/authentication/application/ports/inbound/authentication_use_cases.dart';
import 'package:punto_de_venta/features/authentication/domain/auth_session.dart';

class OwnerRegistrationPage extends StatefulWidget {
  const OwnerRegistrationPage({
    required this.validateRegistration,
    required this.registerOwner,
    super.key,
  });
  final ValidateOwnerRegistrationUseCase validateRegistration;
  final RegisterOwnerUseCase registerOwner;

  @override
  State<OwnerRegistrationPage> createState() => _OwnerRegistrationPageState();
}

class _OwnerRegistrationPageState extends State<OwnerRegistrationPage> {
  final _controllers = {
    for (final field in RegistrationField.values)
      field: TextEditingController(),
  };
  final _focusNodes = {
    for (final field in RegistrationField.values) field: FocusNode(),
  };
  final _fieldKeys = {
    for (final field in RegistrationField.values) field: GlobalKey(),
  };
  final _touched = <RegistrationField>{};
  bool _busy = false;
  String? _error;
  final _serverErrors = <RegistrationField, List<String>>{};

  OwnerRegistration get _input => OwnerRegistration(
    name: _controllers[RegistrationField.name]!.text,
    paternalSurname: _controllers[RegistrationField.paternalSurname]!.text,
    maternalSurname: _controllers[RegistrationField.maternalSurname]!.text,
    email: _controllers[RegistrationField.email]!.text,
    phone: _controllers[RegistrationField.phone]!.text,
    password: _controllers[RegistrationField.password]!.text,
    passwordConfirmation:
        _controllers[RegistrationField.passwordConfirmation]!.text,
  );

  RegistrationValidation get _validation =>
      widget.validateRegistration.execute(_input);

  @override
  void initState() {
    super.initState();
    for (final field in RegistrationField.values) {
      _focusNodes[field]!.addListener(() {
        if (!mounted) return;
        setState(() {
          if (!_focusNodes[field]!.hasFocus) _touched.add(field);
        });
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focus in _focusNodes.values) {
      focus.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _touched.addAll(RegistrationField.values);
      _serverErrors.clear();
      _error = null;
    });
    final result = _validation;
    if (result.isValid) {
      setState(() {
        _busy = true;
        _error = null;
      });
      try {
        final owner = await widget.registerOwner.execute(_input);
        if (!mounted) return;
        _controllers[RegistrationField.password]!.clear();
        _controllers[RegistrationField.passwordConfirmation]!.clear();
        setState(() {
          _busy = false;
          _touched.clear();
        });
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Cuenta creada'),
            content: const Text(
              'Tu cuenta se registró correctamente. Ya puedes iniciar sesión.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Iniciar sesión'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (_) => false,
          arguments: owner.email,
        );
      } on AuthenticationFailure catch (error) {
        if (mounted) {
          setState(() {
            for (final field in RegistrationField.values) {
              final message = error.fieldErrors[field.name];
              if (message != null) {
                _serverErrors[field] = [message];
                _touched.add(field);
              }
            }
            _error = _serverErrors.isEmpty ? error.message : null;
          });
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    // Bring the first invalid field into view after inline messages have laid out.
    final firstError = RegistrationField.values.firstWhere(
      result.errors.containsKey,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final fieldContext = _fieldKeys[firstError]!.currentContext;
      if (fieldContext != null) {
        Scrollable.ensureVisible(
          fieldContext,
          duration: const Duration(milliseconds: 240),
          alignment: 0.12,
        );
      }
    });
  }

  Widget _field(
    RegistrationField field,
    String label,
    String hint,
    String icon, {
    TextInputType? keyboardType,
    Iterable<String>? autofillHints,
  }) {
    final result = _validation;
    final touched = _touched.contains(field);
    final password =
        field == RegistrationField.password ||
        field == RegistrationField.passwordConfirmation;
    return BarroInput(
      key: _fieldKeys[field],
      fieldKey: field.name,
      label: label,
      hint: hint,
      icon: icon,
      controller: _controllers[field]!,
      focusNode: _focusNodes[field]!,
      errors:
          _serverErrors[field] ??
          (touched ? result.errorsFor(field) : const []),
      validName:
          field == RegistrationField.name &&
          touched &&
          result.errorsFor(field).isEmpty,
      password: password,
      bulletedErrors: field == RegistrationField.password,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      inputFormatters: field == RegistrationField.phone
          ? [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ]
          : null,
      last: field == RegistrationField.passwordConfirmation,
      onSubmitted: _submit,
      onChanged: () => setState(() {
        _serverErrors.remove(field);
        _error = null;
      }),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
                      'Crear cuenta',
                      style: BarroTheme.type(30, 36, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Registro de propietario',
                      style: BarroTheme.type(
                        14,
                        20,
                        color: BarroTheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _field(
                      RegistrationField.name,
                      'Nombre',
                      'Escribe tu nombre',
                      'person',
                      autofillHints: [AutofillHints.givenName],
                    ),
                    const SizedBox(height: 12),
                    _field(
                      RegistrationField.paternalSurname,
                      'Apellido paterno',
                      'Escribe tu apellido paterno',
                      'person',
                      autofillHints: [AutofillHints.familyName],
                    ),
                    const SizedBox(height: 12),
                    _field(
                      RegistrationField.maternalSurname,
                      'Apellido materno',
                      'Escribe tu apellido materno',
                      'person',
                    ),
                    const SizedBox(height: 12),
                    _field(
                      RegistrationField.email,
                      'Correo electrónico',
                      'correo@ejemplo.com',
                      'mail',
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: [AutofillHints.email],
                    ),
                    const SizedBox(height: 12),
                    _field(
                      RegistrationField.phone,
                      'Teléfono',
                      'Número de teléfono',
                      'phone',
                      keyboardType: TextInputType.phone,
                      autofillHints: [AutofillHints.telephoneNumberNational],
                    ),
                    const SizedBox(height: 12),
                    _field(
                      RegistrationField.password,
                      'Contraseña',
                      'Crea una contraseña',
                      'lock',
                      autofillHints: [AutofillHints.newPassword],
                    ),
                    const SizedBox(height: 12),
                    _field(
                      RegistrationField.passwordConfirmation,
                      'Confirmar contraseña',
                      'Repite tu contraseña',
                      'lock',
                      autofillHints: [AutofillHints.newPassword],
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
                        key: const ValueKey('create-account'),
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
                                'Crear cuenta',
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
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      children: [
                        Text(
                          '¿Ya tienes cuenta?',
                          style: BarroTheme.type(
                            12,
                            17,
                            color: BarroTheme.secondary,
                          ),
                        ),
                        Semantics(
                          button: true,
                          child: InkWell(
                            onTap: () => Navigator.of(
                              context,
                            ).pushNamedAndRemoveUntil('/login', (_) => false),
                            borderRadius: BorderRadius.circular(4),
                            child: Text(
                              'Iniciar sesión',
                              style: BarroTheme.type(
                                14,
                                20,
                                weight: FontWeight.w600,
                                color: BarroTheme.primary,
                              ),
                            ),
                          ),
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
