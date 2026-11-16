import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_widgets.dart'
    show productoSuave;
import 'package:punto_de_venta/features/tickets/application/impresion_tickets.dart';
import 'package:punto_de_venta/features/tickets/infrastructure/adapters/inbound/seccion_imprimir_ticket.dart';
import 'package:punto_de_venta/features/tickets/infrastructure/impresion_tickets_bluetooth.dart';
import 'package:uuid/uuid.dart';

import '../../../../application/services/gestion_ventas.dart';
import '../../../../application/ticket_venta.dart';
import '../../../../domain/venta.dart';
import 'ventas_widgets.dart';

class ConfirmarVentaPage extends StatefulWidget {
  const ConfirmarVentaPage({
    required this.contexto,
    required this.gestion,
    required this.sucursalId,
    required this.productos,
    required this.onSesionExpirada,
    this.impresion = impresionTicketsBluetooth,
    super.key,
  });

  final VentaContexto contexto;
  final GestionVentas gestion;
  final int sucursalId;
  final List<SeleccionVenta> productos;
  final VoidCallback onSesionExpirada;
  final ImpresionTickets impresion;

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
  bool _consultandoSalida = false;
  bool _imprimiendo = false;

  /// Venta confirmada, con la cotización y la hora con que se registró; se
  /// conserva para imprimir (o reimprimir) su ticket.
  ({VentaRegistrada venta, CotizacionVenta cotizacion, DateTime fecha})?
  _registro;

