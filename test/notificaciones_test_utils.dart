import 'package:flutter_test/flutter_test.dart';
import 'package:toastification/toastification.dart';

/// `toastification` es un singleton global: si un test termina con un toast
/// abierto, deja su temporizador de cierre pendiente (el test falla) y el
/// siguiente test reutiliza el overlay ya desmontado (sus toasts no se ven).
///
/// Llamar al final de cada test que muestre notificaciones.
Future<void> cerrarNotificaciones(WidgetTester tester) async {
  toastification.dismissAll(delayForAnimation: false);
  await tester.pump(const Duration(seconds: 1));
}

/// Igual que [testWidgets], pero cierra las notificaciones al terminar.
void testWidgetsConNotificaciones(
  String descripcion,
  WidgetTesterCallback cuerpo,
) => testWidgets(descripcion, (tester) async {
  await cuerpo(tester);
  await cerrarNotificaciones(tester);
});
