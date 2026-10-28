import '../../../domain/owner_registration.dart';
import '../../../domain/registration_validation.dart';

abstract interface class ValidateOwnerRegistrationUseCase {
  RegistrationValidation execute(OwnerRegistration input);
}
