import '../../domain/login_input.dart';
import '../ports/inbound/validate_login_use_case.dart';

class ValidateLogin implements ValidateLoginUseCase {
  const ValidateLogin();

  @override
  LoginValidation execute(LoginInput input) => LoginRules.validate(input);
}
