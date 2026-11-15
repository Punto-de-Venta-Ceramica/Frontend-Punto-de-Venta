import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/productos/domain/producto.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_widgets.dart';
import 'package:punto_de_venta/features/tickets/application/impresion_tickets.dart';
import 'package:punto_de_venta/features/tickets/domain/ticket.dart';
import 'package:punto_de_venta/features/tickets/infrastructure/adapters/inbound/imprimir_ticket_widgets.dart';
import 'package:punto_de_venta/features/tickets/infrastructure/adapters/inbound/seleccionar_impresora_dialog.dart';
import 'package:punto_de_venta/features/tickets/infrastructure/adapters/outbound/bluetooth_impresora_tickets.dart';
import 'package:punto_de_venta/features/tickets/infrastructure/adapters/outbound/secure_impresora_preferida.dart';
import '../../../application/gestion_pedidos.dart';
import '../../../application/ticket_pedido.dart';
import '../../../domain/pedido.dart';
import 'package:punto_de_venta/core/infrastructure/widgets/barro_header.dart';
import 'editar_pedido_page.dart';
import 'pedido_input_formatters.dart';
import 'pedido_widgets.dart';

/// Detalle del pedido en pantalla completa, con el mismo estilo que el
/// detalle de producto.
///
/// Consulta GET /api/pedidos/{id}, el único endpoint que devuelve el folio.
/// Desde aquí se registran pagos y el propietario puede cancelar el pedido.
class PedidoDetallePage extends StatefulWidget {
  const PedidoDetallePage({
    required this.gestion,
    required this.pedidoId,
    required this.sucursalId,
    required this.esPropietario,
    required this.negocio,
    this.sucursalNombre,
    this.impresion = const ImpresionTickets(
      BluetoothImpresoraTickets(),
      SecureImpresoraPreferida(),
    ),
    super.key,
  });
  final GestionPedidos gestion;
  final int pedidoId;
  final int sucursalId;
  final bool esPropietario;
  final NegocioProducto negocio;
  final String? sucursalNombre;
  final ImpresionTickets impresion;
  @override
  State<PedidoDetallePage> createState() => _PedidoDetallePageState();
}

class _PedidoDetallePageState extends State<PedidoDetallePage> {
  Pedido? _pedido;
  String? _error;
  String? _mensaje;
  bool _cargando = true;
  bool _busy = false;
  // Sin turno de caja abierto no se cobran pagos ni se devuelve lo pagado.
  bool _cajaAbierta = true;
  bool _imprimiendo = false;
  // Última impresora usada en este dispositivo; null = preguntar.
  ImpresoraTicket? _impresora;

