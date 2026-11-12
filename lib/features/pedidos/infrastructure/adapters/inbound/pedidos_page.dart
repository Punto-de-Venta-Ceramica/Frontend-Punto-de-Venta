import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/productos/domain/producto.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_widgets.dart';
import '../../../application/gestion_pedidos.dart';
import '../../../domain/pedido.dart';
import 'pedido_input_formatters.dart';
import 'registrar_pedido_page.dart';
import 'package:punto_de_venta/features/sucursal/infrastructure/adapters/inbound/flutter/sucursal_widgets.dart';
import 'notificaciones_page.dart';
import 'package:punto_de_venta/features/notificaciones/application/contador_notificaciones.dart';
import 'package:punto_de_venta/features/notificaciones/infrastructure/boton_notificaciones.dart';

class PedidosPage extends StatefulWidget {
  const PedidosPage({
    required this.gestion,
    required this.sucursalId,
    required this.negocio,
    required this.esPropietario,
    required this.contador,
    this.onInventario,
<<<<<<< Updated upstream
    this.sucursalNombre,
=======
    this.onCaja,
>>>>>>> Stashed changes
    super.key,
  });
  final GestionPedidos gestion;
  final int sucursalId;
  final String? sucursalNombre;
  final NegocioProducto negocio;
  final bool esPropietario;
  final ContadorNotificaciones contador;
  final VoidCallback? onInventario;
  final VoidCallback? onCaja;
  @override
  State<PedidosPage> createState() => _PedidosPageState();
}

