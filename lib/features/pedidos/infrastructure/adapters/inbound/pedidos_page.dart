import 'dart:async';

import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/productos/domain/producto.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_widgets.dart';
import '../../../application/gestion_pedidos.dart';
import '../../../domain/pedido.dart';
import 'package:punto_de_venta/features/sucursal/infrastructure/adapters/inbound/flutter/encabezado_sucursal_negocio.dart';
import 'pedido_detalle_page.dart';
import 'registrar_pedido_page.dart';
import 'terminar_pedido_dialog.dart';
import 'package:punto_de_venta/features/sucursal/infrastructure/adapters/inbound/flutter/sucursal_widgets.dart';
import 'notificaciones_page.dart';
import 'pedido_widgets.dart';
import 'package:punto_de_venta/core/infrastructure/widgets/barro_header.dart';
import 'package:punto_de_venta/features/notificaciones/application/contador_notificaciones.dart';
import 'package:punto_de_venta/core/infrastructure/services/notificacion_servicio.dart';

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
    this.onDatosContables,
    this.encabezado,
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
  final VoidCallback? onDatosContables;

  /// Desde el negocio (propietario): título y selector de sucursal con el
  /// diseño de Datos contables, sin barra inferior de la sucursal.
  final Widget? encabezado;
  @override
  State<PedidosPage> createState() => _PedidosPageState();
}

class _PedidosPageState extends State<PedidosPage> {
  List<ResumenPedido> _pedidos = [];
  bool _cargando = true;
  bool _cargandoMas = false;
  String? _error;

  /// Texto buscado en el servidor (ya recortado); vacío = sin buscar. Mientras
  /// hay búsqueda se ignora el filtro de estado: busca en todos.
  String _buscado = '';
  Timer? _espera;
  final _buscador = TextEditingController();
  bool get _buscando => _buscado.isNotEmpty;
  String? get _estadoConsulta => _buscando ? null : _estado;
  String? get _busquedaConsulta => _buscando ? _buscado : null;

  /// Estado filtrado en el servidor; null = todos.
  late String? _estado = EstadosPedido.porDefecto(
    esPropietario: widget.esPropietario,
  );
  int _pagina = 0;
  bool _ultima = true;
  int _total = 0;

  /// Descarta respuestas de una carga anterior (p. ej. al cambiar de filtro rápido).
  int _carga = 0;

  /// Filtro (estado, búsqueda) al que corresponden los pedidos en pantalla.
  /// Mientras recarga el mismo filtro (al volver del detalle o al deslizar)
  /// se siguen mostrando; si cambió, se muestra lo guardado de ese filtro o nada.
  (String?, String)? _filtroMostrado;
  bool _hayMostrados = false;

