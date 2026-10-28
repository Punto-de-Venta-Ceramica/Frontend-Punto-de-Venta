import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:punto_de_venta/features/owner_registration/domain/owner_registration.dart';
import 'package:punto_de_venta/features/owner_registration/domain/registration_validation.dart';
import 'package:punto_de_venta/features/login/domain/login_input.dart';
import 'owner_registration_page_test.dart' as registration;
import 'login_test.dart' as login;

OwnerRegistration input({
  String name = 'Ana',
  String email = 'ana@ejemplo.com',
  String phone = '4181234567',
}) => OwnerRegistration(
  name: name,
  paternalSurname: 'Pérez',
  maternalSurname: '',
  email: email,
  phone: phone,
  password: 'Registro123',
  passwordConfirmation: 'Registro123',
);

void main() {
  test(
    'Distingue campos vacíos/espacios, formato y longitud con mensajes del backend',
    () {
      for (final blank in ['', ' ', '\t\n']) {
        final errors = OwnerRegistrationRules.validate(
          input(name: blank, email: blank, phone: blank),
        );
        expect(errors.errorsFor(RegistrationField.name), [
          'El nombre es obligatorio y no puede contener solo espacios.',
        ]);
        expect(errors.errorsFor(RegistrationField.email), [
          'El correo electrónico es obligatorio.',
        ]);
        expect(errors.errorsFor(RegistrationField.phone), [
          'El teléfono es obligatorio.',
        ]);
      }
      for (final phone in [
        '123456789',
        '12345678901',
        'abcdefghij',
        '+521234567890',
        ' 1234567890',
      ]) {
        expect(
          OwnerRegistrationRules.validate(
            input(phone: phone),
          ).errorsFor(RegistrationField.phone),
          ['El teléfono debe contener exactamente 10 dígitos.'],
        );
      }
      expect(
        OwnerRegistrationRules.validate(
          input(name: 'A' * 101),
        ).errorsFor(RegistrationField.name),
        ['El nombre no debe superar 100 caracteres.'],
      );
      expect(
        LoginRules.validate(
          const LoginInput(email: ' ', password: ' '),
        ).passwordError,
        'La contraseña es obligatoria.',
      );
    },
  );

  for (final status in [400, 409]) {
    testWidgets(
      'HTTP $status coloca el mensaje de la API debajo del correo y se limpia al corregir',
      (tester) async {
        final message = status == 409
            ? 'El correo electrónico ya está registrado.'
            : 'El correo electrónico no tiene un formato válido.';
        await registration.openRegistration(
          tester,
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'errores': {'correo': message},
              }),
              status,
                headers: {'content-type': 'application/problem+json; charset=utf-8'},
            ),
          ),
        );
        for (final entry in {
          'name': 'Ana',
          'paternalSurname': 'Pérez',
          'email': 'ana@ejemplo.com',
          'phone': '4181234567',
          'password': 'Registro123',
          'passwordConfirmation': 'Registro123',
        }.entries) {
          await registration.fill(tester, entry.key, entry.value);
        }
        await registration.submit(tester);
        expect(find.text(message), findsOneWidget);
        expect(find.text('Cuenta creada'), findsNothing);
        final emailField = find.byKey(const ValueKey('email'));
        expect(
          tester.getTopLeft(find.text(message)).dy,
          greaterThan(tester.getTopLeft(emailField).dy),
        );
        await registration.fill(tester, 'email', 'otro@ejemplo.com');
        expect(find.text(message), findsNothing);
      },
    );
  }

  testWidgets('Login muestra errores del servidor por campo', (tester) async {
    await login.openLogin(
      tester,
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'errores': {
              'correo': 'El correo electrónico no tiene un formato válido.',
            },
          }),
                400,
                headers: {'content-type': 'application/problem+json; charset=utf-8'},
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-email')),
      'ana@ejemplo.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password')),
      'Registro123',
    );
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();
    expect(
      find.text('El correo electrónico no tiene un formato válido.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-email')),
      'otra@ejemplo.com',
    );
    await tester.pump();
    expect(
      find.text('El correo electrónico no tiene un formato válido.'),
      findsNothing,
    );
  });
}
