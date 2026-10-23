import 'package:flutter_test/flutter_test.dart';
import 'package:punto_de_venta/features/owner_registration/application/services/validate_owner_registration.dart';
import 'package:punto_de_venta/features/owner_registration/domain/owner_registration.dart';

OwnerRegistration registration({
  String name = 'María José',
  String paternalSurname = 'Pérez',
  String email = 'maria@ejemplo.com',
  String phone = '4181234567',
  String password = 'Registro123',
  String confirmation = 'Registro123',
}) => OwnerRegistration(
  name: name,
  paternalSurname: paternalSurname,
  maternalSurname: '',
  email: email,
  phone: phone,
  password: password,
  passwordConfirmation: confirmation,
);

void main() {
  const useCase = ValidateOwnerRegistration();

  test('Acepta datos válidos y apellido materno vacío', () {
    expect(useCase.execute(registration()).isValid, isTrue);
  });

  test('Reproduce los mensajes del estado de validaciones de Figma', () {
    final result = useCase.execute(
      registration(
        name: 'Abraham',
        paternalSurname: '',
        email: 'abraham@',
        phone: '418150',
        password: '!!!!!',
        confirmation: '!!!!!!',
      ),
    );
    expect(result.errorsFor(RegistrationField.name), isEmpty);
    expect(result.errorsFor(RegistrationField.paternalSurname), [
      'Ingresa tu apellido paterno.',
    ]);
    expect(result.errorsFor(RegistrationField.email), [
      'Escribe un correo como nombre@dominio.com.',
    ]);
    expect(result.errorsFor(RegistrationField.phone), [
      'Ingresa un número de 10 dígitos.',
    ]);
    expect(result.errorsFor(RegistrationField.password), hasLength(3));
    expect(result.errorsFor(RegistrationField.passwordConfirmation), [
      'Las contraseñas no coinciden.',
    ]);
  });

  test(
    'No acepta nombres compuestos solo por espacios ni un correo sin dominio',
    () {
      final result = useCase.execute(
        registration(name: '  ', paternalSurname: ' ', email: 'a@b'),
      );
      expect(
        result.errors.keys,
        containsAll([
          RegistrationField.name,
          RegistrationField.paternalSurname,
          RegistrationField.email,
        ]),
      );
    },
  );

  test('Comprueba por separado longitud, letras y números de contraseña', () {
    expect(
      useCase
          .execute(registration(password: 'abcdefgh', confirmation: 'abcdefgh'))
          .errorsFor(RegistrationField.password),
      ['Debe contener al menos un número.'],
    );
    expect(
      useCase
          .execute(registration(password: '12345678', confirmation: '12345678'))
          .errorsFor(RegistrationField.password),
      ['Debe contener letras.'],
    );
    expect(
      useCase
          .execute(registration(password: 'abc123', confirmation: 'abc123'))
          .errorsFor(RegistrationField.password),
      ['Debe contener al menos 8 caracteres.'],
    );
  });
}
