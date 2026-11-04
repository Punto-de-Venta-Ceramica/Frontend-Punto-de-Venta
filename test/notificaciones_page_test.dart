import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/features/notificaciones/application/contador_notificaciones.dart';
import 'package:punto_de_venta/features/pedidos/application/gestion_pedidos.dart';
import 'package:punto_de_venta/features/pedidos/application/ports/pedidos_gateway.dart';
import 'package:punto_de_venta/features/pedidos/domain/pedido.dart';
import 'package:punto_de_venta/features/pedidos/infrastructure/adapters/inbound/notificaciones_page.dart';

class _IconoFalso implements IndicadorIcono {
  @override
  Future<void> actualizar(int cantidad) async {}
}

class _PedidosFalsos extends Fake implements PedidosGateway {
  List<AvisoPedido> avisos = [];

  @override
  Future<List<AvisoPedido>> notificaciones() async => List.of(avisos);

  @override
  Future<void> marcarLeida(int id) async {
    avisos = avisos
        .map(
          (aviso) => aviso.id == id
              ? AvisoPedido(
                  id: aviso.id,
                  titulo: aviso.titulo,
                  mensaje: aviso.mensaje,
                  leida: true,
                )
              : aviso,
        )
        .toList();
  }
}

void main() {
  testWidgets('actualiza la lista cuando cambia el conteo y al solicitarlo', (
    tester,
  ) async {
    final api = ApiClient(
      baseUrl: 'http://localhost/',
      client: MockClient(
        (_) async => throw StateError('No se esperaba una solicitud'),
      ),
    );
    final contador = ContadorNotificaciones(api, _IconoFalso());
    final pedidos = _PedidosFalsos();
    await tester.pumpWidget(
      MaterialApp(
        home: NotificacionesPage(
          gestion: GestionPedidos(pedidos),
          contador: contador,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No tienes notificaciones.'), findsOneWidget);

    pedidos.avisos = [
      const AvisoPedido(
        id: 1,
        titulo: 'Nuevo pedido',
        mensaje: 'Aviso',
        leida: false,
      ),
    ];
    contador.value = 1;
    await tester.pumpAndSettle();
    expect(find.text('Nuevo pedido'), findsOneWidget);

    pedidos.avisos = [
      const AvisoPedido(
        id: 2,
        titulo: 'Otro pedido',
        mensaje: 'Aviso',
        leida: false,
      ),
    ];
    await tester.tap(find.byTooltip('Actualizar notificaciones'));
    await tester.pumpAndSettle();
    expect(find.text('Otro pedido'), findsOneWidget);
    expect(find.text('Nuevo pedido'), findsNothing);

    await tester.tap(find.text('Otro pedido'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva'), findsNothing);
    expect(find.text('Otro pedido'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    contador.dispose();
    api.close();
  });
}
