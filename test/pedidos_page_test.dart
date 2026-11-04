import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/pedidos/application/gestion_pedidos.dart';
import 'package:punto_de_venta/features/pedidos/application/ports/pedidos_gateway.dart';
import 'package:punto_de_venta/features/pedidos/domain/pedido.dart';
import 'package:punto_de_venta/features/pedidos/infrastructure/adapters/inbound/registrar_pedido_page.dart';
import 'package:punto_de_venta/features/productos/domain/producto.dart';

class _Gateway implements PedidosGateway {
  DatosPedido? recibido;
  @override
  Future<List<AvisoPedido>> notificaciones() async => [];
  @override
  Future<void> marcarLeida(int id) async {}
  @override
  Future<List<ProductoPedido>> productos(int id) async => [
    const ProductoPedido(
      id: 3,
      nombre: 'Taza',
      precio: 100,
      cantidadMinima: 2,
      porcentajeDescuento: 10,
    ),
    const ProductoPedido(id: 4, nombre: 'Plato', precio: 50),
  ];
  @override
  Future<List<CortePedido>> cortes(int id) async => [
    const CortePedido(id: 8, apertura: '2026-11-03T10:00:00Z'),
  ];
  @override
  Future<void> registrar(DatosPedido datos) async {
    recibido = datos;
  }

  @override
  Future<List<Pedido>> listar(int id) async => [];
  @override
  Future<void> pagar(int id, double monto, String metodo, int corte) async {}
  @override
  Future<void> cambiarEstado(int id, String estado) async {}
  @override
  Future<void> cancelar(int id) async {}
}

void main() {
  testWidgets(
    'captura el pedido en tres pasos y conserva la dirección y corte',
    (tester) async {
      final gateway = _Gateway();
      await tester.pumpWidget(
        MaterialApp(
          theme: BarroTheme.data,
          home: RegistrarPedidoPage(
            gestion: GestionPedidos(gateway),
            sucursalId: 1,
            negocio: const NegocioProducto(id: 1, nombre: 'Cerámica'),
            esPropietario: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Taza').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(1), '2');
      await tester.ensureVisible(find.text('Agregar producto'));
      await tester.tap(find.text('Agregar producto'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Aplica descuento de mayoreo'),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<int>).first,
      );
      await tester.tap(find.byType(DropdownButtonFormField<int>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Plato').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continuar'));
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      final campos = find.byType(TextFormField);
      await tester.enterText(campos.at(0), 'Ana');
      await tester.enterText(campos.at(1), '5512345678');
      await tester.enterText(campos.at(2), 'Puebla');
      await tester.enterText(campos.at(3), 'Centro');
      await tester.enterText(campos.at(4), 'Hidalgo 123');
      await tester.ensureVisible(find.text('Continuar'));
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '50');
      await tester.ensureVisible(find.text('Registrar pedido').last);
      await tester.tap(find.text('Registrar pedido').last);
      await tester.pumpAndSettle();
      expect(gateway.recibido?.calle, 'Hidalgo 123');
      expect(gateway.recibido?.corteId, 8);
      expect(gateway.recibido?.productos.map((p) => p.productoId), [3, 4]);
    },
  );
}
