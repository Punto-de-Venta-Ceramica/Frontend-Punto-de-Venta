import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punto_de_venta/features/connection/application/ports/inbound/check_connection_use_case.dart';
import 'package:punto_de_venta/features/connection/domain/backend_health.dart';
import 'package:punto_de_venta/features/connection/domain/connection_failure.dart';
import 'package:punto_de_venta/features/connection/infrastructure/adapters/inbound/flutter/connection_page.dart';

class RetryConnection implements CheckConnectionUseCase {
  int calls = 0;

  @override
  Future<BackendHealth> execute() async {
    calls++;
    if (calls == 1) throw const ConnectionFailure('Servicio no disponible');
    return const BackendHealth(application: 'puntoventaapi');
  }
}

void main() {
  testWidgets('La pantalla reintenta usando solo el puerto de entrada', (
    tester,
  ) async {
    final useCase = RetryConnection();
    await tester.pumpWidget(
      MaterialApp(home: ConnectionPage(checkConnection: useCase)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Servicio no disponible'), findsOneWidget);
    await tester.tap(find.text('Comprobar conexión'));
    await tester.pumpAndSettle();
    expect(find.text('Backend conectado'), findsOneWidget);
    expect(useCase.calls, 2);
  });
}
