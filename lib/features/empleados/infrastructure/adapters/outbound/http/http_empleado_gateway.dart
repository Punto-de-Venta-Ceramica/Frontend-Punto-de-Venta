import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import '../../../../application/ports/outbound/empleado_gateway.dart';
import '../../../../domain/empleado.dart';

class HttpEmpleadoGateway implements EmpleadoGateway {
  const HttpEmpleadoGateway(this._api);

  final ApiClient _api;

  Future<T> _seguro<T>(Future<T> Function() operacion) async {
    try {
      return await operacion();
    } on ApiException catch (e) {
      throw EmpleadoFailure(
        e.message,
        fieldErrors: e.fieldErrors,
        sesionExpirada: e.statusCode == 401,
      );
    } on FormatException {
      throw const EmpleadoFailure('El servidor devolvió datos no válidos.');
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

  Empleado _empleado(Object? data) {
    final json = _map(data);
    return Empleado(
      id: _id(json['id']),
      negocioId: _id(json['negocioId']),
      nombre: _texto(json['nombre']),
      apellidoP: json['apellidoP'] as String?,
      apellidoM: json['apellidoM'] as String?,
      correoElectronico: _texto(json['correoElectronico']),
      sucursales: [
        for (final item in (json['sucursales'] as List<dynamic>? ?? const []))
          SucursalEmpleado(
            id: _id((item as Map<String, dynamic>)['id']),
            nombre: _texto(item['nombre'], opcional: true),
          ),
      ],
    );
  }

  @override
  Future<List<NegocioEmpleado>> negocios() => _seguro(
    () async => _lista(await _api.requestJson('GET', 'api/negocios'), (data) {
      final json = _map(data);
      return NegocioEmpleado(
        id: _id(json['id']),
        nombre: _texto(json['nombre']),
      );
    }),
  );

  @override
  Future<List<SucursalEmpleado>> sucursales(int negocioId) => _seguro(
    () async => _lista(
      await _api.requestJson(
        'POST',
        'api/sucursales/consultar',
        body: {'negocioId': negocioId},
      ),
      (data) {
        final json = _map(data);
        return SucursalEmpleado(
          id: _id(json['id']),
          nombre: _texto(json['nombre']),
        );
      },
    ),
  );

  @override
  Future<List<Empleado>> listar(
    int negocioId, {
    bool incluirAsignacion = true,
    int? sucursalId,
  }) => _seguro(
    () async => _lista(
      await _api.requestJson(
        'GET',
        'api/empleados?negocioId=$negocioId&incluirAsignacion=$incluirAsignacion'
            '${sucursalId == null ? '' : '&sucursalId=$sucursalId'}',
      ),
      _empleado,
    ),
  );

  @override
  Future<EmpleadoCreado> registrar(NuevoEmpleado datos) => _seguro(() async {
    final body = <String, dynamic>{
      'negocioId': datos.negocioId,
      'nombre': datos.nombre.trim(),
      'correoElectronico': datos.correoElectronico.trim(),
    };
    if (datos.apellidoP != null && datos.apellidoP!.trim().isNotEmpty) {
      body['apellidoP'] = datos.apellidoP!.trim();
    }
    if (datos.apellidoM != null && datos.apellidoM!.trim().isNotEmpty) {
      body['apellidoM'] = datos.apellidoM!.trim();
    }
    if (datos.sucursalId != null && datos.sucursalId! > 0) {
      body['sucursalId'] = datos.sucursalId;
    }

    final json = _map(
      await _api.requestJson('POST', 'api/empleados', body: body),
    );

    return EmpleadoCreado(
      id: _id(json['id']),
      negocioId: _id(json['negocioId']),
      nombre: _texto(json['nombre']),
      correoElectronico: _texto(json['correoElectronico']),
      passwordGenerada: _texto(json['passwordGenerada']),
      sucursalNombre: json['sucursalNombre'] as String?,
    );
  });

  @override
  Future<Empleado> asignarSucursales({
    required int negocioId,
    required int empleadoId,
    required List<int> sucursalIds,
  }) => _seguro(
    () async => _empleado(
      await _api.requestJson(
        'PUT',
        'api/empleados/sucursales',
        body: {
          'negocioId': negocioId,
          'empleadoId': empleadoId,
          'sucursalIds': sucursalIds,
        },
      ),
    ),
  );

  @override
  Future<void> eliminar(int negocioId, int empleadoId) => _seguro(
    () async => _api.requestJson(
      'DELETE',
      'api/empleados/$empleadoId?negocioId=$negocioId',
    ),
  );
}