  @override
  void initState() {
    super.initState();
    _cargar();
    widget.impresion.preferida().then((impresora) {
      if (mounted && impresora != null) setState(() => _impresora = impresora);
    });
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final (pedido, cajaAbierta) = await (
        widget.gestion.obtener(widget.pedidoId),
        widget.gestion.cajaAbierta(widget.sucursalId),
      ).wait;
      if (mounted) {
        setState(() {
          _pedido = pedido;
          _cajaAbierta = cajaAbierta;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo cargar el pedido.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _accion(Future<void> Function() operacion, String exito) async {
    setState(() {
      _busy = true;
      _error = null;
      _mensaje = null;
    });
    try {
      await operacion();
      if (!mounted) return;
      await _cargar();
      if (mounted) setState(() => _mensaje = exito);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copiarFolio(String folio) async {
    try {
      await Clipboard.setData(ClipboardData(text: folio));
      if (mounted) setState(() => _mensaje = 'Folio copiado.');
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo copiar el folio.');
    }
  }

  Future<void> _pagar(Pedido pedido) async {
    final monto = TextEditingController();
    String metodo = 'EFECTIVO';
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Nuevo pago'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Saldo pendiente: ${formatoPrecio(pedido.saldo)}'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: metodo,
                decoration: const InputDecoration(labelText: 'Tipo de pago'),
                items: const [
                  DropdownMenuItem(value: 'EFECTIVO', child: Text('Efectivo')),
                  DropdownMenuItem(value: 'TARJETA', child: Text('Tarjeta')),
                ],
                onChanged: (v) => update(() => metodo = v!),
              ),
              TextField(
                controller: monto,
                inputFormatters: PedidoInputFormatters.dinero,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Cantidad pagada',
                  helperText: 'No puede superar el saldo pendiente.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () {
                final valor = double.tryParse(monto.text.replaceAll(',', '.'));
                if (valor == null ||
                    !valor.isFinite ||
                    valor <= 0 ||
                    valor > pedido.saldo ||
                    !RegExp(
                      r'^\d+(?:[.,]\d{1,2})?$',
                    ).hasMatch(monto.text.trim())) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Revisa el importe.')),
                  );
                  return;
                }
                Navigator.pop(context);
                _accion(
                  () => widget.gestion.pagar(pedido.id, valor, metodo),
                  'Pago de ${formatoPrecio(valor)} registrado.',
                );
              },
              child: const Text('Guardar pago'),
            ),
          ],
        ),
      ),
    );
    monto.dispose();
  }

  Future<void> _editar(Pedido pedido) async {
    // La nueva ruta queda fuera del scope de la campana: se le pasa el mismo.
    final campana = BarroHeaderScope.maybeOf(context);
    final pantalla = EditarPedidoPage(
      gestion: widget.gestion,
      pedido: pedido,
      negocio: widget.negocio,
      sucursalNombre: widget.sucursalNombre,
    );
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => campana == null
            ? pantalla
            : BarroHeaderScope(
                onPerfil: campana.onPerfil,
                onNotificaciones: campana.onNotificaciones,
                conteoNotificaciones: campana.conteoNotificaciones,
                child: pantalla,
              ),
      ),
    );
    if (guardado == true && mounted) {
      await _cargar();
      if (mounted) setState(() => _mensaje = 'Datos del pedido actualizados.');
    }
  }

  Future<void> _cancelar(Pedido pedido) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar este pedido?'),
        content: Text(
          'El pedido quedará cancelado y ya no podrá cambiar de estado ni recibir pagos.'
          '${pedido.pagado > 0 ? '\n\nLo pagado (${formatoPrecio(pedido.pagado)}) se descontará del corte de caja de hoy como devolución.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar pedido'),
          ),
        ],
      ),
    );
    if (confirmar == true && mounted) {
      await _accion(
        () => widget.gestion.cancelar(pedido.id),
        'Pedido cancelado.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pedido = _pedido;
    return PopScope(
      canPop: !_busy,
      child: ProductoScaffold(
        rol: widget.esPropietario ? 'Propietario' : 'Empleado',
        onRefresh: _cargar,
        children: [
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: _busy ? null : () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
            ),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Pedidos'),
          ),
          ProductoNegocioPanel(
            negocio: widget.negocio,
            sucursal: widget.sucursalNombre,
          ),
          const SizedBox(height: 16),
          Text(
            'Detalle del pedido',
            style: BarroTheme.type(28, 36, weight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          if (_mensaje != null) ...[
            ProductoAviso(_mensaje!),
            const SizedBox(height: 20),
          ],
          if (_error != null) ...[
            ProductoAviso(_error!, error: true),
            const SizedBox(height: 20),
          ],
          if (pedido == null)
            _cargando
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : Center(
                    child: TextButton(
                      onPressed: _cargar,
                      child: const Text('Reintentar'),
                    ),
                  )
          else ...[
            if (_cargando) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
            ],
            _tarjetaCliente(pedido),
            // Cambio de estado (antes estaba en la tarjeta del listado).
            if (EstadosPedido.progreso.contains(pedido.estado)) ...[
              const SizedBox(height: 16),
              _Tarjeta(
                children: [
                  PedidoEstadoSelector(
                    estado: pedido.estado,
                    esPropietario: widget.esPropietario,
                    habilitado: !_busy,
                    onCambiar: (estado) => _accion(
                      () => widget.gestion.cambiarEstado(pedido.id, estado),
                      'Estado actualizado a ${EstadosPedido.etiqueta(estado).toLowerCase()}.',
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            _titulo('Productos'),
            const SizedBox(height: 12),
            _tarjetaProductos(pedido),
            const SizedBox(height: 24),
            _titulo('Pagos'),
            const SizedBox(height: 12),
            _tarjetaPagos(pedido),
            // Editar, cobrar y cancelar ya no aplican a un pedido cerrado:
            // cancelado o terminado (entregado y pagado).
            if (pedido.estado != 'CANCELADO' &&
                pedido.estado != 'TERMINADO') ...[
              const SizedBox(height: 24),
              // Datos del pedido y del cliente: solo el propietario (HU-05).
              if (widget.esPropietario) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _editar(pedido),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Editar datos del pedido'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BarroTheme.primary,
                      minimumSize: const Size.fromHeight(48),
                      side: const BorderSide(color: BarroTheme.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: BarroTheme.type(
                        14,
                        20,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // Cobrar o devolver mueve dinero: necesita un turno de caja abierto.
              if (!_cajaAbierta &&
                  (pedido.saldo > 0 ||
                      (widget.esPropietario && pedido.pagado > 0))) ...[
                const ProductoAviso(
                  'Caja cerrada: abre un turno de caja para registrar pagos '
                  'o cancelar pedidos con pagos.',
                  error: true,
                ),
                const SizedBox(height: 12),
              ],
              if (pedido.saldo > 0)
                ProductoBoton(
                  texto: 'Registrar pago',
                  // Solo gira con su propia acción, no al imprimir.
                  busy: _busy && !_imprimiendo,
                  onPressed: _busy || !_cajaAbierta
                      ? null
                      : () => _pagar(pedido),
                ),
              if (widget.esPropietario) ...[
                const SizedBox(height: 12),
                ProductoBotonPeligro(
                  texto: 'Cancelar pedido',
                  onPressed: _busy || (!_cajaAbierta && pedido.pagado > 0)
                      ? null
                      : () => _cancelar(pedido),
                ),
              ],
            ],
            // Tickets: solo en pedidos terminados, al final del detalle.
            if (pedido.estado == 'TERMINADO') ...[
              const SizedBox(height: 24),
              _titulo('Ticket'),
              const SizedBox(height: 12),
              TarjetaImprimirTicket(
                impresora: _impresora,
                imprimiendo: _imprimiendo,
                onImprimir: _busy ? null : () => _imprimirTicket(pedido),
                onCambiarImpresora: _busy ? null : _elegirImpresora,
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// Imprime en la impresora guardada; la primera vez pide elegirla.
  Future<void> _imprimirTicket(Pedido pedido) async {
    final impresora = _impresora ?? await _elegirImpresora();
    if (impresora == null || !mounted) return;
    setState(() {
      _busy = true;
      _imprimiendo = true;
    });
    try {
      final ticket = ticketDePedido(
        pedido,
        negocio: widget.negocio.nombre,
        sucursal: widget.sucursalNombre ?? 'Sucursal ${widget.sucursalId}',
        entrega: DateTime.now(),
      );
      await widget.impresion.imprimir(impresora, ticket);
      if (mounted) {
        setState(() => _impresora = impresora);
        avisoImpresion(context, 'Ticket impreso en ${impresora.nombre}.');
      }
    } on ImpresionException catch (e) {
      if (mounted) _falloImpresion(pedido, e.message);
    } catch (_) {
      if (mounted) _falloImpresion(pedido, 'No se pudo imprimir el ticket.');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _imprimiendo = false;
        });
      }
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

  void _falloImpresion(Pedido pedido, String mensaje) => avisoImpresion(
    context,
    mensaje,
    error: true,
    onReintentar: () => _imprimirTicket(pedido),
  );

  Widget _titulo(String texto) =>
      Text(texto, style: BarroTheme.type(18, 26, weight: FontWeight.w700));

  Widget _tarjetaCliente(Pedido pedido) {
    final direccion = [pedido.calle, pedido.colonia, pedido.ciudad]
        .map((parte) => parte.trim())
        .where((parte) => parte.isNotEmpty)
        .join(', ');
    return _Tarjeta(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                pedido.cliente,
                style: BarroTheme.type(22, 30, weight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            PedidoEstadoChip(pedido.estado),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'Folio: ${pedido.folio}',
                style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
              ),
            ),
            IconButton(
              tooltip: 'Copiar folio',
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.copy_outlined,
                size: 18,
                color: BarroTheme.primary,
              ),
              onPressed: () => _copiarFolio(pedido.folio),
            ),
          ],
        ),
        const Divider(height: 24, color: BarroTheme.border),
        _Dato(icono: Icons.phone_outlined, texto: pedido.telefono),
        if (direccion.isNotEmpty)
          _Dato(icono: Icons.place_outlined, texto: direccion),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: PedidoTipoEntrega(pedido.tipoEntrega, tamano: 14),
        ),
        if (pedido.descripcionEnvio.isNotEmpty)
          _Dato(icono: Icons.notes_outlined, texto: pedido.descripcionEnvio),
        if (pedido.descripcion.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: productoSuave,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(pedido.descripcion, style: BarroTheme.type(14, 21)),
          ),
        ],
      ],
    );
  }

  Widget _tarjetaProductos(Pedido pedido) => _Tarjeta(
    children: [
      for (final (i, d) in pedido.productos.indexed) ...[
        if (i > 0) const Divider(height: 24, color: BarroTheme.border),
        // Misma imagen que en el apartado de productos (Cloudinary, con caché).
        ProductoImagen(
          key: ValueKey('pedido-producto-imagen-$i'),
          size: 180,
          ancho: double.infinity,
          url: d.imagenUrl,
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.nombre,
                    style: BarroTheme.type(16, 23, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatoPiezas(d.cantidad),
                    style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
                  ),
                  if (d.porcentajeDescuento > 0) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: productoSuave,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.sell_outlined,
                            size: 14,
                            color: BarroTheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Mayoreo ${d.porcentajeDescuento.toStringAsFixed(2)} %',
                            style: BarroTheme.type(
                              11,
                              16,
                              weight: FontWeight.w700,
                              color: BarroTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              formatoPrecio(d.subtotal),
              style: BarroTheme.type(16, 23, weight: FontWeight.w700),
            ),
          ],
        ),
      ],
    ],
  );

  Widget _tarjetaPagos(Pedido pedido) {
    final liquidado = pedido.saldo == 0;
    return _Tarjeta(
      children: [
        Text(
          'Total',
          style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatoPrecio(pedido.total),
              style: BarroTheme.type(
                30,
                38,
                weight: FontWeight.w700,
                color: BarroTheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'MXN',
                style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
              ),
            ),
          ],
        ),
        const Divider(height: 24, color: BarroTheme.border),
        _Fila('Pagado', formatoPrecio(pedido.pagado)),
        const SizedBox(height: 6),
        _Fila('Saldo pendiente', formatoPrecio(pedido.saldo), fuerte: true),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: liquidado ? const Color(0xFFECF7F0) : productoSuave,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            liquidado ? 'Pagado' : 'Pago pendiente',
            style: BarroTheme.type(
              12,
              18,
              weight: FontWeight.w700,
              color: liquidado ? BarroTheme.success : BarroTheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Contenedor blanco con borde, igual al del detalle de producto.
class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: BarroTheme.border),
      borderRadius: BorderRadius.circular(21),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.texto});
  final IconData icono;
  final String texto;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 18, color: BarroTheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(texto, style: BarroTheme.type(14, 21))),
      ],
    ),
  );
}

class _Fila extends StatelessWidget {
  const _Fila(this.etiqueta, this.valor, {this.fuerte = false});
  final String etiqueta, valor;
  final bool fuerte;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        etiqueta,
        style: BarroTheme.type(14, 21, color: BarroTheme.secondary),
      ),
      Text(
        valor,
        style: BarroTheme.type(
          fuerte ? 16 : 14,
          fuerte ? 23 : 21,
          weight: fuerte ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    ],
  );
}
