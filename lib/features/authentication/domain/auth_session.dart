class AuthSession {
  const AuthSession({
    required this.token,
    required this.expiresAt,
    required this.refreshToken,
    required this.refreshExpiresAt,
    required this.userId,
    required this.role,
  });

  /// Token de acceso (corto). El [ApiClient] lo renueva solo, sin avisar al usuario.
  final String token;
  final DateTime expiresAt;

  /// Token de renovación (largo). Cuando vence, la sesión termina de verdad.
  final String refreshToken;
  final DateTime refreshExpiresAt;
  final int userId;
  final String role;

  /// La sesión terminó: ya no se puede renovar el acceso y hay que iniciar sesión otra vez.
  bool get isExpired => !refreshExpiresAt.isAfter(DateTime.now());
}

class RegisteredOwner {
  const RegisteredOwner({required this.id, required this.email});
  final int id;
  final String email;
}

class AuthenticationFailure implements Exception {
  const AuthenticationFailure(this.message, {this.fieldErrors = const {}});
  final String message;
  final Map<String, String> fieldErrors;
}
