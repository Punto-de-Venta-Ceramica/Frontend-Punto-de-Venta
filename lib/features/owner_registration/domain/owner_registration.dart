enum RegistrationField {
  name,
  paternalSurname,
  maternalSurname,
  email,
  phone,
  password,
  passwordConfirmation,
}

/// Form input kept in memory; passwords must never be logged or persisted here.
class OwnerRegistration {
  const OwnerRegistration({
    required this.name,
    required this.paternalSurname,
    required this.maternalSurname,
    required this.email,
    required this.phone,
    required this.password,
    required this.passwordConfirmation,
  });

  final String name;
  final String paternalSurname;
  final String maternalSurname;
  final String email;
  final String phone;
  final String password;
  final String passwordConfirmation;
}
