class LoginInput {
  const LoginInput({required this.email, required this.password});
  final String email;
  final String password;
}

class LoginValidation {
  const LoginValidation({this.emailError, this.passwordError});
  final String? emailError;
  final String? passwordError;
  bool get isValid => emailError == null && passwordError == null;
}

abstract final class LoginRules {
  static LoginValidation validate(LoginInput input) => LoginValidation(
    emailError:
        RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(input.email.trim())
        ? null
        : 'Escribe un correo como nombre@dominio.com.',
    // Login checks presence; registration password policies do not apply.
    passwordError: input.password.isEmpty ? 'Ingresa tu contraseña.' : null,
  );
}