  void _mostrar(PaginaPedidos pagina) {
    _pedidos = pagina.pedidos;
    _pagina = pagina.pagina;
    _ultima = pagina.ultima;
    _total = pagina.total;
    _filtroMostrado = (_estadoConsulta, _buscado);
    _hayMostrados = true;
  }

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _espera?.cancel();
    _buscador.dispose();
    super.dispose();
  }

  /// Espera a que se deje de escribir para no consultar en cada tecla.
  void _buscar(String texto) {
    setState(() {}); // Muestra u oculta la X al instante.
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 350), () {
      final buscado = texto.trim();
      if (!mounted || buscado == _buscado) return;
      setState(() => _buscado = buscado);
      _cargar();
    });
  }

  /// Carga la primera página del filtro actual.
  Future<void> _cargar() async {
    // Registrar o cambiar un pedido genera avisos: no esperar al sondeo de 45 s.
    unawaited(widget.contador.actualizar());
    final carga = ++_carga;
    setState(() {
      // Se muestra al instante lo último recibido; la consulta lo reemplaza.
      if (!_hayMostrados || _filtroMostrado != (_estadoConsulta, _buscado)) {
        final guardado = _buscando
            ? null
            : widget.gestion.listadoGuardado(
                widget.sucursalId,
                estado: _estado,
              );
        if (guardado != null) {
          _mostrar(guardado);
        } else {
          _pedidos = [];
          _hayMostrados = false;
        }
      }
      _cargando = true;
      _cargandoMas = false;
      _error = null;
    });
    try {
      final pagina = await widget.gestion.listar(
        widget.sucursalId,
        estado: _estadoConsulta,
        busqueda: _busquedaConsulta,
      );
      if (!mounted || carga != _carga) return;
      setState(() => _mostrar(pagina));
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
        estado: _estadoConsulta,
        busqueda: _busquedaConsulta,
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
        NotificacionServicio.error(context, e.message);
      }
    } finally {
      if (mounted && carga == _carga) setState(() => _cargandoMas = false);
    }
  }

  /// Borra la búsqueda de inmediato y cierra el teclado.
  void _limpiarBusqueda() {
    _buscador.clear();
    _quitarFoco();
    _espera?.cancel();
    if (_buscado.isEmpty) return setState(() {});
    setState(() => _buscado = '');
    _cargar();
  }

  void _quitarFoco() => FocusManager.instance.primaryFocus?.unfocus();

  void _filtrar(String? estado) {
    _quitarFoco();
    if (estado == _estado) return;
    setState(() => _estado = estado);
    _cargar();
  }

  void _abrirNotificaciones() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => NotificacionesPage(
        gestion: widget.gestion,
        contador: widget.contador,
        esPropietario: widget.esPropietario,
      ),
    ),
  );

  /// La campana de la cabecera común (BarroHeader) toma su acción del
  /// BarroHeaderScope más cercano. Pedidos y las pantallas que abre son rutas
  /// nuevas, fuera del scope de la pantalla de inicio, así que se lo damos
  /// aquí: abre las notificaciones y muestra el punto si hay sin leer.
  Widget _conCampana(Widget pantalla) => BarroHeaderScope(
    onPerfil: BarroHeaderScope.maybeOf(context)?.onPerfil,
    onNotificaciones: _abrirNotificaciones,
    conteoNotificaciones: widget.contador,
    child: pantalla,
  );

  Future<void> _nuevo() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _conCampana(
          RegistrarPedidoPage(
            gestion: widget.gestion,
            sucursalId: widget.sucursalId,
            negocio: widget.negocio,
            esPropietario: widget.esPropietario,
            sucursalNombre: widget.sucursalNombre,
            // Se llaman ya cerrado el registro: mismos destinos que esta barra.
            onInicio: () => Navigator.of(context).maybePop(),
            onCaja: widget.onCaja,
            onInventario: widget.onInventario,
            onDatosContables: widget.onDatosContables,
          ),
        ),
      ),
    );
    if (mounted) await _cargar();
  }

  Future<void> _detalle(ResumenPedido pedido) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _conCampana(
          PedidoDetallePage(
            gestion: widget.gestion,
            pedidoId: pedido.id,
            sucursalId: widget.sucursalId,
            esPropietario: widget.esPropietario,
            negocio: widget.negocio,
            sucursalNombre: widget.sucursalNombre,
          ),
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
        NotificacionServicio.error(context, e.message);
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
              // Con búsqueda se busca en todos los estados: el filtro espera.
              selected: !_buscando && _estado == estado,
              onSelected: _buscando ? null : (_) => _filtrar(estado),
            ),
          ),
      ],
    ),
  );

  /// Productos visibles en la tarjeta; el resto se resume en "+N más".
  static const _productosVisibles = 3;

  Widget _tarjeta(ResumenPedido p) {
    final (_, colorEstado, _) = PedidoEstadoChip.colores(p.estado);
    final extra = p.productos.length - _productosVisibles;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BarroTheme.border),
        borderRadius: BorderRadius.circular(21),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Franja con el color del estado: se distingue al recorrer la lista.
          Container(height: 4, color: colorEstado),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        p.cliente,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BarroTheme.type(17, 24, weight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PedidoEstadoChip(p.estado),
                  ],
                ),
                const SizedBox(height: 4),
                PedidoTipoEntrega(p.tipoEntrega),
                const SizedBox(height: 12),
                for (final d in p.productos.take(_productosVisibles))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: productoSuave,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${d.cantidad}×',
                            style: BarroTheme.type(
                              12,
                              18,
                              weight: FontWeight.w700,
                              color: BarroTheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            d.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BarroTheme.type(14, 21),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (extra > 0)
                  Text(
                    '+$extra ${extra == 1 ? 'producto' : 'productos'} más',
                    style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
                  ),
                const SizedBox(height: 10),
                _importes(p),
                const SizedBox(height: 10),
                // Wrap: en pantallas angostas el botón de terminar baja de renglón.
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: () => _detalle(p),
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('Ver detalle'),
                    ),
                    if (p.estado == 'ENTREGADO')
                      FilledButton.icon(
                        // Mientras se actualiza, la tarjeta puede estar atrasada.
                        onPressed: _cargando ? null : () => _terminar(p),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Terminar pedido'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Total, pagado y saldo en un recuadro suave; liquidado en verde.
  Widget _importes(ResumenPedido p) {
    final liquidado = p.saldo <= 0;
    Widget columna(String etiqueta, String valor, {Color? color}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: BarroTheme.type(11, 16, color: BarroTheme.secondary),
          ),
          Text(
            valor,
            style: BarroTheme.type(
              15,
              22,
              weight: FontWeight.w700,
              color: color ?? BarroTheme.text,
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: BarroTheme.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          columna('Total', formatoPrecio(p.total)),
          columna('Pagado', formatoPrecio(p.pagado)),
          liquidado
              ? Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_outlined,
                        size: 16,
                        color: BarroTheme.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Liquidado',
                        style: BarroTheme.type(
                          13,
                          20,
                          weight: FontWeight.w700,
                          color: BarroTheme.success,
                        ),
                      ),
                    ],
                  ),
                )
              : columna(
                  'Saldo',
                  formatoPrecio(p.saldo),
                  color: BarroTheme.primary,
                ),
        ],
      ),
    );
  }

  Future<void> _terminar(ResumenPedido p) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => TerminarPedidoDialog(pedido: p),
    );
    if (confirmar == true && mounted) {
      await _accion(() => widget.gestion.cambiarEstado(p.id, 'TERMINADO'));
    }
  }

  // Estado y búsqueda se filtran en el servidor: lo cargado es lo que se ve,
  // y "Mostrando X de Y" cuenta lo mismo que las tarjetas.
  @override
  Widget build(BuildContext context) => _conCampana(_pantalla(_pedidos));

  Widget _pantalla(List<ResumenPedido> visibles) {
    final contenido = <Widget>[
      TextField(
        controller: _buscador,
        textInputAction: TextInputAction.search,
        decoration:
            productoDecoracion(
              hint: 'Buscar por cliente, teléfono o folio...',
            ).copyWith(
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: BarroTheme.secondary,
              ),
              suffixIcon: _buscador.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar búsqueda',
                      icon: const Icon(Icons.close_rounded),
                      color: BarroTheme.secondary,
                      onPressed: _limpiarBusqueda,
                    ),
            ),
        onChanged: _buscar,
        // Al tocar fuera (filtros, tarjetas) se cierra el teclado.
        onTapOutside: (_) => _quitarFoco(),
      ),
      const SizedBox(height: 12),
      _filtros(),
      if (_buscando) ...[
        const SizedBox(height: 8),
        Text(
          'Buscando en todos los estados',
          style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
        ),
      ],
      const SizedBox(height: 14),
      ProductoBoton(texto: '+ Nuevo pedido', onPressed: _nuevo),
      const SizedBox(height: 20),
      // Con pedidos ya en pantalla (guardados o de la carga anterior) se
      // siguen mostrando y una barra indica que se están actualizando.
      if (_cargando && !_hayMostrados)
        const Center(child: CircularProgressIndicator())
      else if (_error != null)
        ProductoAviso(_error!, error: true)
      else if (_cargando && visibles.isEmpty)
        const LinearProgressIndicator()
      else if (visibles.isEmpty)
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              _buscando
                  ? 'Ningún pedido coincide con "$_buscado".'
                  : _estado == null
                  ? 'No hay pedidos para mostrar.'
                  : 'No hay pedidos en estado ${EstadosPedido.etiqueta(_estado!).toLowerCase()}.',
              textAlign: TextAlign.center,
            ),
          ),
        )
      else ...[
        if (_cargando) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
        ],
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
    ];
    final encabezado = widget.encabezado;
    if (encabezado != null) {
      return PantallaNegocio(
        onRefresh: _cargar,
        children: [encabezado, const SizedBox(height: 20), ...contenido],
      );
    }
    return ProductoScaffold(
      // El empleado navega con la barra de su pantalla de inicio.
      barraInferior: widget.esPropietario
          ? SucursalNavegacion(
              seleccionada: 'Pedidos',
              onInicio: () => Navigator.of(context).maybePop(),
              onPedidos: () {},
              onInventario: widget.onInventario,
              onCaja: widget.onCaja,
              onDatosContables: widget.onDatosContables,
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
        Text(
          'Pedidos',
          style: BarroTheme.type(28, 36, weight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        ...contenido,
      ],
    );
  }
}
