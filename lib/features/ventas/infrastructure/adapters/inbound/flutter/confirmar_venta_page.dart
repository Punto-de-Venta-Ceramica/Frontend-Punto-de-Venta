import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:uuid/uuid.dart';

import '../../../../application/services/gestion_ventas.dart';
import '../../../../domain/venta.dart';
import 'ticket_venta_dialog.dart';
import 'ventas_widgets.dart';

class ConfirmarVentaPage extends StatefulWidget {
  const ConfirmarVentaPage({
    required this.contexto,
    required this.gestion,
    required this.sucursalId,
    required this.productos,
    required this.onSesionExpirada,
    super.key,
  });

  final VentaContexto contexto;
  final GestionVentas gestion;
  final int sucursalId;
  final List<SeleccionVenta> productos;
  final VoidCallback onSesionExpirada;

  @override
  State<ConfirmarVentaPage> createState() => _ConfirmarVentaPageState();
}

class _ConfirmarVentaPageState extends State<ConfirmarVentaPage> {
  final _efectivo = TextEditingController();
  static final _formatoEfectivo = RegExp(r'^\d{1,16}(?:[.,]\d{1,2})?$');
  MetodoPagoVenta? _metodo;
  CotizacionVenta? _cotizacion;
  String? _error;
  String? _errorMonto;
  ({String clave, num? monto})? _intento;
  bool _cotizando = false;
  bool _guardando = false;
  bool _ventaRegistrada = false;
  bool _consultandoSalida = false;

  bool get _resultadoIncierto => _intento != null && !_guardando;

  num? get _montoRecibido {
    final texto = _efectivo.text.trim();
    return _formatoEfectivo.hasMatch(texto)
        ? num.tryParse(texto.replaceAll(',', '.'))
        : null;
  }

  @override
  void initState() {
    super.initState();
    _preparar();
  }

  @override
  void dispose() {
    _efectivo.dispose();
    super.dispose();
  }

  Future<void> _preparar() async {
    if (_cotizando) return;
    setState(() {
      _cotizacion = null;
      _cotizando = true;
      _error = null;
      _errorMonto = null;
    });
    try {
      final cotizacion = await widget.gestion.preparar(
        sucursalId: widget.sucursalId,
        productos: widget.productos,
      );
      if (!mounted) return;
      setState(() {
        _cotizacion = cotizacion;
        _cotizando = false;
      });
    } on VentaFailure catch (error) {
      if (!mounted) return;
      if (error.sesionExpirada) {
        widget.onSesionExpirada();
        return;
      }
      setState(() {
        _error = error.mensaje;
        _cotizando = false;
      });
    }
  }