  bool get _ventaRegistrada => _registro != null;
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
        _intento = null;
        _registro = (
          venta: venta,
          cotizacion: cotizacion,
          fecha: DateTime.now(),
        );
      });
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

  /// Sale de la venta ya registrada y la devuelve a quien abrió el registro
  /// (para refrescar inventario y avisar del cobro).
  void _terminar() {
    final registro = _registro;
    if (registro == null || _imprimiendo) return;
    Navigator.of(context).pop(registro.venta);
  }

  /// Escribe un monto sugerido en el campo de efectivo.
  void _usarMonto(num monto) {
    final texto = monto == monto.roundToDouble()
        ? monto.toInt().toString()
        : monto.toStringAsFixed(2);
    _efectivo.value = TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
    setState(() => _errorMonto = null);
  }

  @override
  Widget build(BuildContext context) {
    final metodo = _metodo;
    final cotizacion = _cotizacion;
    final registro = _registro;
    final ocupado = _guardando || _ventaRegistrada;
    final bloqueado = ocupado || _resultadoIncierto;
    final monto = _montoRecibido;
    final cambio =
        monto != null && cotizacion != null && monto >= cotizacion.total
        ? monto - cotizacion.total
        : null;

    return PopScope<VentaRegistrada>(
      canPop: !bloqueado,
      onPopInvokedWithResult: (salio, _) {
        if (salio) return;
        if (_ventaRegistrada) {
          _terminar();
        } else if (_resultadoIncierto) {
          _cancelar();
        }
      },
      child: VentaScaffold(
        contexto: widget.contexto,
        paso: registro == null
            ? '2 de 2 · Confirma los productos y el pago.'
            : 'Venta ${registro.venta.folio} registrada.',
        accion: switch ((registro, _resultadoIncierto)) {
          (_?, _) => 'Venta registrada',
          (null, true) => 'Reintentar confirmación',
          (null, false) => 'Registrar venta',
        },
        iconoAccion: switch ((registro, _resultadoIncierto)) {
          (_?, _) => Icons.check_circle_rounded,
          (null, true) => Icons.refresh_rounded,
          (null, false) => Icons.point_of_sale_rounded,
        },
        procesando: _guardando,
        onAccion: cotizacion != null && metodo != null && !ocupado
            ? _confirmar
            : null,
        debajoAccion: registro == null
            ? null
            : SeccionImprimirTicket(
                impresion: widget.impresion,
                onImprimiendo: (valor) => setState(() => _imprimiendo = valor),
                ticket: () => ticketDeVenta(
                  registro.venta,
                  registro.cotizacion,
                  productos: widget.productos,
                  negocio: widget.contexto.negocio,
                  sucursal: widget.contexto.sucursal,
                  fecha: registro.fecha,
                ),
              ),
        textoCancelar: registro == null ? 'Cancelar' : 'Terminar',
        onCancelar: registro != null
            ? (_imprimiendo ? null : _terminar)
            : (ocupado ? null : _cancelar),
        children: [
          _resumen(cotizacion),
          const SizedBox(height: 28),
          VentaCampo(
            etiqueta: 'Método de pago *',
            child: Row(
              children: [
                for (final opcion in MetodoPagoVenta.values) ...[
                  if (opcion != MetodoPagoVenta.values.first)
                    const SizedBox(width: 12),
                  Expanded(
                    child: _OpcionPago(
                      metodo: opcion,
                      seleccionado: metodo == opcion,
                      onTap: bloqueado
                          ? null
                          : () => setState(() {
                              _metodo = opcion;
                              _errorMonto = null;
                            }),
                    ),
                  ),
                ],
              ],
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
                decoration:
                    decoracionCampoVenta(
                      indicacion: 'Ingresa el monto recibido',
                      error: _errorMonto,
                    ).copyWith(
                      prefixIcon: const Icon(
                        Icons.payments_outlined,
                        color: BarroTheme.primary,
                      ),
                    ),
                onChanged: (_) => setState(() => _errorMonto = null),
              ),
            ),
            if (cotizacion != null && !bloqueado) ...[
              const SizedBox(height: 10),
              _MontosRapidos(total: cotizacion.total, onElegir: _usarMonto),
            ],
            const SizedBox(height: 14),
            _Cambio(cambio),
          ] else if (metodo == MetodoPagoVenta.tarjeta) ...[
            const SizedBox(height: 14),
            const _Indicacion(
              icono: Icons.contactless_outlined,
              texto: 'Cobra el total con la terminal antes de registrar.',
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
    final piezas = detalles.fold(0, (suma, detalle) => suma + detalle.cantidad);

    return VentaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _IconoCirculo(Icons.receipt_long_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Productos seleccionados',
                  style: BarroTheme.type(16, 22, weight: FontWeight.w700),
                ),
              ),
              Text(
                piezas == 1 ? '1 pieza' : '$piezas piezas',
                style: BarroTheme.type(12, 17, color: BarroTheme.secondary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final detalle in detalles) _LineaProducto(detalle),
          const Divider(height: 20, color: BarroTheme.border),
          if (descuento > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_offer_outlined,
                    size: 18,
                    color: BarroTheme.success,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Descuento',
                      style: BarroTheme.type(
                        14,
                        20,
                        weight: FontWeight.w600,
                        color: BarroTheme.success,
                      ),
                    ),
                  ),
                  Text(
                    '-${dineroVenta(descuento)}',
                    style: BarroTheme.type(
                      14,
                      20,
                      weight: FontWeight.w600,
                      color: BarroTheme.success,
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: productoSuave,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    cotizacion == null ? 'Total estimado (MXN)' : 'Total (MXN)',
                    style: BarroTheme.type(14, 20, weight: FontWeight.w600),
                  ),
                ),
                Text(
                  dineroVenta(total),
                  style: BarroTheme.type(
                    22,
                    28,
                    weight: FontWeight.w800,
                    color: BarroTheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconoCirculo extends StatelessWidget {
  const _IconoCirculo(this.icono);
  final IconData icono;

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    decoration: const BoxDecoration(
      color: productoSuave,
      shape: BoxShape.circle,
    ),
    child: Icon(icono, size: 20, color: BarroTheme.primary),
  );
}

class _LineaProducto extends StatelessWidget {
  const _LineaProducto(this.detalle);
  final DetalleVenta detalle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 36),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: BarroTheme.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${detalle.cantidad}×',
            textAlign: TextAlign.center,
            style: BarroTheme.type(13, 18, weight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detalle.nombre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: BarroTheme.type(14, 20, weight: FontWeight.w600),
              ),
              Text(
                '${dineroVenta(detalle.precioUnitario)} c/u',
                style: BarroTheme.type(12, 17, color: BarroTheme.secondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          dineroVenta(detalle.subtotal),
          style: BarroTheme.type(14, 20, weight: FontWeight.w600),
        ),
      ],
    ),
  );
}

/// Tarjeta seleccionable con el ícono y el nombre del método de pago.
class _OpcionPago extends StatelessWidget {
  const _OpcionPago({
    required this.metodo,
    required this.seleccionado,
    required this.onTap,
  });

  final MetodoPagoVenta metodo;
  final bool seleccionado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = seleccionado ? BarroTheme.primary : BarroTheme.secondary;
    return Semantics(
      button: true,
      selected: seleccionado,
      child: Material(
        color: seleccionado ? productoSuave : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: seleccionado ? BarroTheme.primary : BarroTheme.border,
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                Icon(switch (metodo) {
                  MetodoPagoVenta.efectivo => Icons.payments_outlined,
                  MetodoPagoVenta.tarjeta => Icons.credit_card_rounded,
                }, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    metodo.etiqueta,
                    style: BarroTheme.type(
                      15,
                      21,
                      weight: FontWeight.w600,
                      color: seleccionado ? BarroTheme.text : color,
                    ),
                  ),
                ),
                Icon(
                  seleccionado
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: 20,
                  color: seleccionado ? BarroTheme.primary : BarroTheme.border,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Atajos para el efectivo recibido: el monto exacto y los billetes que lo
/// cubren.
class _MontosRapidos extends StatelessWidget {
  const _MontosRapidos({required this.total, required this.onElegir});

  final num total;
  final ValueChanged<num> onElegir;

  static const _billetes = [20, 50, 100, 200, 500, 1000];

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      ActionChip(
        avatar: const Icon(Icons.done_all_rounded, size: 18),
        label: const Text('Exacto'),
        onPressed: () => onElegir(total),
      ),
      for (final billete in _billetes.where((b) => b > total).take(3))
        ActionChip(
          label: Text('\$$billete'),
          onPressed: () => onElegir(billete),
        ),
    ],
  );
}

/// Cambio que se debe entregar; resaltado en verde cuando el efectivo alcanza.
class _Cambio extends StatelessWidget {
  const _Cambio(this.cambio);
  final num? cambio;

  @override
  Widget build(BuildContext context) {
    final valor = cambio;
    final color = valor == null ? BarroTheme.secondary : BarroTheme.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: valor == null ? Colors.white : const Color(0xFFECF7F0),
        border: Border.all(
          color: valor == null ? BarroTheme.border : const Color(0xFFB9DEC8),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.currency_exchange_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cambio a entregar',
              style: BarroTheme.type(14, 20, weight: FontWeight.w600),
            ),
          ),
          Text(
            valor == null ? '—' : dineroVenta(valor),
            style: BarroTheme.type(
              20,
              26,
              weight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _Indicacion extends StatelessWidget {
  const _Indicacion({required this.icono, required this.texto});
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icono, size: 20, color: BarroTheme.secondary),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          texto,
          style: BarroTheme.type(13, 19, color: BarroTheme.secondary),
        ),
      ),
    ],
  );
}
