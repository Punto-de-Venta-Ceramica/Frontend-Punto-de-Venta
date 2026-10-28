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
      errors[RegistrationField.name] = [
        'El nombre es obligatorio y no puede contener solo espacios.',
      ];
    } else if (input.name.length > 100) {
      errors[RegistrationField.name] = [
        'El nombre no debe superar 100 caracteres.',
      ];
    }
    if (input.paternalSurname.length > 100) {
      errors[RegistrationField.paternalSurname] = [
        'El apellido paterno no debe superar 100 caracteres.',
      ];
    }
    if (input.maternalSurname.length > 100) {
      errors[RegistrationField.maternalSurname] = [
        'El apellido materno no debe superar 100 caracteres.',
      ];
    }
    if (input.paternalSurname.trim().isEmpty) {
      errors[RegistrationField.paternalSurname] = [
        'Ingresa tu apellido paterno.',
      ];
    }
    // The design does not mark the maternal surname as required.
    if (input.email.trim().isEmpty) {
      errors[RegistrationField.email] = [
        'El correo electrónico es obligatorio.',
      ];
    } else if (!RegExp(
      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
    ).hasMatch(input.email.trim())) {
      errors[RegistrationField.email] = [
        'El correo electrónico no tiene un formato válido.',
      ];
    } else if (input.email.length > 254) {
      errors[RegistrationField.email] = [
        'El correo electrónico no debe superar 254 caracteres.',
      ];
    }
    if (input.phone.trim().isEmpty) {
      errors[RegistrationField.phone] = ['El teléfono es obligatorio.'];
    } else if (!RegExp(r'^[0-9]{10}$').hasMatch(input.phone)) {
      errors[RegistrationField.phone] = [
        'El teléfono debe contener exactamente 10 dígitos.',
      ];
    }
    final passwordErrors = <String>[];
    if (input.password.trim().isEmpty) {
      passwordErrors.add('La contraseña es obligatoria.');
    }
    if (input.password.length > 128) {
      passwordErrors.add(
        'La contraseña debe contener entre 8 y 128 caracteres.',
      );
    }
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