  Future<void> _confirmar() async {
    final metodo = _metodo;
    final cotizacion = _cotizacion;
    if (_guardando ||
        _ventaRegistrada ||
        metodo == null ||
        cotizacion == null) {
      return;
    }

    final esEfectivo = metodo == MetodoPagoVenta.efectivo;
    final monto = esEfectivo ? _montoRecibido : null;
    if (esEfectivo && !_resultadoIncierto) {
      if (monto == null || monto < cotizacion.total) {
        setState(() {
          _errorMonto = monto == null
              ? 'Ingresa un importe válido con hasta dos decimales.'
              : 'El efectivo recibido debe cubrir el total.';
        });
        return;
      }
    }

    final intento = _intento ?? (clave: const Uuid().v4(), monto: monto);
    setState(() {
      _intento = intento;
      _guardando = true;
      _error = null;
      _errorMonto = null;
    });
    try {
      final venta = await widget.gestion.confirmar(
        sucursalId: widget.sucursalId,
        productos: widget.productos,
        metodo: metodo,
        claveOperacion: intento.clave,
        montoRecibido: intento.monto,
      );
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _ventaRegistrada = true;
        _intento = null;
      });
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => const TicketVentaDialog(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(venta);
    } on VentaFailure catch (error) {
      if (!mounted) return;
      if (error.sesionExpirada) {
        widget.onSesionExpirada();
        return;
      }
      setState(() {
        _guardando = false;
        if (error.resultadoIncierto) {
          _error =
              'No se pudo comprobar si la venta se registró. '
              'Reintenta desde aquí para recuperar el resultado.';
        } else {
          _intento = null;
          if (error.errorMonto != null) _cotizacion = null;
          _error = error.errorMonto ?? error.mensaje;
        }
      });
    }
  }

  Future<void> _cancelar() async {
    if (_guardando || _ventaRegistrada || _consultandoSalida) return;
    if (_resultadoIncierto) {
      _consultandoSalida = true;
      final salir = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Venta pendiente de verificación'),
          content: const Text(
            'La venta pudo haberse registrado. Puedes reintentar la confirmación desde esta pantalla.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Volver a la venta'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Salir'),
            ),
          ],
        ),
      );
      _consultandoSalida = false;
      if (!mounted || salir != true) return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final metodo = _metodo;
    final cotizacion = _cotizacion;
    final ocupado = _guardando || _ventaRegistrada;
    final bloqueado = ocupado || _resultadoIncierto;
    final monto = _montoRecibido;
    final cambio =
        monto != null && cotizacion != null && monto >= cotizacion.total
        ? dineroVenta(monto - cotizacion.total)
        : '—';

    return PopScope<VentaRegistrada>(
      canPop: !bloqueado,
      onPopInvokedWithResult: (salio, _) {
        if (!salio && _resultadoIncierto) _cancelar();
      },
      child: VentaScaffold(
        contexto: widget.contexto,
        paso: '2 de 2 · Confirma los productos y el pago.',
        accion: _resultadoIncierto
            ? 'Reintentar confirmación'
            : 'Registrar venta',
        procesando: _guardando,
        onAccion: cotizacion != null && metodo != null && !ocupado
            ? _confirmar
            : null,
        onCancelar: ocupado ? null : _cancelar,
        children: [
          _resumen(cotizacion),
          const SizedBox(height: 28),
          VentaCampo(
            etiqueta: 'Método de pago *',
            child: ButtonTheme.fromButtonThemeData(
              data: ButtonTheme.of(context).copyWith(alignedDropdown: true),
              child: DropdownButtonFormField<MetodoPagoVenta>(
                initialValue: metodo,
                isExpanded: true,
                decoration: decoracionCampoVenta(),
                hint: const Text('Selecciona un método de pago'),
                items: [
                  for (final opcion in MetodoPagoVenta.values)
                    DropdownMenuItem(
                      value: opcion,
                      child: Text(opcion.etiqueta),
                    ),
                ],
                onChanged: bloqueado
                    ? null
                    : (valor) => setState(() {
                        _metodo = valor;
                        _errorMonto = null;
                      }),
              ),
            ),
          ),
          if (metodo == MetodoPagoVenta.efectivo) ...[
            const SizedBox(height: 20),
            VentaCampo(
              etiqueta: 'Efectivo recibido (MXN) *',
              child: TextField(
                controller: _efectivo,
                enabled: !bloqueado,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: decoracionCampoVenta(
                  indicacion: 'Ingresa el monto recibido',
                  error: _errorMonto,
                ),
                onChanged: (_) => setState(() => _errorMonto = null),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Cambio: $cambio',
              style: BarroTheme.type(14, 20, weight: FontWeight.w600),
            ),
          ],
          if (_cotizando) ...[
            const SizedBox(height: 16),
            const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Calculando total',
              ),
            ),
          ],
          if (_error case final error?) ...[
            const SizedBox(height: 16),
            AvisoVenta(
              error,
              onReintentar: cotizacion == null ? _preparar : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _resumen(CotizacionVenta? cotizacion) {
    final detalles =
        cotizacion?.detalles ??
        [
          for (final seleccion in widget.productos)
            DetalleVenta(
              nombre: seleccion.producto.nombre,
              cantidad: seleccion.cantidad,
              precioUnitario: seleccion.producto.precio,
              subtotal: seleccion.importe,
            ),
        ];
    final total =
        cotizacion?.total ??
        detalles.fold<num>(0, (suma, detalle) => suma + detalle.subtotal);
    final descuento =
        cotizacion?.descuento ??
        (detalles.fold<num>(
                      0,
                      (suma, detalle) =>
                          suma +
                          (detalle.precioUnitario * detalle.cantidad -
                              detalle.subtotal),
                    ) *
                    100)
                .round() /
            100;

    return VentaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Productos seleccionados',
            style: BarroTheme.type(18, 24, weight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          for (final detalle in detalles)
            VentaResumenFila(
              descripcion:
                  '${detalle.nombre} · ${detalle.cantidad} × '
                  '${dineroVenta(detalle.precioUnitario)}',
              importe: dineroVenta(detalle.subtotal),
            ),
          if (descuento > 0)
            VentaResumenFila(
              descripcion: 'Descuento',
              importe: '-${dineroVenta(descuento)}',
            ),
          const SizedBox(height: 18),
          VentaResumenFila(
            descripcion: cotizacion == null
                ? 'Total estimado (MXN)'
                : 'Total (MXN)',
            importe: dineroVenta(total),
            destacado: true,
          ),
        ],
      ),
    );
  }
}

class VentaResumenFila extends StatelessWidget {
  const VentaResumenFila({
    required this.descripcion,
    required this.importe,
    this.destacado = false,
    super.key,
  });

  final String descripcion;
  final String importe;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final estilo = BarroTheme.type(
      14,
      20,
      weight: destacado ? FontWeight.w600 : FontWeight.w400,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(descripcion, style: estilo)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(importe, textAlign: TextAlign.end, style: estilo),
          ),
        ],
      ),
    );
  }
}