class _PedidosPageState extends State<PedidosPage> {
  List<Pedido> _pedidos = [];
  bool _cargando = true;
  String? _error;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final pedidos = await widget.gestion.listar(widget.sucursalId);
      if (mounted) setState(() => _pedidos = pedidos);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudieron cargar los pedidos.');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _nuevo() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RegistrarPedidoPage(
          gestion: widget.gestion,
          sucursalId: widget.sucursalId,
          negocio: widget.negocio,
          esPropietario: widget.esPropietario,
          sucursalNombre: widget.sucursalNombre,
        ),
      ),
    );
    if (mounted) await _cargar();
  }

  Future<void> _accion(Future<void> Function() operacion) async {
    try {
      await operacion();
      if (mounted) await _cargar();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _detalle(Pedido pedido) async {
    String? mensajeCopia;
    final direccion = [pedido.calle, pedido.colonia, pedido.ciudad]
        .map((parte) => parte.trim())
        .where((parte) => parte.isNotEmpty)
        .join(', ');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, actualizar) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detalle del pedido',
                  style: BarroTheme.type(24, 32, weight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Text('Folio: ${pedido.folio}')),
                    IconButton(
                      tooltip: 'Copiar folio',
                      icon: const Icon(Icons.copy_outlined),
                      onPressed: () async {
                        try {
                          await Clipboard.setData(
                            ClipboardData(text: pedido.folio),
                          );
                          if (context.mounted) {
                            actualizar(() => mensajeCopia = 'Folio copiado');
                          }
                        } catch (_) {
                          if (context.mounted) {
                            actualizar(
                              () =>
                                  mensajeCopia = 'No se pudo copiar el folio.',
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
                if (mensajeCopia != null) Text(mensajeCopia!),
                Text('Cliente: ${pedido.cliente} · ${pedido.telefono}'),
                if (direccion.isNotEmpty) Text('Dirección: $direccion'),
                Text('Entrega: ${pedido.tipoEntrega}'),
                if (pedido.descripcion.isNotEmpty) Text(pedido.descripcion),
                const SizedBox(height: 12),
                for (final d in pedido.productos)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${d.cantidad} × ${d.nombre} · ${formatoPrecio(d.subtotal)}',
                      ),
                      if (d.porcentajeDescuento > 0)
                        Text(
                          'Descuento de mayoreo: ${d.porcentajeDescuento.toStringAsFixed(2)} %',
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
                Text(
                  'Total: ${formatoPrecio(pedido.total)} · Saldo: ${formatoPrecio(pedido.saldo)}',
                ),
                Text(pedido.saldo == 0 ? 'Pagado' : 'Pago pendiente'),
                if (pedido.saldo > 0 && pedido.estado != 'CANCELADO') ...[
                  const SizedBox(height: 16),
                  ProductoBoton(
                    texto: 'Registrar pago',
                    onPressed: () {
                      Navigator.pop(context);
                      _pagar(pedido);
                    },
                  ),
                ],
                if (widget.esPropietario && pedido.estado != 'CANCELADO')
                  TextButton(
                    onPressed: () async {
                      final confirmar = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Cancelar pedido'),
                          content: const Text('¿Deseas cancelar este pedido?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Volver'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Cancelar pedido'),
                            ),
                          ],
                        ),
                      );
                      if (confirmar == true && context.mounted) {
                        Navigator.pop(context);
                        await _accion(() => widget.gestion.cancelar(pedido.id));
                      }
                    },
                    child: const Text('Cancelar pedido'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pagar(Pedido pedido) async {
    if (!mounted) return;
    final monto = TextEditingController();
    String metodo = 'EFECTIVO';
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Nuevo pago'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Saldo pendiente: ${formatoPrecio(pedido.saldo)}'),
              DropdownButtonFormField<String>(
                initialValue: metodo,
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
                decoration: const InputDecoration(labelText: 'Cantidad pagada'),
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
                _accion(() => widget.gestion.pagar(pedido.id, valor, metodo));
              },
              child: const Text('Guardar pago'),
            ),
          ],
        ),
      ),
    );
    monto.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibles = _pedidos
        .where(
          (p) => '${p.folio} ${p.cliente}'.toLowerCase().contains(
            _busqueda.toLowerCase(),
          ),
        )
        .toList();
    return ProductoScaffold(
      barraInferior: SucursalNavegacion(
        seleccionada: 'Pedidos',
        onInicio: () => Navigator.of(context).maybePop(),
        onPedidos: () {},
        onInventario: widget.onInventario,
        onCaja: widget.onCaja,
      ),
      rol: widget.esPropietario ? 'Propietario' : 'Empleado',
      onRefresh: _cargar,
      children: [
        const SizedBox(height: 20),
        ProductoNegocioPanel(
          negocio: widget.negocio,
          sucursal: widget.sucursalNombre,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                'Pedidos',
                style: BarroTheme.type(28, 36, weight: FontWeight.w700),
              ),
            ),
            BotonNotificaciones(
              conteo: widget.contador,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => NotificacionesPage(
                    gestion: widget.gestion,
                    contador: widget.contador,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: productoDecoracion(hint: 'Buscar pedido o cliente...'),
          onChanged: (v) => setState(() => _busqueda = v),
        ),
        const SizedBox(height: 14),
        ProductoBoton(texto: '+ Nuevo pedido', onPressed: _nuevo),
        const SizedBox(height: 20),
        if (_cargando)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          ProductoAviso(_error!, error: true)
        else if (visibles.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('No hay pedidos para mostrar.'),
            ),
          )
        else
          for (final p in visibles)
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.folio,
                            style: BarroTheme.type(
                              16,
                              22,
                              weight: FontWeight.w700,
                              color: BarroTheme.primary,
                            ),
                          ),
                        ),
                        Text(p.estado),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      p.cliente,
                      style: BarroTheme.type(16, 22, weight: FontWeight.w700),
                    ),
                    for (final d in p.productos)
                      Text('${d.cantidad} × ${d.nombre}'),
                    Text(
                      'Total: ${formatoPrecio(p.total)}   Saldo: ${formatoPrecio(p.saldo)}',
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => _detalle(p),
                          child: const Text('Ver detalle'),
                        ),
                        if ((p.estado == 'ENCARGADO' && widget.esPropietario) ||
                            p.estado == 'PRODUCCION' ||
                            p.estado == 'ENTREGADO')
                          PopupMenuButton<String>(
                            onSelected: (estado) => _accion(
                              () => widget.gestion.cambiarEstado(p.id, estado),
                            ),
                            itemBuilder: (_) => [
                              if (p.estado == 'ENCARGADO' &&
                                  widget.esPropietario)
                                const PopupMenuItem(
                                  value: 'PRODUCCION',
                                  child: Text('En producción'),
                                ),
                              if (p.estado == 'PRODUCCION')
                                const PopupMenuItem(
                                  value: 'ENTREGADO',
                                  child: Text('Entregado'),
                                ),
                              if (p.estado == 'ENTREGADO')
                                const PopupMenuItem(
                                  value: 'TERMINADO',
                                  child: Text('Terminado'),
                                ),
                            ],
                            child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('Actualizar estado'),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
