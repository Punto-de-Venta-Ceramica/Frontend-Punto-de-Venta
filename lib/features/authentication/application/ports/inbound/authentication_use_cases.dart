import '../../../domain/auth_session.dart';
import 'package:punto_de_venta/features/login/domain/login_input.dart';
import 'package:punto_de_venta/features/owner_registration/domain/owner_registration.dart';

abstract interface class SignInUseCase {
  Future<AuthSession> execute(LoginInput input);
}

abstract interface class RegisterOwnerUseCase {
  Future<RegisteredOwner> execute(OwnerRegistration input);
}
