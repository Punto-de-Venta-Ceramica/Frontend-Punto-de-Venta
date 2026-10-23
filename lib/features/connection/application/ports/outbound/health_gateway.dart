import 'package:punto_de_venta/features/connection/domain/backend_health.dart';

abstract interface class HealthGateway {
  Future<BackendHealth> check();
}
