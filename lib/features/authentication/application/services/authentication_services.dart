import '../ports/inbound/authentication_use_cases.dart';
import '../ports/outbound/authentication_gateway.dart';
import '../../domain/auth_session.dart';
import 'package:punto_de_venta/features/login/domain/login_input.dart';
import 'package:punto_de_venta/features/owner_registration/domain/owner_registration.dart';
import 'package:punto_de_venta/features/owner_registration/domain/registration_validation.dart';

class SignIn implements SignInUseCase {
  const SignIn(this._gateway);
  final AuthenticationGateway _gateway;
  @override
  Future<AuthSession> execute(LoginInput input) {
    if (!LoginRules.validate(input).isValid) {
      throw const AuthenticationFailure('Revisa tu correo y contraseña.');
    }
    return _gateway.login(input);
  }
}

class RegisterOwner implements RegisterOwnerUseCase {
  const RegisterOwner(this._gateway);
  final AuthenticationGateway _gateway;
  @override
  Future<RegisteredOwner> execute(OwnerRegistration input) {
    if (!OwnerRegistrationRules.validate(input).isValid) {
      throw const AuthenticationFailure('Revisa los datos del formulario.');
    }
    return _gateway.register(input);
  }
}
