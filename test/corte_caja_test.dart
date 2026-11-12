import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punto_de_venta/features/corte_caja/application/ports/outbound/corte_caja_gateway.dart';
import 'package:punto_de_venta/features/corte_caja/application/services/gestion_corte_caja.dart';
import 'package:punto_de_venta/features/corte_caja/domain/corte_caja.dart';
import 'package:punto_de_venta/features/corte_caja/infrastructure/adapters/inbound/flutter/corte_caja_page.dart';
import 'package:punto_de_venta/features/corte_caja/infrastructure/adapters/inbound/flutter/corte_realizado_page.dart';
import 'package:punto_de_venta/features/corte_caja/infrastructure/adapters/inbound/flutter/detalle_movimientos_page.dart';

class FakeCorteCajaGateway implements CorteCajaGateway {
  CorteCaja? corteActivo;
  int abrirCorteLlamadas = 0;
  int cerrarCorteLlamadas = 0;

  @override
  Future<CorteCaja> abrirCorte({
    required int sucursalId,
    required double montoInicial,
  }) async {
    abrirCorteLlamadas++;
    corteActivo = CorteCaja(
      id: 42,
      cajaId: 1,
      sucursalId: sucursalId,
      sucursalNombre: 'Centro',
      usuarioId: 10,
      usuarioNombre: 'María López',
      fechaHoraApertura: DateTime(2026, 10, 1, 9, 0),
      cerrado: false,
      montoInicial: montoInicial,
      totalVentas: 0.0,
      totalAnticipos: 0.0,
      totalLiquidaciones: 0.0,
      totalCancelaciones: 0.0,
      ventasEfectivo: DesgloseMetodoPago(
        totalVentas: 0,
        anticipos: 0,
        liquidaciones: 0,
        cancelaciones: 0,
        subtotalNeto: 0,
        montoInicial: montoInicial,
        totalEsperado: montoInicial,
      ),
      ventasTarjeta: const DesgloseMetodoPago(
        totalVentas: 0,
        anticipos: 0,
        liquidaciones: 0,
        cancelaciones: 0,
        subtotalNeto: 0,
        montoInicial: 0,
        totalEsperado: 0,
      ),
      cancelacionesPedidos: const SeccionCancelaciones(
        totalCancelaciones: 0,
        cancelacionesEfectivo: 0,
        cancelacionesTarjeta: 0,
        detalles: [],
      ),
      totalEfectivo: montoInicial,
      totalTarjeta: 0.0,
      totalEstimado: montoInicial,
      productos: const [],
    );
    return corteActivo!;
  }

  @override
  Future<CorteCaja?> obtenerCorteActivo(int sucursalId) async => corteActivo;

  @override
  Future<CorteCaja> cerrarCorte({
    required int corteId,
    required double totalReal,
  }) async {
    cerrarCorteLlamadas++;
    final actual = corteActivo!;
    final cerrado = CorteCaja(
      id: actual.id,
      cajaId: actual.cajaId,
      sucursalId: actual.sucursalId,
      sucursalNombre: actual.sucursalNombre,
      usuarioId: actual.usuarioId,
      usuarioNombre: actual.usuarioNombre,
      fechaHoraApertura: actual.fechaHoraApertura,
      fechaHoraCierre: DateTime(2026, 10, 1, 18, 0),
      cerrado: true,
      montoInicial: actual.montoInicial,
      totalVentas: actual.totalVentas,
      totalAnticipos: actual.totalAnticipos,
      totalLiquidaciones: actual.totalLiquidaciones,
      totalCancelaciones: actual.totalCancelaciones,
      ventasEfectivo: actual.ventasEfectivo,
      ventasTarjeta: actual.ventasTarjeta,
      cancelacionesPedidos: actual.cancelacionesPedidos,
      totalEfectivo: actual.totalEfectivo,
      totalTarjeta: actual.totalTarjeta,
      totalEstimado: actual.totalEstimado,
      totalReal: totalReal,
      diferencia: totalReal - actual.efectivoEsperado,
      productos: actual.productos,
    );
    corteActivo = null;
    return cerrado;
  }

  @override
  Future<CorteCaja> consultarCorte(int corteId) async => corteActivo!;

  @override
  Future<List<ResumenCorteCaja>> listarHistorial(
    int sucursalId, {
    int page = 0,
    int size = 20,
  }) async => [];
}

CorteCaja _crearCorteEjemplo() => CorteCaja(
  id: 41,
  cajaId: 1,
  sucursalId: 1,
  sucursalNombre: 'Centro',
  usuarioId: 5,
  usuarioNombre: 'María López',
  fechaHoraApertura: DateTime(2026, 10, 1, 8, 30),
  cerrado: false,
  montoInicial: 200.0,
  totalVentas: 1800.0,
  totalAnticipos: 500.0,
  totalLiquidaciones: 900.0,
  totalCancelaciones: 100.0,
  ventasEfectivo: const DesgloseMetodoPago(
    totalVentas: 1200.0,
    anticipos: 300.0,
    liquidaciones: 500.0,
    cancelaciones: 100.0,
    subtotalNeto: 1900.0,
    montoInicial: 200.0,
    totalEsperado: 2100.0,
  ),
  ventasTarjeta: const DesgloseMetodoPago(
    totalVentas: 600.0,
    anticipos: 200.0,
    liquidaciones: 400.0,
    cancelaciones: 0.0,
    subtotalNeto: 1200.0,
    montoInicial: 0.0,
    totalEsperado: 1200.0,
  ),
  cancelacionesPedidos: SeccionCancelaciones(
    totalCancelaciones: 100.0,
    cancelacionesEfectivo: 100.0,
    cancelacionesTarjeta: 0.0,
    detalles: [
      CancelacionPedido(
        pedidoId: 18,
        folio: 'P-018',
        monto: 100.0,
        metodoPago: 'EFECTIVO',
        tipoPago: 'ANTICIPO',
        fechaHora: DateTime(2026, 10, 1, 14, 0),
      ),
    ],
  ),
  totalEfectivo: 2100.0,
  totalTarjeta: 1200.0,
  totalEstimado: 3300.0,
  productos: const [
    ProductoVendido(
      idProducto: 1,
      nombre: 'Maceta mediana',
      cantidad: 8,
      precioUnitario: 120.0,
      subtotal: 960.0,
    ),
    ProductoVendido(
      idProducto: 2,
      nombre: 'Jabonero',
      cantidad: 8,
      precioUnitario: 85.0,
      subtotal: 680.0,
    ),
  ],
);

