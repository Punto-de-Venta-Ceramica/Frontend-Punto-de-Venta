import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.fieldErrors = const {},
  });
  final String message;
  final int? statusCode;
  final Map<String, String> fieldErrors;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({required String baseUrl, http.Client? client})
    : _baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
      _client = client ?? http.Client() {
    if (!_baseUri.hasAuthority ||
        !const ['http', 'https'].contains(_baseUri.scheme) ||
        _baseUri.hasQuery ||
        _baseUri.hasFragment) {
      throw const ApiException(
        'API_BASE_URL debe ser una URL HTTP o HTTPS sin query ni fragmento.',
      );
    }
  }

  final Uri _baseUri;
  final http.Client _client;
  static const timeout = Duration(seconds: 10);
  String? bearerToken;

  // --- Sesión renovable -----------------------------------------------------
  // El token de acceso es corto; con el de renovación se obtiene uno nuevo en
  // segundo plano. Solo si la renovación falla de forma definitiva (token de
  // renovación vencido o rechazado) se avisa por [onSessionExpired].
  static const _margenRenovacion = Duration(seconds: 30);
  DateTime? _accessExpiresAt;
  String? _refreshToken;
  DateTime? _refreshExpiresAt;
  Future<bool>? _renovando;

  /// Se llama una sola vez cuando la sesión terminó y hay que volver al login.
  void Function()? onSessionExpired;

  void iniciarSesion({
    required String token,
    required DateTime expiresAt,
    required String refreshToken,
    required DateTime refreshExpiresAt,
  }) {
    bearerToken = token;
    _accessExpiresAt = expiresAt;
    _refreshToken = refreshToken;
    _refreshExpiresAt = refreshExpiresAt;
  }

  void cerrarSesion() {
    bearerToken = null;
    _accessExpiresAt = null;
    _refreshToken = null;
    _refreshExpiresAt = null;
  }

  bool get _puedeRenovar => _refreshToken != null;

  bool get _accesoPorVencer =>
      _accessExpiresAt != null &&
      !_accessExpiresAt!.isAfter(DateTime.now().add(_margenRenovacion));

  void _terminarSesion() {
    final avisar = onSessionExpired;
    cerrarSesion();
    avisar?.call();
  }

  /// Renueva el token de acceso. Varias peticiones simultáneas comparten una sola
  /// renovación. Devuelve `false` si la sesión terminó (ya se avisó al usuario);
  /// lanza [ApiException] si falla por red o servidor sin que la sesión termine.
  Future<bool> _renovar() =>
      _renovando ??= _renovarAhora().whenComplete(() => _renovando = null);

  Future<bool> _renovarAhora() async {
    final refresh = _refreshToken;
    final vence = _refreshExpiresAt;
    if (refresh == null) return false;
    if (vence != null && !vence.isAfter(DateTime.now())) {
      _terminarSesion();
      return false;
    }
    try {
      final request = http.Request('POST', _resolve('api/auth/refresh'))
        ..headers['Content-Type'] = 'application/json; charset=utf-8'
        ..headers['Accept'] = 'application/json'
        ..body = jsonEncode({'refreshToken': refresh});
      final response = await (() async {
        final stream = await _client.send(request);
        return http.Response.fromStream(stream);
      })().timeout(timeout);
      // La sesión se cerró o cambió mientras se renovaba: se descarta el resultado.
      if (_refreshToken != refresh) return false;
      if (response.statusCode == 400 ||
          response.statusCode == 401 ||
          response.statusCode == 403) {
        _terminarSesion();
        return false;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'El servidor respondió HTTP ${response.statusCode}. Inténtalo más tarde.',
          statusCode: response.statusCode,
        );
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final expiry = data is Map && data['expiraEn'] is String
          ? DateTime.tryParse(data['expiraEn'] as String)
          : null;
      if (data is! Map ||
          data['token'] is! String ||
          (data['token'] as String).isEmpty ||
          expiry == null) {
        throw const ApiException(
          'La respuesta del servidor no contiene una sesión válida.',
        );
      }
      bearerToken = data['token'] as String;
      _accessExpiresAt = expiry;
      return true;
    } on TimeoutException {
      throw const ApiException('El servidor tardó demasiado en responder.');
    } on http.ClientException {
      throw const ApiException(
        'No se pudo contactar al backend. Revisa que esté iniciado, la URL y CORS.',
      );
    } on FormatException {
      throw const ApiException(
        'La respuesta del servidor no contiene JSON válido.',
      );
    }
  }

  Uri _resolve(String path) =>
      _baseUri.resolve(path.replaceFirst(RegExp(r'^/+'), ''));

  Future<Map<String, dynamic>> getJson(String path) async =>
      _object(await requestJson('GET', path));

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    bool authenticated = true,
  }) async => _object(
    await requestJson('POST', path, body: body, authenticated: authenticated),
  );

  Map<String, dynamic> _object(Object? data) {
    if (data is! Map<String, dynamic>) {
      throw const ApiException('La API no devolvió un objeto JSON válido.');
    }
    return data;
  }

  Future<Object?> requestJson(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final uri = _resolve(path);
    return _send(
      () {
        final request = http.Request(method, uri);
        if (body != null) {
          request.headers['Content-Type'] = 'application/json; charset=utf-8';
          request.body = jsonEncode(body);
        }
        return request;
      },
      path,
      authenticated: authenticated,
    );
  }

  Future<Object?> requestMultipart(
    String method,
    String path, {
    required Map<String, String> fields,
    List<http.MultipartFile> files = const [],
  }) {
    final uri = _resolve(path);
    // Los archivos son un flujo de un solo uso: no se puede reenviar tras renovar.
    return _send(
      () => http.MultipartRequest(method, uri)
        ..fields.addAll(fields)
        ..files.addAll(files),
      path,
      reintentable: false,
    );
  }

  static const _sesionExpirada = ApiException(
    'Tu sesión expiró o no es válida. Inicia sesión de nuevo.',
    statusCode: 401,
  );

  Future<Object?> _send(
    http.BaseRequest Function() build,
    String path, {
    bool authenticated = true,
    bool reintentable = true,
  }) async {
    try {
      // Renovación preventiva: evita mandar un token a punto de vencer.
      if (authenticated && _puedeRenovar && _accesoPorVencer) {
        if (!await _renovar()) throw _sesionExpirada;
      }
      var renovado = false;
      late http.Response response;
      while (true) {
        final request = build();
        request.headers['Accept'] = 'application/json';
        if (authenticated && bearerToken != null) {
          request.headers['Authorization'] = 'Bearer $bearerToken';
        }
        response = await (() async {
          final stream = await _client.send(request);
          return http.Response.fromStream(stream);
        })().timeout(timeout);
        // 401 con sesión renovable: el acceso venció (p. ej. reloj desfasado).
        if (response.statusCode == 401 &&
            authenticated &&
            _puedeRenovar &&
            !renovado) {
          renovado = true;
          if (!await _renovar()) throw _sesionExpirada;
          if (reintentable) continue;
        }
        break;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = switch (response.statusCode) {
          400 => 'Revisa los datos del formulario.',
          401 =>
            authenticated
                ? 'Tu sesión expiró o no es válida. Inicia sesión de nuevo.'
                : 'Correo o contraseña incorrectos.',
          403 => 'No tienes permiso para realizar esta operación.',
          404 => 'El recurso no existe o no tienes acceso.',
          409 =>
            path.contains('usuarios/registro')
                ? 'El correo electrónico ya está registrado.'
                : 'No se pudo completar la operación porque hay datos relacionados o en conflicto.',
          413 =>
            'El archivo es demasiado grande. Selecciona un logo de hasta 2 MB.',
          429 => 'Demasiados intentos. Inténtalo más tarde.',
          _ =>
            'El servidor respondió HTTP ${response.statusCode}. Inténtalo más tarde.',
        };
        final fieldErrors = <String, String>{};
        if (response.statusCode == 400 || response.statusCode == 409) {
          try {
            final problem = jsonDecode(utf8.decode(response.bodyBytes));
            if (problem is Map && problem['errores'] is Map) {
              for (final entry in (problem['errores'] as Map).entries) {
                if (entry.key is String &&
                    entry.value is String &&
                    (entry.value as String).isNotEmpty) {
                  fieldErrors[entry.key as String] = entry.value as String;
                }
              }
            }
          } on FormatException {
            /* Keep the HTTP fallback for non-JSON errors. */
          }
        }
        throw ApiException(
          message,
          statusCode: response.statusCode,
          fieldErrors: Map.unmodifiable(fieldErrors),
        );
      }
      if (response.statusCode == 204) return null;
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on TimeoutException {
      throw const ApiException('El servidor tardó demasiado en responder.');
    } on http.ClientException {
      throw const ApiException(
        'No se pudo contactar al backend. Revisa que esté iniciado, la URL y CORS.',
      );
    } on FormatException {
      throw const ApiException(
        'La respuesta del servidor no contiene JSON válido.',
      );
    }
  }

  void close() => _client.close();
}
