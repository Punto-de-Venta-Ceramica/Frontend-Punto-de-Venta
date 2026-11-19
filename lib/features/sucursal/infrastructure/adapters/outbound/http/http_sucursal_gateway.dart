import 'package:punto_de_venta/core/infrastructure/cache/consultas_compartidas.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import '../../../../application/ports/outbound/sucursal_gateway.dart';
import '../../../../domain/sucursal.dart';

class HttpSucursalGateway implements SucursalGateway {
  const HttpSucursalGateway(this._api, {ConsultasCompartidas? compartidas})
    : _compartidas = compartidas;
  final ApiClient _api;

  /// Caché de negocios y sucursales que comparten los módulos. Crear, editar
  /// o eliminar una sucursal descarta las sucursales guardadas.
  final ConsultasCompartidas? _compartidas;

  Future<T> _seguro<T>(Future<T> Function() operacion) async {
    try {
      return await operacion();
    } on ApiException catch (e) {
      throw SucursalFailure(
        e.message,
        fieldErrors: e.fieldErrors,
        sesionExpirada: e.statusCode == 401,
      );
    } on FormatException {
      throw const SucursalFailure(
        'El servidor devolvió datos de sucursal no válidos.',
      );
    }
  }

  Map<String, dynamic> _map(Object? data) {
    if (data is! Map<String, dynamic>) throw const FormatException();
    return data;
  }

  int _id(Object? value) {
    if (value is! int || value <= 0) throw const FormatException();
    return value;
  }

  String _texto(Object? value, {bool opcional = false}) {
    if (opcional && value == null) return '';
    if (value is! String) throw const FormatException();
    return value;
  }

  List<T> _lista<T>(Object? data, T Function(Object?) parse) {
    if (data is! List) throw const FormatException();
    return data.map(parse).toList(growable: false);
  }

  Sucursal _sucursal(Object? data) {
    final json = _map(data);
    return Sucursal(
      id: _id(json['id']),
      negocioId: _id(json['negocioId']),
      nombre: _texto(json['nombre']),
      descripcion: _texto(json['descripcion'], opcional: true),
      ciudad: _texto(json['ciudad'], opcional: true),
      calle: _texto(json['calle'], opcional: true),
      codigoPostal: _texto(json['codigoPostal'], opcional: true),
    );
  }

  @override
  Future<List<NegocioSucursal>> negocios() => _seguro(
    () async => _lista(
      await (_compartidas?.negocios() ??
          _api.requestJson('GET', 'api/negocios')),
      (data) {
        final json = _map(data);
        return NegocioSucursal(
          id: _id(json['id']),
          nombre: _texto(json['nombre']),
        );
      },
    ),
  );
  @override
  Future<List<Sucursal>> listar(int negocioId) => _seguro(() async {
    final lista = _lista(
      await (_compartidas?.sucursales(negocioId) ??
          _api.requestJson(
            'POST',
            'api/sucursales/consultar',
            body: {'negocioId': negocioId},
          )),
      _sucursal,
    );
    if (lista.any((s) => s.negocioId != negocioId)) {
      throw const FormatException();
    }
    return lista;
  });
  @override
  Future<Sucursal> crear(int negocioId, DatosSucursal datos) =>
      _seguro(() async {
        final sucursal = _sucursal(
          await _api.requestJson(
            'POST',
            'api/sucursales',
            body: {
              'negocioId': negocioId,
              'nombre': datos.nombre.trim(),
              'descripcion': datos.descripcion.trim(),
              'ciudad': datos.ciudad.trim(),
              'calle': datos.calle.trim(),
              'codigoPostal': datos.codigoPostal,
            },
          ),
        );
        _compartidas?.descartarSucursales(negocioId);
        return sucursal;
      });
  @override
  Future<Sucursal> editar(int id, DatosSucursal datos) => _seguro(() async {
    final sucursal = _sucursal(
      await _api.requestJson(
        'PATCH',
        'api/sucursales',
        body: {
          'id': id,
          'nombre': datos.nombre.trim(),
          'descripcion': datos.descripcion.trim(),
        },
      ),
    );
    _compartidas?.descartarSucursales(sucursal.negocioId);
    return sucursal;
  });
  @override
  Future<void> eliminar(int id) => _seguro(() async {
    await _api.requestJson('DELETE', 'api/sucursales', body: {'id': id});
    // Solo se conoce la sucursal, no su negocio: se descartan todas.
    _compartidas?.descartarSucursales();
  });
}
