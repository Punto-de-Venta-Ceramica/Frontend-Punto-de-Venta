import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/productos/domain/producto.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_widgets.dart';
import '../../../application/gestion_pedidos.dart';
import '../../../domain/pedido.dart';
import 'pedido_detalle_page.dart';
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
    this.sucursalNombre,
    this.onCaja,
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
  List<ResumenPedido> _pedidos = [];
  bool _cargando = true;
  bool _cargandoMas = false;
  String? _error;
  String _busqueda = '';

  /// Estado filtrado en el servidor; null = todos.
  String? _estado = EstadosPedido.porDefecto;
  int _pagina = 0;
  bool _ultima = true;
  int _total = 0;

  /// Descarta respuestas de una carga anterior (p. ej. al cambiar de filtro rápido).
  int _carga = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  /// Carga la primera página del filtro actual.
  Future<void> _cargar() async {
    final carga = ++_carga;
    setState(() {
      _cargando = true;
      _cargandoMas = false;
      _error = null;
    });
    try {
      final pagina = await widget.gestion.listar(
        widget.sucursalId,
        estado: _estado,
      );
      if (!mounted || carga != _carga) return;
      setState(() {
        _pedidos = pagina.pedidos;
        _pagina = pagina.pagina;
        _ultima = pagina.ultima;
        _total = pagina.total;
      });
    } on ApiException catch (e) {
      if (mounted && carga == _carga) setState(() => _error = e.message);
    } catch (_) {
      if (mounted && carga == _carga) {
        setState(() => _error = 'No se pudieron cargar los pedidos.');
      }
    } finally {
      if (mounted && carga == _carga) setState(() => _cargando = false);
    }
  }

  /// Agrega la siguiente página de 20 al final de la lista.
  Future<void> _masPedidos() async {
    if (_cargando || _cargandoMas || _ultima) return;
    final carga = _carga;
    setState(() => _cargandoMas = true);
    try {
      final pagina = await widget.gestion.listar(
        widget.sucursalId,
        estado: _estado,
        pagina: _pagina + 1,
      );
      if (!mounted || carga != _carga) return;
      // Si entraron pedidos nuevos entre páginas, evita repetir los ya mostrados.
      final mostrados = {for (final p in _pedidos) p.id};
      setState(() {
        _pedidos = [
          ..._pedidos,
          ...pagina.pedidos.where((p) => !mostrados.contains(p.id)),
        ];
        _pagina = pagina.pagina;
        _ultima = pagina.ultima;
        _total = pagina.total;
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted && carga == _carga) setState(() => _cargandoMas = false);
    }
  }

  void _filtrar(String? estado) {
    if (estado == _estado) return;
    setState(() => _estado = estado);
    _cargar();
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

  Future<void> _detalle(ResumenPedido pedido) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PedidoDetallePage(
          gestion: widget.gestion,
          pedidoId: pedido.id,
          sucursalId: widget.sucursalId,
          esPropietario: widget.esPropietario,
          negocio: widget.negocio,
          sucursalNombre: widget.sucursalNombre,
        ),
      ),
    );
    // Pudo registrarse un pago o cancelarse el pedido.
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

  Widget _filtros() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final estado in <String?>[...EstadosPedido.todos, null])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                estado == null ? 'Todos' : EstadosPedido.etiqueta(estado),
              ),
              selected: _estado == estado,
              onSelected: (_) => _filtrar(estado),
            ),
          ),
      ],
    ),
  );

  Widget _tarjeta(ResumenPedido p) => Card(
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
                  p.cliente,
                  style: BarroTheme.type(
                    16,
                    22,
                    weight: FontWeight.w700,
                    color: BarroTheme.primary,
                  ),
                ),
              ),
              Text(EstadosPedido.etiqueta(p.estado)),
            ],
          ),
          const SizedBox(height: 8),
          for (final d in p.productos) Text('${d.cantidad} × ${d.nombre}'),
          Text(
            'Total: ${formatoPrecio(p.total)}   Saldo: ${formatoPrecio(p.saldo)}',
          ),
          const SizedBox(height: 12),
          _estadoPedido(p),
          const SizedBox(height: 12),
          // Wrap: en pantallas angostas el botón de terminar baja de renglón.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () => _detalle(p),
                child: const Text('Ver detalle'),
              ),
              if (p.estado == 'ENTREGADO')
                FilledButton.icon(
                  onPressed: () => _terminar(p),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Terminar pedido'),
                ),
            ],
          ),
        ],
      ),
    ),
  );

  /// Selector de estado: muestra el actual y solo habilita el siguiente paso
  /// permitido para el rol. Terminado y cancelado no se editan aquí.
  Widget _estadoPedido(ResumenPedido p) {
    if (!EstadosPedido.progreso.contains(p.estado)) {
      return Text('Estado: ${EstadosPedido.etiqueta(p.estado)}');
    }
    bool habilitado(String destino) => EstadosPedido.puedeCambiar(
      p.estado,
      destino,
      esPropietario: widget.esPropietario,
    );
    final editable = EstadosPedido.progreso.any(habilitado);
    return DropdownButtonFormField<String>(
      key: ValueKey('estado-${p.id}-${p.estado}'),
      initialValue: p.estado,
      decoration: productoDecoracion().copyWith(
        labelText: 'Estado del pedido',
        helperText: !widget.esPropietario
            ? 'Solo el propietario puede cambiar a producción o entregado.'
            : p.estado == 'ENCARGADO'
            ? 'Debe pasar por producción antes de entregarse.'
            : null,
        helperMaxLines: 2,
      ),
      items: [
        for (final estado in EstadosPedido.progreso)
          DropdownMenuItem(
            value: estado,
            enabled: estado == p.estado || habilitado(estado),
            child: Text(
              EstadosPedido.etiqueta(estado),
              style: estado == p.estado || habilitado(estado)
                  ? null
                  : BarroTheme.type(14, 21, color: BarroTheme.placeholder),
            ),
          ),
      ],
      onChanged: editable
          ? (estado) {
              if (estado == null || estado == p.estado) return;
              _accion(() => widget.gestion.cambiarEstado(p.id, estado));
            }
          : null,
    );
  }

  Future<void> _terminar(ResumenPedido p) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminar pedido'),
        content: Text(
          '¿Estás seguro de terminar el pedido de ${p.cliente}? '
          'Ya no podrá cambiar de estado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, terminar'),
          ),
        ],
      ),
    );
    if (confirmar == true && mounted) {
      await _accion(() => widget.gestion.cambiarEstado(p.id, 'TERMINADO'));
    }
  }

  @override
  Widget build(BuildContext context) {
    // La búsqueda filtra los pedidos ya cargados; el estado se filtra en el servidor.
    final busqueda = _busqueda.trim().toLowerCase();
    final visibles = _pedidos
        .where((p) => p.cliente.toLowerCase().contains(busqueda))
        .toList();
    return ProductoScaffold(
      // El empleado navega con la barra de su pantalla de inicio.
      barraInferior: widget.esPropietario
          ? SucursalNavegacion(
              seleccionada: 'Pedidos',
              onInicio: () => Navigator.of(context).maybePop(),
              onPedidos: () {},
              onInventario: widget.onInventario,
              onCaja: widget.onCaja,
            )
          : null,
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
          decoration: productoDecoracion(hint: 'Buscar cliente...'),
          onChanged: (v) => setState(() => _busqueda = v),
        ),
        const SizedBox(height: 12),
        _filtros(),
        const SizedBox(height: 14),
        ProductoBoton(texto: '+ Nuevo pedido', onPressed: _nuevo),
        const SizedBox(height: 20),
        if (_cargando)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          ProductoAviso(_error!, error: true)
        else if (visibles.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                _estado == null || busqueda.isNotEmpty
                    ? 'No hay pedidos para mostrar.'
                    : 'No hay pedidos en estado ${EstadosPedido.etiqueta(_estado!).toLowerCase()}.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Mostrando ${_pedidos.length} de $_total',
              style: BarroTheme.type(13, 20),
            ),
          ),
          for (final p in visibles) _tarjeta(p),
        ],
        if (!_cargando && _error == null && !_ultima)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: _cargandoMas
                  ? const CircularProgressIndicator()
                  : OutlinedButton(
                      onPressed: _masPedidos,
                      child: const Text('Cargar más pedidos'),
                    ),
            ),
          ),
      ],
    );
  }
}
