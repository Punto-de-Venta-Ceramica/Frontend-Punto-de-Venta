import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/core/infrastructure/services/notificacion_servicio.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/productos/domain/producto.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_widgets.dart';
import 'package:punto_de_venta/features/tickets/application/impresion_tickets.dart';
import 'package:punto_de_venta/features/tickets/infrastructure/adapters/inbound/seccion_imprimir_ticket.dart';
import 'package:punto_de_venta/features/tickets/infrastructure/impresion_tickets_bluetooth.dart';
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
    this.impresion = impresionTicketsBluetooth,
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
  bool _cargando = true;
  bool _busy = false;
  // Sin turno de caja abierto no se cobran pagos ni se devuelve lo pagado.
  bool _cajaAbierta = true;
  bool _imprimiendo = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  /// Si lo que se ve llegó del servidor en esta pantalla (no es lo guardado).
  bool _fresco = false;

  /// Mientras carga, lo que se ve puede ser lo guardado (atrasado): cobrar,
  /// cancelar, editar o cambiar el estado esperan a la versión fresca. Si la
  /// consulta falla, siguen deshabilitados hasta que se recargue (deslizando).
  bool get _bloqueado => _busy || _cargando || !_fresco;

  Future<void> _cargar() async {
    setState(() {
      // Se muestra al instante el último detalle recibido; la consulta lo
      // reemplaza en cuanto llega.
      _pedido ??= widget.gestion.pedidoGuardado(widget.pedidoId);
      // Hasta que esta carga termine bien, lo que se ve puede estar
      // atrasado (p. ej. tras registrar un pago que aún no se refleja).
      _fresco = false;
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
          _fresco = true;
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
    });
    try {
      await operacion();
      if (!mounted) return;
      await _cargar();
      if (mounted) NotificacionServicio.exito(context, exito);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copiarFolio(String folio) async {
    try {
      await Clipboard.setData(ClipboardData(text: folio));
      if (mounted) NotificacionServicio.info(context, 'Folio copiado.');
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo copiar el folio.');
    }
  }

  Future<void> _pagar(Pedido pedido) async {
    final monto = TextEditingController();
    String metodo = 'EFECTIVO';
    String? error;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          void guardar() {
            final valor = double.tryParse(monto.text.replaceAll(',', '.'));
            if (valor == null ||
                !valor.isFinite ||
                valor <= 0 ||
                valor > pedido.saldo ||
                !RegExp(r'^\d+(?:[.,]\d{1,2})?$').hasMatch(monto.text.trim())) {
              update(
                () => error = valor != null && valor > pedido.saldo
                    ? 'No puede superar el saldo pendiente.'
                    : 'Escribe un importe mayor a \$0 con hasta dos decimales.',
              );
              return;
            }
            Navigator.pop(context);
            _accion(
              () => widget.gestion.pagar(pedido.id, valor, metodo),
              'Pago de ${formatoPrecio(valor)} registrado.',
            );
          }

          Widget opcion(String valor, String texto, IconData icono) {
            final elegido = metodo == valor;
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => update(() => metodo = valor),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: elegido ? productoSuave : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: elegido ? BarroTheme.primary : BarroTheme.border,
                      width: elegido ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        icono,
                        color: elegido
                            ? BarroTheme.primary
                            : BarroTheme.secondary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        texto,
                        style: BarroTheme.type(
                          13,
                          18,
                          weight: elegido ? FontWeight.w700 : FontWeight.w500,
                          color: elegido ? BarroTheme.primary : BarroTheme.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: productoSuave,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.payments_outlined,
                            color: BarroTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Registrar pago',
                                style: BarroTheme.type(
                                  20,
                                  28,
                                  weight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                pedido.cliente,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: BarroTheme.type(
                                  13,
                                  18,
                                  color: BarroTheme.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: BarroTheme.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: BarroTheme.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Saldo pendiente',
                              style: BarroTheme.type(
                                13,
                                18,
                                color: BarroTheme.secondary,
                              ),
                            ),
                          ),
                          Text(
                            formatoPrecio(pedido.saldo),
                            style: BarroTheme.type(
                              20,
                              26,
                              weight: FontWeight.w700,
                              color: BarroTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const ProductoEtiqueta('Método de pago'),
                    Row(
                      children: [
                        opcion('EFECTIVO', 'Efectivo', Icons.payments_outlined),
                        const SizedBox(width: 10),
                        opcion('TARJETA', 'Tarjeta', Icons.credit_card),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(
                          child: ProductoEtiqueta('Cantidad pagada'),
                        ),
                        TextButton(
                          onPressed: () => update(() {
                            monto.text = pedido.saldo.toStringAsFixed(2);
                            error = null;
                          }),
                          child: const Text('Liquidar saldo'),
                        ),
                      ],
                    ),
                    TextField(
                      controller: monto,
                      autofocus: true,
                      inputFormatters: PedidoInputFormatters.dinero,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) {
                        if (error != null) update(() => error = null);
                      },
                      onSubmitted: (_) => guardar(),
                      style: BarroTheme.type(18, 24, weight: FontWeight.w700),
                      decoration: productoDecoracion(hint: '0.00', error: error)
                          .copyWith(
                            prefixIcon: const Icon(
                              Icons.attach_money,
                              color: BarroTheme.secondary,
                            ),
                            helperText: error == null
                                ? 'No puede superar el saldo pendiente.'
                                : null,
                          ),
                    ),
                    const SizedBox(height: 20),
                    ProductoBoton(texto: 'Guardar pago', onPressed: guardar),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Volver'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
      if (mounted) {
        NotificacionServicio.actualizacion(
          context,
          'Datos del pedido actualizados.',
        );
      }
    }
  }

  Future<void> _cancelar(Pedido pedido) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => _CancelarPedidoDialog(pagado: pedido.pagado),
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
                    habilitado: !_bloqueado,
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
                    onPressed: _bloqueado ? null : () => _editar(pedido),
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
                  onPressed: _bloqueado || !_cajaAbierta
                      ? null
                      : () => _pagar(pedido),
                ),
              if (widget.esPropietario) ...[
                const SizedBox(height: 12),
                ProductoBotonPeligro(
                  texto: 'Cancelar pedido',
                  onPressed: _bloqueado || (!_cajaAbierta && pedido.pagado > 0)
                      ? null
                      : () => _cancelar(pedido),
                ),
              ],
            ],
            // Comprobante de lo pagado mientras el pedido sigue en curso (el
            // mismo que se ofrece al registrarlo con anticipo).
            if (pedido.pagado > 0 &&
                pedido.estado != 'TERMINADO' &&
                pedido.estado != 'CANCELADO') ...[
              const SizedBox(height: 24),
              _titulo('Comprobante de pago'),
              const SizedBox(height: 12),
              SeccionImprimirTicket(
                impresion: widget.impresion,
                habilitado: !_busy || _imprimiendo,
                onImprimiendo: (imprimiendo) => setState(() {
                  _busy = imprimiendo;
                  _imprimiendo = imprimiendo;
                }),
                ticket: () => ticketDeComprobante(
                  pedido,
                  negocio: widget.negocio.nombre,
                  sucursal:
                      widget.sucursalNombre ?? 'Sucursal ${widget.sucursalId}',
                  fecha: DateTime.now(),
                ),
              ),
            ],
            // Tickets: solo en pedidos terminados, al final del detalle.
            if (pedido.estado == 'TERMINADO') ...[
              const SizedBox(height: 24),
              _titulo('Ticket'),
              const SizedBox(height: 12),
              SeccionImprimirTicket(
                impresion: widget.impresion,
                habilitado: !_busy || _imprimiendo,
                onImprimiendo: (imprimiendo) => setState(() {
                  _busy = imprimiendo;
                  _imprimiendo = imprimiendo;
                }),
                ticket: () => ticketDePedido(
                  pedido,
                  negocio: widget.negocio.nombre,
                  sucursal:
                      widget.sucursalNombre ?? 'Sucursal ${widget.sucursalId}',
                  entrega: DateTime.now(),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

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
              child: _Dato(
                icono: Icons.person_outline,
                etiqueta: 'Nombre del cliente',
                texto: pedido.cliente,
              ),
            ),
            const SizedBox(width: 12),
            PedidoEstadoChip(pedido.estado),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _Dato(
                icono: Icons.tag,
                etiqueta: 'Folio',
                texto: pedido.folio,
                abajo: 0,
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
        _Dato(
          icono: Icons.phone_outlined,
          etiqueta: 'Teléfono del cliente',
          texto: pedido.telefono,
        ),
        if (direccion.isNotEmpty)
          _Dato(
            icono: Icons.place_outlined,
            etiqueta: 'Dirección de entrega',
            texto: direccion,
          ),
        if (pedido.fechaEntrega != null)
          _Dato(
            icono: Icons.event_outlined,
            etiqueta:
                pedido.estado == 'ENTREGADO' || pedido.estado == 'TERMINADO'
                ? 'Entregado el'
                : 'Fecha de entrega',
            texto:
                '${pedido.fechaEntrega!.day.toString().padLeft(2, '0')}/'
                '${pedido.fechaEntrega!.month.toString().padLeft(2, '0')}/'
                '${pedido.fechaEntrega!.year}',
          ),
        if (pedido.descripcionEnvio.isNotEmpty)
          _Dato(
            icono: Icons.notes_outlined,
            etiqueta: 'Indicaciones de entrega',
            texto: pedido.descripcionEnvio,
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: PedidoTipoEntrega(
            pedido.tipoEntrega,
            tamano: 14,
            destacarEtiqueta: true,
          ),
        ),
        if (pedido.descripcion.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Descripción del pedido',
            style: BarroTheme.type(14, 21, weight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
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
        // Mismo recuadro que la tarjeta del listado de productos: la foto se
        // ve completa y, si su forma no encaja, sobre un fondo difuminado.
        ProductoImagen(
          key: ValueKey('pedido-producto-imagen-$i'),
          size: 180,
          proporcion: 4 / 3,
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
  const _Dato({
    required this.icono,
    required this.etiqueta,
    required this.texto,
    this.abajo = 8,
  });
  final IconData icono;

  /// Breve descripción del dato (p. ej. "Teléfono del cliente"), en negritas;
  /// el valor va en texto normal.
  final String etiqueta;
  final String texto;
  final double abajo;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: abajo),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 18, color: BarroTheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$etiqueta: ',
                  style: BarroTheme.type(14, 21, weight: FontWeight.w700),
                ),
                TextSpan(
                  text: texto,
                  style: BarroTheme.type(14, 21, color: BarroTheme.secondary),
                ),
              ],
            ),
          ),
        ),
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

/// Confirma la cancelación; se cierra con `true` si el usuario la acepta.
class _CancelarPedidoDialog extends StatelessWidget {
  const _CancelarPedidoDialog({required this.pagado});
  final double pagado;

  static const _rojoSuave = Color(0xFFFDECEA);

  Widget _consecuencia(IconData icono, String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 18, color: BarroTheme.secondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            texto,
            style: BarroTheme.type(13, 19, color: BarroTheme.secondary),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: BarroTheme.background,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _rojoSuave,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFF6C9C4), width: 6),
                ),
                child: const Icon(
                  Icons.event_busy_rounded,
                  size: 32,
                  color: BarroTheme.error,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '¿Cancelar este pedido?',
              textAlign: TextAlign.center,
              style: BarroTheme.type(21, 27, weight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Esta acción no se puede deshacer.',
              textAlign: TextAlign.center,
              style: BarroTheme.type(13, 19, color: BarroTheme.placeholder),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: BarroTheme.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _consecuencia(
                    Icons.block_rounded,
                    'El pedido quedará cancelado y ya no podrá cambiar de estado.',
                  ),
                  _consecuencia(
                    Icons.money_off_rounded,
                    'No podrá recibir más pagos.',
                  ),
                ],
              ),
            ),
            if (pagado > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6E5),
                  border: Border.all(color: const Color(0xFFF2D59B)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.currency_exchange_rounded,
                      size: 20,
                      color: Color(0xFF9A6200),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: BarroTheme.type(
                            13,
                            19,
                            color: const Color(0xFF6B4500),
                          ),
                          children: [
                            const TextSpan(text: 'Lo pagado ('),
                            TextSpan(
                              text: formatoPrecio(pagado),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(
                              text:
                                  ') se descontará del corte de caja de hoy como devolución.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            FilledButton.icon(
              key: const ValueKey('pedido-cancelar-confirmar'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: BarroTheme.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.cancel_outlined, size: 20),
              label: const Text('Cancelar pedido'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: BarroTheme.secondary,
                side: const BorderSide(color: BarroTheme.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.pop(context, false),
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              label: const Text('Volver'),
            ),
          ],
        ),
      ),
    ),
  );
}
