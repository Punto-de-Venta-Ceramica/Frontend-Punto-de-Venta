import '../../../domain/login_input.dart';

abstract interface class ValidateLoginUseCase {
  LoginValidation execute(LoginInput input);
}
