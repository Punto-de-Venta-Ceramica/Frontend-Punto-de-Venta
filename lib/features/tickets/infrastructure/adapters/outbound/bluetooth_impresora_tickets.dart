import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../../application/impresion_tickets.dart';
import '../../../domain/ticket.dart';
import 'escpos/escpos_ticket.dart';

/// Impresora térmica por Bluetooth (perfil serie SPP en Android, BLE en iOS)
/// que habla ESC/POS, como la POS-5890A-L.
///
/// En Android la impresora debe estar vinculada antes en Ajustes > Bluetooth
/// (PIN habitual: 0000 o 1234).
class BluetoothImpresoraTickets implements ImpresoraTicketsPort {
  const BluetoothImpresoraTickets({this.encoder = const EscPosTicket()});

  final EscPosTicket encoder;

  @override
  Future<List<ImpresoraTicket>> vinculadas() async {
    await _preparar();
    final lista = await PrintBluetoothThermal.pairedBluetooths;
    return [
      for (final d in lista)
        ImpresoraTicket(
          nombre: d.name.trim().isEmpty ? d.macAdress : d.name.trim(),
          direccion: d.macAdress,
        ),
    ];
  }

  @override
  Future<void> imprimir(ImpresoraTicket impresora, Ticket ticket) async {
    await _preparar();
    final bytes = encoder.codificar(ticket);

    // Cierra una conexión previa (quizá con otra impresora) antes de abrir.
    if (await PrintBluetoothThermal.connectionStatus) {
      await PrintBluetoothThermal.disconnect;
    }
    final conectada = await PrintBluetoothThermal.connect(
      macPrinterAddress: impresora.direccion,
    );
    if (!conectada) {
      throw ImpresionException(
        'No se pudo conectar con "${impresora.nombre}". Revisa que esté '
        'encendida, con papel y cerca del teléfono.',
      );
    }
    try {
      if (!await PrintBluetoothThermal.writeBytes(
        // El plugin en Android espera List<Int>; un Uint8List llega como
        // ByteArray, el cast falla y devuelve false sin imprimir nada.
        List<int>.of(bytes, growable: true),
      )) {
        throw const ImpresionException(
          'Se perdió la conexión con la impresora. Intenta de nuevo.',
        );
      }
      // Da tiempo a que salgan los últimos bytes antes de cerrar el socket.
      await Future<void>.delayed(const Duration(seconds: 3));
    } finally {
      await PrintBluetoothThermal.disconnect;
    }
  }

  Future<void> _preparar() async {
    if (kIsWeb ||
        !(Platform.isAndroid || Platform.isIOS || Platform.isWindows)) {
      throw const ImpresionException(
        'La impresión de tickets solo está disponible en la app de Android, '
        'iOS o Windows.',
      );
    }
    if (Platform.isAndroid || Platform.isIOS) {
      final permisos = Platform.isAndroid
          ? [Permission.bluetoothConnect, Permission.bluetoothScan]
          : [Permission.bluetooth];
      final estados = await permisos.request();
      if (estados.values.any((e) => !e.isGranted && !e.isLimited)) {
        throw const ImpresionException(
          'Permite el acceso a "Dispositivos cercanos" (Bluetooth) para '
          'imprimir tickets.',
        );
      }
    }
    if (!await PrintBluetoothThermal.bluetoothEnabled) {
      throw const ImpresionException(
        'El Bluetooth está apagado. Actívalo e intenta de nuevo.',
      );
    }
  }
}
