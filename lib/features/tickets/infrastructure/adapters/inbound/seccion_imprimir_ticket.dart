import 'package:flutter/material.dart';

import '../../../application/impresion_tickets.dart';
import '../../../domain/ticket.dart';
import 'imprimir_ticket_widgets.dart';
import 'seleccionar_impresora_dialog.dart';

/// Sección reutilizable para imprimir un ticket: recuerda la impresora
/// preferida, la pide la primera vez, imprime y avisa del resultado (con
/// reintento si falla).
///
/// Cada módulo solo indica cómo armar su [Ticket]; no sabe nada de
/// impresoras ni de Bluetooth.
class SeccionImprimirTicket extends StatefulWidget {
  const SeccionImprimirTicket({
    required this.impresion,
    required this.ticket,
    this.habilitado = true,
    this.onImprimiendo,
    super.key,
  });

  final ImpresionTickets impresion;

  /// Arma el ticket al momento de imprimir. Puede lanzar
  /// [ImpresionException] si no se puede imprimir.
  final Ticket Function() ticket;

  /// false = deshabilitada (otra acción de la pantalla está en curso).
  final bool habilitado;

  /// Avisa cuando empieza (true) y termina (false) la impresión, para que la
  /// pantalla bloquee sus demás acciones mientras tanto.
  final ValueChanged<bool>? onImprimiendo;

  @override
  State<SeccionImprimirTicket> createState() => _SeccionImprimirTicketState();
}

class _SeccionImprimirTicketState extends State<SeccionImprimirTicket> {
  // Última impresora usada en este dispositivo; null = preguntar.
  ImpresoraTicket? _impresora;
  bool _imprimiendo = false;

  @override
  void initState() {
    super.initState();
    widget.impresion
        .preferida()
        .then((impresora) {
          if (mounted && impresora != null && _impresora == null) {
            setState(() => _impresora = impresora);
          }
        })
        .catchError((Object _) {});
  }

  /// Imprime en la impresora guardada; la primera vez pide elegirla.
  Future<void> _imprimir() async {
    if (_imprimiendo) return;
    final impresora = _impresora ?? await _elegirImpresora();
    if (impresora == null || !mounted) return;
    _cambiarImprimiendo(true);
    try {
      await widget.impresion.imprimir(impresora, widget.ticket());
      if (mounted) {
        setState(() => _impresora = impresora);
        avisoImpresion(context, 'Ticket impreso en ${impresora.nombre}.');
      }
    } on ImpresionException catch (e) {
      if (mounted) _fallo(e.message);
    } catch (_) {
      if (mounted) _fallo('No se pudo imprimir el ticket.');
    } finally {
      if (mounted) _cambiarImprimiendo(false);
    }
  }

  Future<ImpresoraTicket?> _elegirImpresora() async {
    final elegida = await seleccionarImpresora(
      context,
      widget.impresion,
      actual: _impresora,
    );
    if (elegida != null && mounted) setState(() => _impresora = elegida);
    return elegida;
  }

  void _cambiarImprimiendo(bool valor) {
    setState(() => _imprimiendo = valor);
    widget.onImprimiendo?.call(valor);
  }

  void _fallo(String mensaje) =>
      avisoImpresion(context, mensaje, error: true, onReintentar: _imprimir);

  @override
  Widget build(BuildContext context) => TarjetaImprimirTicket(
    impresora: _impresora,
    imprimiendo: _imprimiendo,
    onImprimir: widget.habilitado ? _imprimir : null,
    onCambiarImpresora: widget.habilitado ? _elegirImpresora : null,
  );
}
