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
    emailError: input.email.trim().isEmpty
        ? 'El correo electrónico es obligatorio.'
        : input.email.length > 254
        ? 'El correo electrónico no debe superar 254 caracteres.'
        : RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(input.email.trim())
        ? null
        : 'El correo electrónico no tiene un formato válido.',
    // Login checks presence; registration password policies do not apply.
    passwordError: input.password.trim().isEmpty
        ? 'La contraseña es obligatoria.'
        : input.password.length > 128
        ? 'La contraseña no debe superar 128 caracteres.'
        : null,
  );
}
