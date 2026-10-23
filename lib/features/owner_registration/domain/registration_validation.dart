import 'owner_registration.dart';

class RegistrationValidation {
  RegistrationValidation(Map<RegistrationField, List<String>> errors)
    : errors = Map.unmodifiable(
        errors.map(
          (field, messages) =>
              MapEntry(field, List<String>.unmodifiable(messages)),
        ),
      );

  final Map<RegistrationField, List<String>> errors;
  bool get isValid => errors.isEmpty;
  List<String> errorsFor(RegistrationField field) => errors[field] ?? const [];
}

/// Rules visible in the Figma registration design. No Flutter/HTTP dependency.
class OwnerRegistrationRules {
  static RegistrationValidation validate(OwnerRegistration input) {
    final errors = <RegistrationField, List<String>>{};
    if (input.name.trim().isEmpty) {
      errors[RegistrationField.name] = ['Ingresa tu nombre.'];
    }
    if (input.paternalSurname.trim().isEmpty) {
      errors[RegistrationField.paternalSurname] = [
        'Ingresa tu apellido paterno.',
      ];
    }
    // The design does not mark the maternal surname as required.
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(input.email.trim())) {
      errors[RegistrationField.email] = [
        'Escribe un correo como nombre@dominio.com.',
      ];
    }
    if (!RegExp(r'^[0-9]{10}$').hasMatch(input.phone.trim())) {
      errors[RegistrationField.phone] = ['Ingresa un número de 10 dígitos.'];
    }
    final passwordErrors = <String>[];
    if (input.password.runes.length < 8) {
      passwordErrors.add('Debe contener al menos 8 caracteres.');
    }
    if (!RegExp(r'[a-zA-ZÀ-ÖØ-öø-ÿ]').hasMatch(input.password)) {
      passwordErrors.add('Debe contener letras.');
    }
    if (!RegExp(r'[0-9]').hasMatch(input.password)) {
      passwordErrors.add('Debe contener al menos un número.');
    }
    if (passwordErrors.isNotEmpty) {
      errors[RegistrationField.password] = passwordErrors;
    }
    if (input.passwordConfirmation.isEmpty) {
      errors[RegistrationField.passwordConfirmation] = [
        'Confirma tu contraseña.',
      ];
    } else if (input.password != input.passwordConfirmation) {
      errors[RegistrationField.passwordConfirmation] = [
        'Las contraseñas no coinciden.',
      ];
    }
    return RegistrationValidation(errors);
  }
}
