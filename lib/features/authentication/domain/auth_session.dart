class AuthSession {
  const AuthSession({
    required this.token,
    required this.expiresAt,
    required this.userId,
    required this.role,
  });
  final String token;
  final DateTime expiresAt;
  final int userId;
  final String role;
  bool get isExpired => !expiresAt.isAfter(DateTime.now());
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
