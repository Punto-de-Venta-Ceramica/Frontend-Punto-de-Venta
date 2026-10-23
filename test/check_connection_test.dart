import 'package:flutter_test/flutter_test.dart';
import 'package:punto_de_venta/features/connection/application/ports/outbound/health_gateway.dart';
import 'package:punto_de_venta/features/connection/application/services/check_connection.dart';
import 'package:punto_de_venta/features/connection/domain/backend_health.dart';
import 'package:punto_de_venta/features/connection/domain/connection_failure.dart';

class InMemoryHealthGateway implements HealthGateway {
  InMemoryHealthGateway({this.failure});
  final ConnectionFailure? failure;

  @override
  Future<BackendHealth> check() async {
    if (failure != null) throw failure!;
    return const BackendHealth(application: 'puntoventaapi');
  }
}

void main() {
  test('El caso de uso funciona sin HTTP ni widgets', () async {
    final useCase = CheckConnection(InMemoryHealthGateway());
    expect((await useCase.execute()).application, 'puntoventaapi');
  });

  test('Conserva el fallo de aplicación del puerto de salida', () async {
    const failure = ConnectionFailure('Sin conexión');
    final useCase = CheckConnection(InMemoryHealthGateway(failure: failure));
    await expectLater(useCase.execute(), throwsA(same(failure)));
  });
}
