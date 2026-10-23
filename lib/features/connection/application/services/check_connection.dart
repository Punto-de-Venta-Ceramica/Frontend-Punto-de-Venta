import 'package:punto_de_venta/features/connection/application/ports/inbound/check_connection_use_case.dart';
import 'package:punto_de_venta/features/connection/application/ports/outbound/health_gateway.dart';
import 'package:punto_de_venta/features/connection/domain/backend_health.dart';

class CheckConnection implements CheckConnectionUseCase {
  const CheckConnection(this._healthGateway);
  final HealthGateway _healthGateway;

  @override
  Future<BackendHealth> execute() => _healthGateway.check();
}
