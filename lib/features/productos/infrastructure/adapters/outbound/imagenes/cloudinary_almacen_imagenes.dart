import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../../application/ports/outbound/almacen_imagenes.dart';
import '../../../../domain/imagen_producto.dart';

final class CloudinaryAlmacenImagenes implements AlmacenImagenes {
  CloudinaryAlmacenImagenes({
    required String cloudName,
    required String uploadPreset,
    http.Client Function()? crearCliente,
    Duration timeout = const Duration(seconds: 45),
  }) : _cloudName = cloudName.trim(),
       _uploadPreset = uploadPreset.trim(),
       _crearCliente = crearCliente ?? http.Client.new,
       _timeout = timeout;

  final String _cloudName;
  final String _uploadPreset;
  final http.Client Function() _crearCliente;
  final Duration _timeout;

  @override
  Future<ImagenProductoSubida> subir(
    ArchivoImagenProducto archivo, {
    void Function(double fraccion)? alProgresar,
  }) async {
    if (_cloudName.isEmpty || _uploadPreset.isEmpty) {
      throw const ImagenProductoException(
        'Falta configurar la subida de imágenes.',
      );
    }
    if (archivo.bytes.isEmpty) {
      throw const ImagenProductoException(
        'La imagen que se va a subir está vacía.',
      );
    }
    final solicitud =
        _SolicitudConProgreso(
            Uri(
              scheme: 'https',
              host: 'api.cloudinary.com',
              pathSegments: ['v1_1', _cloudName, 'image', 'upload'],
            ),
            alProgresar,
          )
          ..followRedirects = false
          ..fields['upload_preset'] = _uploadPreset
          ..files.add(
            http.MultipartFile(
              'file',
              _fragmentos(archivo.bytes),
              archivo.bytes.length,
              filename: 'producto.jpg',
              contentType: MediaType('image', 'jpeg'),
            ),
          );

    final cliente = _crearCliente();
    try {
      final respuesta = await _enviar(cliente, solicitud).timeout(_timeout);
      if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) {
        throw const ImagenProductoException(
          'Cloudinary rechazó la subida. Inténtalo de nuevo.',
        );
      }
      return _leerResultado(respuesta.bodyBytes);
    } on TimeoutException {
      throw const ImagenProductoException(
        'La subida tardó demasiado. Revisa tu conexión e inténtalo de nuevo.',
      );
    } on http.ClientException {
      throw const ImagenProductoException(
        'No se pudo conectar con Cloudinary. Revisa tu conexión.',
      );
    } on FormatException {
      throw const ImagenProductoException(
        'Cloudinary no devolvió una URL y un identificador válidos.',
      );
    } finally {
      cliente.close();
    }
  }

  Future<http.Response> _enviar(
    http.Client cliente,
    http.BaseRequest solicitud,
  ) async => http.Response.fromStream(await cliente.send(solicitud));

  ImagenProductoSubida _leerResultado(Uint8List bytes) {
    final datos = jsonDecode(utf8.decode(bytes));
    if (datos is! Map<String, dynamic>) throw const FormatException();
    final url = datos['secure_url'];
    final publicId = datos['public_id'];
    if (url is! String || publicId is! String || publicId.trim().isEmpty) {
      throw const FormatException();
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'res.cloudinary.com' ||
        uri.userInfo.isNotEmpty ||
        uri.path.length <= 1) {
      throw const FormatException();
    }
    return ImagenProductoSubida(url: url, publicId: publicId);
  }

  Stream<List<int>> _fragmentos(Uint8List bytes) async* {
    const tamano = 64 * 1024;
    for (var inicio = 0; inicio < bytes.length; inicio += tamano) {
      yield Uint8List.sublistView(
        bytes,
        inicio,
        math.min(inicio + tamano, bytes.length),
      );
    }
  }
}

final class _SolicitudConProgreso extends http.MultipartRequest {
  _SolicitudConProgreso(Uri url, this._alProgresar) : super('POST', url);

  final void Function(double)? _alProgresar;

  @override
  http.ByteStream finalize() {
    final cuerpo = super.finalize();
    final avisar = _alProgresar;
    if (avisar == null) return cuerpo;

    final total = contentLength;
    var enviados = 0;
    var ultimoPorcentaje = 0;
    avisar(0);
    return http.ByteStream(
      cuerpo.map((fragmento) {
        enviados += fragmento.length;
        final porcentaje = enviados * 100 ~/ total;
        if (porcentaje > ultimoPorcentaje) {
          ultimoPorcentaje = porcentaje;
          avisar(porcentaje / 100);
        }
        return fragmento;
      }),
    );
  }
}
