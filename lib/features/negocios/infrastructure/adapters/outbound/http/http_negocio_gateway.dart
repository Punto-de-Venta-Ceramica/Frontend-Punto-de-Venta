import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import '../../../../application/ports/outbound/negocio_gateway.dart';
import '../../../../domain/negocio.dart';

class HttpNegocioGateway implements NegocioGateway {
  const HttpNegocioGateway(this._api);
  final ApiClient _api;

  Future<T> _seguro<T>(Future<T> Function() operacion) async {
    try {
      return await operacion();
    } on ApiException catch (e) {
      throw NegocioFailure(
        e.message,
        fieldErrors: e.fieldErrors,
        sesionExpirada: e.statusCode == 401,
      );
    } on FormatException {
      throw const NegocioFailure(
        'El servidor devolvió datos de negocio no válidos.',
      );
    }
  }

  Negocio _negocio(Object? data) {
    if (data is! Map<String, dynamic> ||
        data['id'] is! int ||
        (data['id'] as int) <= 0 ||
        data['nombre'] is! String ||
        (data['logo'] != null && data['logo'] is! String)) {
      throw const FormatException();
    }
    return Negocio(
      id: data['id'] as int,
      nombre: data['nombre'] as String,
      logo: data['logo'] as String?,
    );
  }

  Future<Negocio> _guardar(
    String metodo,
    String ruta,
    DatosNegocio datos, {
    bool edicion = false,
  }) => _seguro(
    () async => _negocio(
      await _api.requestMultipart(
        metodo,
        ruta,
        fields: {
          'nombre': datos.nombre.trim(),
          if (edicion) 'eliminarLogo': datos.eliminarLogo.toString(),
        },
        files: [
          if (datos.logo case final logo?)
            http.MultipartFile.fromBytes(
              'logo',
              logo.contenido,
              filename: logo.nombre,
              contentType: MediaType.parse(logo.tipo!),
            ),
        ],
      ),
    ),
  );

  @override
  Future<List<Negocio>> listar() => _seguro(() async {
    final data = await _api.requestJson('GET', 'api/negocios');
    if (data is! List) throw const FormatException();
    return data.map(_negocio).toList(growable: false);
  });
  @override
  Future<Negocio> consultar(int id) => _seguro(
    () async => _negocio(await _api.requestJson('GET', 'api/negocios/$id')),
  );
  @override
  Future<Negocio> crear(DatosNegocio datos) =>
      _guardar('POST', 'api/negocios', datos);
  @override
  Future<Negocio> editar(int id, DatosNegocio datos) =>
      _guardar('PUT', 'api/negocios/$id', datos, edicion: true);
  @override
  Future<void> eliminar(int id) => _seguro(() async {
    await _api.requestJson('DELETE', 'api/negocios/$id');
  });
}