void main() {
  group('Corte de caja - Dominio y Caso de uso', () {
    test('Calcula el total neto y efectivo esperado adecuadamente', () {
      final corte = _crearCorteEjemplo();
      expect(corte.totalNetoDia, 3100.0);
      expect(corte.efectivoEsperado, 2100.0);
    });

    test('Validaciones de montos no negativos en GestionCorteCaja', () async {
      final fake = FakeCorteCajaGateway();
      final gestion = GestionCorteCaja(fake);

      expect(
        () => gestion.abrirCorte(sucursalId: 1, montoInicial: -10),
        throwsA(isA<CorteCajaFailure>()),
      );

      expect(
        () => gestion.cerrarCorte(corteId: 1, totalReal: -5),
        throwsA(isA<CorteCajaFailure>()),
      );
    });
  });

  group('Corte de caja - Widgets', () {
    testWidgets('Muestra pantalla de apertura cuando la caja está cerrada', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fake = FakeCorteCajaGateway()..corteActivo = null;
      final gestion = GestionCorteCaja(fake);

      await tester.pumpWidget(
        MaterialApp(
          home: CorteCajaPage(
            gestion: gestion,
            sucursalId: 1,
            sucursalNombre: 'Centro',
            esPropietario: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Caja cerrada'), findsOneWidget);
      expect(find.text('Abrir turno de caja'), findsOneWidget);

      // Abre el turno
      final botonAbrir = find.text('Abrir turno de caja');
      await tester.ensureVisible(botonAbrir);
      await tester.tap(botonAbrir);
      await tester.pumpAndSettle();

      expect(fake.abrirCorteLlamadas, 1);
      expect(find.text('Corte de caja'), findsOneWidget);
    });

    testWidgets(
      'Muestra resumen del día, revisión de efectivo y badge de diferencia en corte activo',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fake = FakeCorteCajaGateway()..corteActivo = _crearCorteEjemplo();
        final gestion = GestionCorteCaja(fake);

        await tester.pumpWidget(
          MaterialApp(
            home: CorteCajaPage(
              gestion: gestion,
              sucursalId: 1,
              sucursalNombre: 'Centro',
              esPropietario: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Corte de caja'), findsOneWidget);
        expect(find.text('Resumen del día'), findsOneWidget);
        expect(find.text('Revisión de efectivo'), findsOneWidget);
        expect(find.text('Fondo inicial'), findsOneWidget);
        expect(find.text('Efectivo esperado'), findsOneWidget);

        final botonCorte = find.text('Realizar corte');
        await tester.ensureVisible(botonCorte);
        expect(botonCorte, findsOneWidget);

        // Sin diferencia inicialmente al coincidir
        expect(find.text('Sin diferencia - \$0.00'), findsOneWidget);
      },
    );

    testWidgets('DetalleMovimientosPage muestra productos y alerta de cancelación', (
      tester,
    ) async {
      final corte = _crearCorteEjemplo();

      await tester.pumpWidget(
        MaterialApp(
          home: DetalleMovimientosPage(
            corte: corte,
            esPropietario: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Detalle del día'), findsOneWidget);
      expect(find.text('Productos vendidos'), findsOneWidget);
      expect(find.text('Maceta mediana'), findsOneWidget);
      expect(find.text('Jabonero'), findsOneWidget);
      expect(find.text('Pagos y cancelaciones'), findsOneWidget);
      expect(find.text('Pedido P-018 cancelado'), findsOneWidget);
      expect(find.text('Descontado automáticamente del corte'), findsOneWidget);
      expect(find.text('Volver al resumen'), findsOneWidget);
    });

    testWidgets('CorteRealizadoPage muestra el respaldo contable del corte', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final corte = _crearCorteEjemplo();

      await tester.pumpWidget(
        MaterialApp(
          home: CorteRealizadoPage(
            corte: corte,
            esPropietario: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Corte realizado'), findsOneWidget);
      expect(find.text('Tu respaldo contable está listo'), findsOneWidget);
      expect(find.text('Ventas directas'), findsOneWidget);
      expect(find.text('Anticipos de pedidos'), findsOneWidget);
      expect(find.text('Liquidaciones de pedidos'), findsOneWidget);
      expect(find.text('Cancelaciones'), findsOneWidget);
      expect(find.text('Efectivo neto'), findsOneWidget);
      expect(find.text('Tarjeta'), findsOneWidget);
      expect(find.text('Volver a caja'), findsOneWidget);
    });
  });
}

