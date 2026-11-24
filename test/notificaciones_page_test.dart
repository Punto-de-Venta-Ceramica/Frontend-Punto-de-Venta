import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/features/notificaciones/application/contador_notificaciones.dart';
import 'package:punto_de_venta/features/pedidos/application/gestion_pedidos.dart';
import 'package:punto_de_venta/features/pedidos/application/ports/pedidos_gateway.dart';
import 'package:punto_de_venta/features/pedidos/domain/pedido.dart';
import 'package:punto_de_venta/features/pedidos/infrastructure/adapters/inbound/notificaciones_page.dart';
import 'package:punto_de_venta/features/pedidos/infrastructure/adapters/inbound/pedido_detalle_page.dart';

class _IconoFalso implements IndicadorIcono {
  @override
  Future<void> actualizar(int cantidad) async {}
}

class _PedidosFalsos extends Fake implements PedidosGateway {
  List<AvisoPedido> avisos = [];
  final paginasPedidas = <int>[];

  /// Como el servidor: 20 por página, tal cual está ordenada la lista.
  @override
  Future<PaginaAvisos> notificaciones({int pagina = 0}) async {
    paginasPedidas.add(pagina);
    final desde = pagina * 20;
    return PaginaAvisos(
      avisos: avisos.skip(desde).take(20).toList(),
      pagina: pagina,
      ultima: desde + 20 >= avisos.length,
    );
  }

  @override
  Future<Pedido> obtener(int pedidoId) async => Pedido(
    id: pedidoId,
    folio: 'PED-000007',
    estado: 'ENCARGADO',
    cliente: 'Ana López',
    telefono: '5512345678',
    ciudad: '',
    colonia: '',
    calle: '',
    descripcion: '',
    tipoEntrega: 'LOCAL',
    productos: const [],
    total: 100,
    pagado: 0,
    saldo: 100,
    sucursalId: 3,
    negocioId: 1,
    negocio: 'Cerámica',
    sucursal: 'Centro',
  );

  @override
  Future<bool> cajaAbierta(int sucursalId) async => true;

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
                  pedidoId: aviso.pedidoId,
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
          esPropietario: true,
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
    // La primera página se pone al inicio y lo ya cargado se conserva.
    expect(find.text('Otro pedido'), findsOneWidget);
    expect(find.text('Nuevo pedido'), findsOneWidget);

    // Al leerlo sale de "No leídas" (el filtro por defecto) y pasa a "Leídas".
    await tester.tap(find.text('Otro pedido'));
    await tester.pumpAndSettle();
    expect(find.text('Otro pedido'), findsNothing);
    await tester.tap(find.text('Leídas'));
    await tester.pumpAndSettle();
    expect(find.text('Otro pedido'), findsOneWidget);
    expect(find.text('Nuevo pedido'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    contador.dispose();
    api.close();
  });

  testWidgets('al tocar un aviso con pedido abre su detalle', (tester) async {
    final api = ApiClient(
      baseUrl: 'http://localhost/',
      client: MockClient(
        (_) async => throw StateError('No se esperaba una solicitud'),
      ),
    );
    final contador = ContadorNotificaciones(api, _IconoFalso());
    final pedidos = _PedidosFalsos()
      ..avisos = [
        const AvisoPedido(
          id: 5,
          titulo: 'Nuevo pedido',
          mensaje: 'Se registró un nuevo pedido.',
          leida: true,
          pedidoId: 7,
        ),
      ];
    await tester.pumpWidget(
      MaterialApp(
        home: NotificacionesPage(
          gestion: GestionPedidos(pedidos),
          contador: contador,
          esPropietario: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Es un aviso leído: por defecto no aparece hasta elegir "Leídas".
    expect(find.text('Nuevo pedido'), findsNothing);
    await tester.tap(find.text('Leídas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nuevo pedido'));
    await tester.pumpAndSettle();
    expect(find.byType(PedidoDetallePage), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    contador.dispose();
    api.close();
  });

  testWidgets('carga de 20 en 20 y filtra leídas / no leídas en la app', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 30000);
    addTearDown(tester.view.reset);
    final api = ApiClient(
      baseUrl: 'http://localhost/',
      client: MockClient(
        (_) async => throw StateError('No se esperaba una solicitud'),
      ),
    );
    final contador = ContadorNotificaciones(api, _IconoFalso());
    // 45 avisos, del 45 (más reciente) al 1; los pares ya están leídos.
    final pedidos = _PedidosFalsos()
      ..avisos = [
        for (var i = 45; i >= 1; i--)
          AvisoPedido(
            id: i,
            titulo: 'Aviso $i',
            mensaje: 'Detalle',
            leida: i.isEven,
          ),
      ];
    await tester.pumpWidget(
      MaterialApp(
        home: NotificacionesPage(
          gestion: GestionPedidos(pedidos),
          contador: contador,
          esPropietario: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Solo se pidió la primera página; por defecto se ven las no leídas.
    expect(pedidos.paginasPedidas, [0]);
    expect(find.text('Aviso 45'), findsOneWidget);
    expect(find.text('Aviso 44'), findsNothing);
    expect(find.text('Aviso 25'), findsNothing);

    await tester.tap(find.text('Leídas'));
    await tester.pumpAndSettle();
    expect(find.text('Aviso 44'), findsOneWidget);
    expect(find.text('Aviso 45'), findsNothing);

    await tester.tap(find.text('Todas'));
    await tester.pumpAndSettle();
    expect(find.text('Aviso 45'), findsOneWidget);
    expect(find.text('Aviso 44'), findsOneWidget);

    await tester.tap(find.text('Cargar más notificaciones'));
    await tester.pumpAndSettle();
    expect(pedidos.paginasPedidas.last, 1);
    expect(find.text('Aviso 6'), findsOneWidget);
    expect(find.text('Aviso 5'), findsNothing);

    await tester.tap(find.text('Cargar más notificaciones'));
    await tester.pumpAndSettle();
    expect(find.text('Aviso 1'), findsOneWidget);
    expect(find.text('Cargar más notificaciones'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    contador.dispose();
    api.close();
  });

  testWidgets('agrupa por día y muestra hace cuánto llegó cada aviso', (
    tester,
  ) async {
    final api = ApiClient(
      baseUrl: 'http://localhost/',
      client: MockClient(
        (_) async => throw StateError('No se esperaba una solicitud'),
      ),
    );
    final contador = ContadorNotificaciones(api, _IconoFalso());
    final ahora = DateTime.now();
    final pedidos = _PedidosFalsos()
      ..avisos = [
        AvisoPedido(
          id: 2,
          titulo: 'Pedido entregado',
          mensaje: 'Un pedido fue entregado.',
          leida: false,
          fecha: ahora.subtract(const Duration(seconds: 10)),
        ),
        AvisoPedido(
          id: 1,
          titulo: 'Nuevo pedido',
          mensaje: 'Se registró un nuevo pedido.',
          leida: false,
          fecha: ahora.subtract(const Duration(days: 1)),
        ),
      ];
    await tester.pumpWidget(
      MaterialApp(
        home: NotificacionesPage(
          gestion: GestionPedidos(pedidos),
          contador: contador,
          esPropietario: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('HOY'), findsOneWidget);
    expect(find.text('AYER'), findsOneWidget);
    expect(find.text('Ahora'), findsOneWidget);
    expect(find.text('2 notificaciones nuevas'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    contador.dispose();
    api.close();
  });
}
