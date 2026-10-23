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
    try {
      final uri = _baseUri.resolve(path.replaceFirst(RegExp(r'^/+'), ''));
      final headers = {
        'Accept': 'application/json',
        if (body != null) 'Content-Type': 'application/json; charset=utf-8',
        if (authenticated && bearerToken != null)
          'Authorization': 'Bearer $bearerToken',
      };
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final response = await (() async {
        final stream = await _client.send(request);
        return http.Response.fromStream(stream);
      })().timeout(timeout);
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
