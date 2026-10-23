import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
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

  Future<Map<String, dynamic>> getJson(String path) async {
    try {
      final response = await _client
          .get(
            _baseUri.resolve(path.replaceFirst(RegExp(r'^/+'), '')),
            headers: {'Accept': 'application/json'},
          )
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'El servidor respondió HTTP ${response.statusCode}.',
        );
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map<String, dynamic>) {
        throw const ApiException('La API no devolvió un objeto JSON válido.');
      }
      return data;
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
