import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/features/connection/application/ports/outbound/health_gateway.dart';
import 'package:punto_de_venta/features/connection/domain/backend_health.dart';
import 'package:punto_de_venta/features/connection/domain/connection_failure.dart';

/// Translates the REST contract into application types and failures.
class HttpHealthGateway implements HealthGateway {
  const HttpHealthGateway(this._api);
  final ApiClient _api;

  @override
  Future<BackendHealth> check() async {
    try {
      final data = await _api.getJson('api/health');
      if (data['status'] != 'UP' || data['application'] != 'puntoventaapi') {
        throw const ConnectionFailure(
          'El servicio no confirmó el estado de la API de punto de venta.',
        );
      }
      return BackendHealth(application: data['application'] as String);
    } on ApiException catch (error) {
      throw ConnectionFailure(error.message);
    }
  }
}
