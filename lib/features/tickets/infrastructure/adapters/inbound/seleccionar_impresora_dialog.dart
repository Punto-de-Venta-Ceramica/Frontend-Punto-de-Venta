import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';

import '../../../application/impresion_tickets.dart';
import '../../../domain/ticket.dart';

const _suave = Color(0xFFFBEFEA);

/// Hoja inferior para elegir una impresora vinculada. Devuelve null si se
/// cierra sin elegir.
Future<ImpresoraTicket?> seleccionarImpresora(
  BuildContext context,
  ImpresionTickets impresion, {
  ImpresoraTicket? actual,
}) => showModalBottomSheet<ImpresoraTicket>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (_) => _SeleccionarImpresora(impresion: impresion, actual: actual),
);

class _SeleccionarImpresora extends StatefulWidget {
  const _SeleccionarImpresora({required this.impresion, this.actual});
  final ImpresionTickets impresion;
  final ImpresoraTicket? actual;
  @override
  State<_SeleccionarImpresora> createState() => _SeleccionarImpresoraState();
}

class _SeleccionarImpresoraState extends State<_SeleccionarImpresora> {
  List<ImpresoraTicket>? _impresoras;
  String? _error;

  @override
  void initState() {
    super.initState();
    _buscar();
  }

  Future<void> _buscar() async {
    setState(() {
      _impresoras = null;
      _error = null;
    });
    try {
      final lista = await widget.impresion.vinculadas();
      // Las que parecen impresoras, primero.
      lista.sort(
        (a, b) => (_esImpresora(b) ? 1 : 0) - (_esImpresora(a) ? 1 : 0),
      );
      if (mounted) setState(() => _impresoras = lista);
    } on ImpresionException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudieron consultar las impresoras.');
      }
    }
  }

  static bool _esImpresora(ImpresoraTicket i) =>
      RegExp('print|pos|ticket', caseSensitive: false).hasMatch(i.nombre);

  @override
  Widget build(BuildContext context) {
    final alto = MediaQuery.sizeOf(context).height * 0.75;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: alto),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Elegir impresora',
                          style: BarroTheme.type(
                            20,
                            28,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Dispositivos vinculados por Bluetooth',
                          style: BarroTheme.type(
                            13,
                            19,
                            color: BarroTheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Buscar de nuevo',
                    onPressed: _impresoras == null && _error == null
                        ? null
                        : _buscar,
                    icon: const Icon(Icons.refresh, color: BarroTheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(child: _contenido()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contenido() {
    final impresoras = _impresoras;
    if (_error != null) {
      return _Estado(
        icono: Icons.bluetooth_disabled,
        titulo: 'No se pudo usar el Bluetooth',
        texto: _error!,
        accion: 'Reintentar',
        onAccion: _buscar,
      );
    }
    if (impresoras == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Buscando impresoras…'),
          ],
        ),
      );
    }
    if (impresoras.isEmpty) {
      return _Estado(
        icono: Icons.print_disabled_outlined,
        titulo: 'No hay impresoras vinculadas',
        texto:
            '1. Enciende la impresora.\n'
            '2. En Ajustes > Bluetooth del teléfono, vincula '
            '"BlueTooth Printer" (PIN 0000 o 1234).\n'
            '3. Vuelve aquí y toca Reintentar.',
        accion: 'Reintentar',
        onAccion: _buscar,
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: impresoras.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final impresora = impresoras[i];
        final elegida = impresora.direccion == widget.actual?.direccion;
        final esImpresora = _esImpresora(impresora);
        return Material(
          color: elegida ? _suave : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: elegida ? BarroTheme.primary : BarroTheme.border,
              width: elegida ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.pop(context, impresora),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: esImpresora ? _suave : const Color(0xFFF3EEEC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      esImpresora
                          ? Icons.print_outlined
                          : Icons.bluetooth_outlined,
                      color: esImpresora
                          ? BarroTheme.primary
                          : BarroTheme.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          impresora.nombre,
                          style: BarroTheme.type(
                            15,
                            22,
                            weight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          impresora.direccion,
                          style: BarroTheme.type(
                            12,
                            18,
                            color: BarroTheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (elegida)
                    const Icon(Icons.check_circle, color: BarroTheme.primary)
                  else
                    const Icon(
                      Icons.chevron_right,
                      color: BarroTheme.placeholder,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Estado extends StatelessWidget {
  const _Estado({
    required this.icono,
    required this.titulo,
    required this.texto,
    required this.accion,
    required this.onAccion,
  });
  final IconData icono;
  final String titulo, texto, accion;
  final VoidCallback onAccion;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: _suave,
            shape: BoxShape.circle,
          ),
          child: Icon(icono, size: 30, color: BarroTheme.primary),
        ),
        const SizedBox(height: 12),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: BarroTheme.type(16, 23, weight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          texto,
          style: BarroTheme.type(14, 21, color: BarroTheme.secondary),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onAccion,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(accion),
            style: OutlinedButton.styleFrom(
              foregroundColor: BarroTheme.primary,
              minimumSize: const Size.fromHeight(46),
              side: const BorderSide(color: BarroTheme.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
