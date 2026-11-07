import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.fieldErrors = const {},
    this.code,
  });
  final String message;
  final int? statusCode;
  final Map<String, String> fieldErrors;
  final String? code;
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
    final uri = _baseUri.resolve(path.replaceFirst(RegExp(r'^/+'), ''));
    final request = http.Request(method, uri);
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }
    return _send(request, path, authenticated: authenticated);
  }

  Future<Object?> requestMultipart(
    String method,
    String path, {
    required Map<String, String> fields,
    List<http.MultipartFile> files = const [],
  }) {
    final uri = _baseUri.resolve(path.replaceFirst(RegExp(r'^/+'), ''));
    final request = http.MultipartRequest(method, uri)
      ..fields.addAll(fields)
      ..files.addAll(files);
    return _send(request, path);
  }

  Future<Object?> _send(
    http.BaseRequest request,
    String path, {
    bool authenticated = true,
  }) async {
    try {
      request.headers['Accept'] = 'application/json';
      if (authenticated && bearerToken != null) {
        request.headers['Authorization'] = 'Bearer $bearerToken';
      }
      final response = await (() async {
        final stream = await _client.send(request);
        return http.Response.fromStream(stream);
      })().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        var message = switch (response.statusCode) {
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
        String? code;
        if (response.statusCode == 400 || response.statusCode == 409) {
          try {
            final problem = jsonDecode(utf8.decode(response.bodyBytes));
            if (problem is Map) {
              if (problem['errores'] is Map) {
                for (final entry in (problem['errores'] as Map).entries) {
                  if (entry.key is String &&
                      entry.value is String &&
                      (entry.value as String).isNotEmpty) {
                    fieldErrors[entry.key as String] = entry.value as String;
                  }
                }
              }
              final ruta = path
                  .replaceFirst(RegExp(r'^/+'), '')
                  .split('?')
                  .first;
              if (response.statusCode == 400 &&
                  (ruta == 'api/pedidos' || ruta.startsWith('api/pedidos/'))) {
                final recibido = problem['codigo'];
                final detalle = problem['detail'];
                if (recibido is String) code = recibido;
                if (code == null &&
                    detalle is String &&
                    (detalle.trim() ==
                            'Debe haber un corte de caja abierto para la sucursal del pedido.' ||
                        detalle.trim() ==
                            'El corte de caja debe estar abierto y pertenecer a la sucursal del pedido.')) {
                  code = 'CORTE_CAJA_NO_ABIERTO';
                }
                message = switch (code) {
                  'CORTE_CAJA_NO_ABIERTO' =>
                    'No hay un corte de caja abierto en esta sucursal. Abre uno antes de registrar un pago.',
                  'PAGO_SUPERA_SALDO' =>
                    'El pago supera el saldo calculado por el servidor. Actualiza el pedido y revisa el importe.',
                  'PRODUCTO_NO_DISPONIBLE' =>
                    'Uno de los productos ya no está disponible. Vuelve a la lista de pedidos e inicia el registro de nuevo.',
                  _ => message,
                };
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
          code: code,
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
