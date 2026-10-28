import '../../domain/owner_registration.dart';
import '../../domain/registration_validation.dart';
import '../ports/inbound/validate_owner_registration_use_case.dart';

class ValidateOwnerRegistration implements ValidateOwnerRegistrationUseCase {
  const ValidateOwnerRegistration();

  @override
  RegistrationValidation execute(OwnerRegistration input) =>
      OwnerRegistrationRules.validate(input);
}
