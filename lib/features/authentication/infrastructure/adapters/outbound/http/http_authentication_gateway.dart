import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/features/authentication/application/ports/outbound/authentication_gateway.dart';
import 'package:punto_de_venta/features/authentication/domain/auth_session.dart';
import 'package:punto_de_venta/features/login/domain/login_input.dart';
import 'package:punto_de_venta/features/owner_registration/domain/owner_registration.dart';

class HttpAuthenticationGateway implements AuthenticationGateway {
  const HttpAuthenticationGateway(this._api);
  final ApiClient _api;

  AuthenticationFailure _failure(ApiException error) {
    const fields = {
      'nombre': 'name',
      'apellidoPaterno': 'paternalSurname',
      'apellidoMaterno': 'maternalSurname',
      'correo': 'email',
      'telefono': 'phone',
      'password': 'password',
    };
    final mapped = <String, String>{
      for (final entry in error.fieldErrors.entries)
        if (fields.containsKey(entry.key)) fields[entry.key]!: entry.value,
    };
    if (error.statusCode == 409) {
      mapped.putIfAbsent('email', () => error.message);
    }
    return AuthenticationFailure(
      error.message,
      fieldErrors: Map.unmodifiable(mapped),
    );
  }

  @override
  Future<AuthSession> login(LoginInput input) async {
    try {
      final data = await _api.postJson('api/auth/login', {
        'correo': input.email.trim(),
        'password': input.password,
      }, authenticated: false);
      final expiry = DateTime.tryParse(
        data['expiraEn'] is String ? data['expiraEn'] as String : '',
      );
      if (data['token'] is! String ||
          (data['token'] as String).isEmpty ||
          data['tipo'] != 'Bearer' ||
          expiry == null ||
          !expiry.isAfter(DateTime.now()) ||
          data['usuarioId'] is! int ||
          data['rol'] is! String) {
        throw const AuthenticationFailure(
          'El servidor no devolvió una sesión válida.',
        );
      }
      return AuthSession(
        token: data['token'] as String,
        expiresAt: expiry,
        userId: data['usuarioId'] as int,
        role: data['rol'] as String,
      );
    } on ApiException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<RegisteredOwner> register(OwnerRegistration input) async {
    try {
      final data = await _api.postJson('api/usuarios/registro', {
        'nombre': input.name.trim(),
        'apellidoPaterno': input.paternalSurname.trim(),
        'apellidoMaterno': input.maternalSurname.trim(),
        'correo': input.email.trim(),
        'telefono': input.phone.trim(),
        'password': input.password,
      }, authenticated: false);
      if (data['id'] is! int || data['correo'] is! String) {
        throw const AuthenticationFailure(
          'El servidor no confirmó el registro.',
        );
      }
      return RegisteredOwner(
        id: data['id'] as int,
        email: data['correo'] as String,
      );
    } on ApiException catch (error) {
      throw _failure(error);
    }
  }
}
