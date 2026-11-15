import '../../../domain/auth_session.dart';
import 'package:punto_de_venta/features/login/domain/login_input.dart';
import 'package:punto_de_venta/features/owner_registration/domain/owner_registration.dart';

abstract interface class AuthenticationGateway {
  Future<AuthSession> login(LoginInput input);
  Future<RegisteredOwner> register(OwnerRegistration input);

  /// Cambia la contraseña del usuario autenticado.
  Future<void> cambiarPassword({
    required String passwordActual,
    required String nuevaPassword,
    required String confirmarPassword,
  });

  /// Envía un código de 6 dígitos al correo para recuperar la contraseña.
  Future<void> solicitarCodigo(String correo);

  /// Verifica el código y, si es correcto, cambia la contraseña.
  Future<void> restablecerPassword({
    required String correo,
    required String codigo,
    required String nuevaPassword,
    required String confirmarPassword,
  });
}
