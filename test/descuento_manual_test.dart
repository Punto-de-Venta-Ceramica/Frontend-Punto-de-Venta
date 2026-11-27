import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punto_de_venta/core/infrastructure/widgets/descuento_manual_dialog.dart';
import 'package:punto_de_venta/features/pedidos/domain/pedido.dart';
import 'package:punto_de_venta/features/ventas/domain/venta.dart';

void main() {
  const vaso = ProductoVenta(
    id: 1,
    nombre: 'Vaso',
    precio: 10,
    existencia: 20,
    descuentos: [RangoDescuentoVenta(cantidadMinima: 1, porcentaje: 5)],
  );
  const varios = ProductoVenta(
    id: 77,
    nombre: 'Artículo artesanal',
    precio: 0,
    existencia: 0,
    precioVariable: true,
  );

  test('el porcentaje manual solo acepta de 1 a 100 con 2 decimales', () {
    expect(leerPorcentajeManual('1'), 1);
    expect(leerPorcentajeManual('12,5'), 12.5);
    expect(leerPorcentajeManual('100'), 100);
    for (final invalido in ['', '0', '0.99', '100.01', '10.001', 'abc']) {
      expect(leerPorcentajeManual(invalido), isNull, reason: invalido);
    }
  });

  test('en ventas el descuento manual reemplaza al del catálogo', () {
    const linea = SeleccionVenta(
      producto: vaso,
      cantidad: 2,
      aplicarDescuento: true,
      descuentoManual: 25,
    );
    expect(linea.porcentajeAplicado, 25);
    expect(linea.importe, 15);
    // Cambiar la cantidad lo conserva; desmarcar lo quita.
    expect(linea.actualizar(vaso, 4).importe, 30);
    expect(linea.conDescuento().importe, 20);
  });

  test('el artículo artesanal admite descuento manual', () {
    const linea = SeleccionVenta(
      producto: varios,
      cantidad: 2,
      precioLibre: 50,
      descuentoManual: 10,
    );
    expect(linea.importe, 90);
  });

  test('en pedidos el descuento manual se aplica aunque no haya escalón', () {
    const linea = LineaPedido(productoId: 1, cantidad: 2);
    final manual = linea.conDescuentoManual(30);
    expect(manual.descuentoManual, 30);
    expect(manual.conCantidad(3).descuentoManual, 30);
    expect(manual.conDescuento(false).descuentoManual, isNull);
    expect(manual.conDescuentoManual(null).aplicarDescuento, isFalse);
  });

  Future<DescuentoManual?> abrir(WidgetTester tester, String porcentaje) async {
    DescuentoManual? resultado;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => resultado = await pedirDescuentoManual(
              context,
              producto: 'Vaso',
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('campo-descuento-manual')),
      porcentaje,
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Aplicar descuento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar descuento'));
    await tester.pumpAndSettle();
    return resultado;
  }

  testWidgets('hasta 60 % se aplica sin alerta', (tester) async {
    await abrir(tester, '60');
    expect(find.text('¡Atención!'), findsNothing);
    expect(find.byKey(const ValueKey('campo-descuento-manual')), findsNothing);
  });

  testWidgets('arriba de 60 % pide confirmar y permite revisar', (
    tester,
  ) async {
    await abrir(tester, '75');
    expect(find.text('¡Atención!'), findsOneWidget);
    expect(find.text('Sí, aplicar 75 %'), findsOneWidget);
    expect(
      find.textContaining(
        'El descuento es muy alto. El cliente pagará solo el 25% del precio. '
        'Revisa que el porcentaje sea correcto antes de aplicarlo.',
        findRichText: true,
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('revisar-descuento-alto')));
    await tester.pumpAndSettle();
    // Sigue en el diálogo del porcentaje para corregirlo.
    expect(
      find.byKey(const ValueKey('campo-descuento-manual')),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Aplicar descuento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar descuento'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmar-descuento-alto')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('campo-descuento-manual')), findsNothing);
  });
}
