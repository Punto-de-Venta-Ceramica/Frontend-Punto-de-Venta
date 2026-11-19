import 'package:flutter_test/flutter_test.dart';
import 'package:punto_de_venta/features/pedidos/application/ticket_pedido.dart';
import 'package:punto_de_venta/features/pedidos/domain/pedido.dart';
import 'package:punto_de_venta/features/tickets/domain/ticket.dart';
import 'package:punto_de_venta/features/tickets/infrastructure/adapters/outbound/escpos/escpos_ticket.dart';

Pedido _pedido({String estado = 'TERMINADO'}) => Pedido(
  id: 1,
  folio: 'PED-1',
  estado: estado,
  cliente: 'Ana',
  telefono: '',
  ciudad: '',
  colonia: '',
  calle: '',
  descripcion: '',
  tipoEntrega: 'LOCAL',
  fechaCreacion: DateTime(2026, 11, 10, 9, 5),
  productos: const [
    DetallePedido(
      nombre: 'Cazuela de barro grande con asas',
      cantidad: 10,
      precioUnitario: 120,
      subtotal: 1080,
      porcentajeDescuento: 10,
    ),
    DetallePedido(
      nombre: 'Jarro',
      cantidad: 2,
      subtotal: 90,
      porcentajeDescuento: 0,
    ),
  ],
  total: 1170,
  pagado: 1170,
  saldo: 0,
);

/// Texto imprimible del ticket: quita los comandos ESC/GS/FS y decodifica.
String _texto(List<int> bytes) {
  final salida = StringBuffer();
  var i = 0;
  while (i < bytes.length) {
    final b = bytes[i];
    if (b == 0x1B || b == 0x1D) {
      // ESC @ y FS . miden 2; los demás que usamos, 3 (GS v 0 no hay aquí).
      i += bytes[i + 1] == 0x40 ? 2 : 3;
    } else if (b == 0x1C) {
      i += 2;
    } else {
      salida.writeCharCode(b);
      i++;
    }
  }
  return salida.toString();
}

void main() {
  const encoder = EscPosTicket();
  final entrega = DateTime(2026, 11, 14, 18, 30);

  test('solo se arma el ticket de un pedido terminado', () {
    expect(
      () => ticketDePedido(
        _pedido(estado: 'ENTREGADO'),
        negocio: 'Santo Barro',
        sucursal: 'Centro',
        entrega: entrega,
      ),
      throwsA(isA<ImpresionException>()),
    );
  });

  test('las líneas del ticket suman el total del pedido', () {
    final ticket = ticketDePedido(
      _pedido(),
      negocio: 'Santo Barro',
      sucursal: 'Centro',
      entrega: entrega,
    );
    final suma = ticket.lineas.fold<double>(
      0,
      (s, l) => s + l.importeBruto - l.descuento,
    );
    expect(suma, closeTo(ticket.total, 0.001));
    expect(ticket.lineas.first.descuento, closeTo(120, 0.001));
    // Sin precio de lista, se usa el efectivo y no hay descuento.
    expect(ticket.lineas.last.precioUnitario, 45);
    expect(ticket.lineas.last.descuento, 0);
  });

  test('inicia la impresora, sale del modo chino y usa WPC1252', () {
    final bytes = encoder.codificar(
      ticketDePedido(
        _pedido(),
        negocio: 'Santo Barro',
        sucursal: 'Centro',
        entrega: entrega,
      ),
    );
    expect(bytes.take(10), [
      0x1B, 0x40, 0x1C, 0x2E, 0x1B, 0x74, 16, // reinicio, sin chino, WPC1252
      0x1B, 0x33, 26, // interlineado corto (fuente A)
    ]);
    // Avanza papel al final: la POS-5890 no corta.
    expect(bytes.skip(bytes.length - 3), [0x1B, 0x64, 4]);
  });

  test('el ticket lleva todos los datos y ningún renglón pasa de 32', () {
    final texto = _texto(
      encoder.codificar(
        ticketDePedido(
          _pedido(),
          negocio: 'Santo Barro',
          sucursal: 'Centro',
          entrega: entrega,
        ),
      ),
    );
    expect(texto, contains('SANTO BARRO'));
    expect(texto, contains('Sucursal: Centro'));
    expect(texto, contains('TICKET DE PEDIDO'));
    expect(texto, contains('Folio: PED-1'));
    expect(texto, isNot(contains('10/11/2026 09:05')));
    expect(texto, isNot(contains('Pedido:')));
    expect(texto, contains('Entrega:'));
    expect(texto, contains('14/11/2026 18:30'));
    expect(texto, contains('10 x \$120.00'));
    expect(texto, contains('\$1,200.00'));
    expect(texto, contains('Descuento 10%'));
    expect(texto, contains('-\$120.00'));
    expect(texto, contains('2 x \$45.00'));
    expect(texto, contains('\$1,170.00'));
    for (final renglon in texto.split('\n')) {
      expect(renglon.length, lessThanOrEqualTo(32), reason: renglon);
    }
  });

  test('el ticket de pedido no lleva eslogan del negocio', () {
    final ticket = ticketDePedido(
      _pedido(),
      negocio: 'Santo Barro',
      sucursal: 'Centro',
      entrega: entrega,
    );
    expect(ticket.eslogan, isNull);
    expect(
      _texto(encoder.codificar(ticket)),
      contains('Gracias por su compra'),
    );
  });

  test('el eslogan del ticket de venta se imprime al pie', () {
    final texto = _texto(
      encoder.codificar(
        Ticket(
          tipo: TipoTicket.venta,
          negocio: 'Santo Barro',
          sucursal: 'Centro',
          folio: 'VTA-000001',
          fecha: entrega,
          total: 10,
          lineas: const [],
          eslogan: 'Santo Barro la mejor calidad al mejor precio',
        ),
      ),
    );
    expect(texto, contains('TICKET DE VENTA'));
    expect(texto, contains('Santo Barro la mejor calidad al'));
    for (final renglon in texto.split('\n')) {
      expect(renglon.length, lessThanOrEqualTo(32), reason: renglon);
    }
  });

  test('acentos en WPC1252 y lo que no existe se vuelve ?', () {
    expect(EscPosTicket.cp1252('ñÁé¿¡'), [0xF1, 0xC1, 0xE9, 0xBF, 0xA1]);
    expect(EscPosTicket.cp1252('— €'), [0x97, 0x20, 0x80]);
    expect(EscPosTicket.cp1252('😀'), [0x3F]);
  });

  test('un folio UUID se corta en un guion, sin letras sueltas', () {
    expect(
      encoder.envolverEnGuiones('Folio: 33770435-dffd-430b-a516-5632062ea54a'),
      ['Folio: 33770435-dffd-430b-a516-', '5632062ea54a'],
    );
  });

  test('envolver corta por palabras y parte las muy largas', () {
    expect(EscPosTicket.envolver('uno dos tres', 7), ['uno dos', 'tres']);
    expect(EscPosTicket.envolver('abcdefghij', 4), ['abcd', 'efgh', 'ij']);
  });
}
