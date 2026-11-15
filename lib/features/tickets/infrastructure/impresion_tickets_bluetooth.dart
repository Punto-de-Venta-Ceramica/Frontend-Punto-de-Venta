import '../application/impresion_tickets.dart';
import 'adapters/outbound/bluetooth_impresora_tickets.dart';
import 'adapters/outbound/secure_impresora_preferida.dart';

/// Impresión real del dispositivo: impresora térmica Bluetooth y la última
/// impresora usada guardada en el almacenamiento seguro. Es el valor por
/// defecto de las pantallas que imprimen tickets (pedidos y ventas).
const impresionTicketsBluetooth = ImpresionTickets(
  BluetoothImpresoraTickets(),
  SecureImpresoraPreferida(),
);
