import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_widgets.dart'
    show NivelExistencia, ProductoImagen, productoSuave;
import 'package:punto_de_venta/features/tickets/application/impresion_tickets.dart';
import 'package:punto_de_venta/features/tickets/infrastructure/impresion_tickets_bluetooth.dart';

import '../../../../application/services/gestion_ventas.dart';
import '../../../../domain/busqueda_productos_venta.dart';
import '../../../../domain/venta.dart';
import 'cobro_libre_widgets.dart';
import 'confirmar_venta_page.dart';
import 'filtros_productos_venta.dart';
import 'ventas_widgets.dart';

class RegistrarVentaPage extends StatefulWidget {
  const RegistrarVentaPage({
    required this.contexto,
    required this.gestion,
    required this.sucursalId,
    required this.onSesionExpirada,
    this.impresion = impresionTicketsBluetooth,
    super.key,
  });

  final VentaContexto contexto;
  final GestionVentas gestion;
  final int sucursalId;
  final VoidCallback onSesionExpirada;

  /// Impresión del ticket una vez registrada la venta.
  final ImpresionTickets impresion;

  @override
  State<RegistrarVentaPage> createState() => _RegistrarVentaPageState();
}

class _RegistrarVentaPageState extends State<RegistrarVentaPage> {
  final _formulario = GlobalKey<FormState>();
  final _carrito = <int, SeleccionVenta>{};

  /// Cobro libre (artículo artesanal): una sola línea por venta, fuera del listado
  /// porque no tiene existencia ni descuentos.
  SeleccionVenta? _libre;
  ProductoVenta? _productoLibre;
  bool _cargandoLibre = false;
  final _buscador = TextEditingController();
  PaginaProductosVenta? _pagina;
  Timer? _esperaBusqueda;
  int _solicitud = 0;
  int _paginaSolicitada = 0;
  String _busqueda = '';
  FiltroProductosVenta _filtros = const FiltroProductosVenta();
  String? _error;
  bool _cargando = true;
  bool _abriendoPago = false;
  bool _soloSeleccionados = false;

  @override
  void initState() {
    super.initState();
    _cargar(0);
  }

  @override
  void dispose() {
    _esperaBusqueda?.cancel();
    _buscador.dispose();
    super.dispose();
  }

  void _buscar(String texto) {
    final busqueda = texto.trim();
    if (busqueda == _busqueda) return;
    _reiniciarListado(
      busqueda: busqueda,
      espera: const Duration(milliseconds: 300),
    );
  }

  void _reiniciarListado({
    String? busqueda,
    FiltroProductosVenta? filtros,
    Duration? espera,
  }) {
    _esperaBusqueda?.cancel();
    _solicitud++;
    setState(() {
      _busqueda = busqueda ?? _busqueda;
      _filtros = filtros ?? _filtros;
      _pagina = null;
      _paginaSolicitada = 0;
      _error = null;
      _cargando = !_soloSeleccionados;
    });
    if (_soloSeleccionados) return;
    if (espera == null) {
      _cargar(0);
    } else {
      _esperaBusqueda = Timer(espera, () => _cargar(0));
    }
  }

  void _limpiarBusqueda() {
    _buscador.clear();
    _buscar('');
  }

  void _alternarSeleccionados(bool valor) {
    setState(() => _soloSeleccionados = valor);
    if (!valor && _pagina == null && !_cargando && _error == null) {
      _cargar(_paginaSolicitada);
    }
  }

  Future<void> _cargar(int indice) async {
    _esperaBusqueda?.cancel();
    final solicitud = ++_solicitud;
    setState(() {
      _paginaSolicitada = indice;
      _cargando = true;
      _error = null;
    });
    try {
      final pagina = await widget.gestion.listarProductos(
        widget.sucursalId,
        buscar: _busqueda,
        filtros: _filtros,
        pagina: indice,
      );
      if (!mounted || solicitud != _solicitud) return;
      final total = pagina.totalElementos;
      final ultimaPagina = total == 0
          ? 0
          : (total - 1) ~/ GestionVentas.productosPorPagina;
      if (pagina.productos.isEmpty && indice > ultimaPagina) {
        await _cargar(ultimaPagina);
        return;
      }
      setState(() {
        for (final producto in pagina.productos) {
          final seleccion = _carrito[producto.id];
          if (seleccion == null) continue;
          if (producto.existencia == 0) {
            _carrito.remove(producto.id);
          } else {
            _carrito[producto.id] = seleccion.actualizar(
              producto,
              seleccion.cantidad.clamp(1, producto.existencia),
            );
          }
        }
        _pagina = pagina;
        _cargando = false;
      });
    } on VentaFailure catch (error) {
      if (!mounted || solicitud != _solicitud) return;
      if (error.sesionExpirada) {
        widget.onSesionExpirada();
        return;
      }
      setState(() {
        _error = error.mensaje;
        _cargando = false;
      });
    }
  }

  void _cambiarCantidad(ProductoVenta producto, int cantidad) {
    setState(() {
      if (cantidad == 0) {
        _carrito.remove(producto.id);
      } else {
        _carrito[producto.id] =
            _carrito[producto.id]?.actualizar(producto, cantidad) ??
            SeleccionVenta(producto: producto, cantidad: cantidad);
      }
    });
  }

  void _cambiarDescuento(int productoId, bool aplicar) {
    final seleccion = _carrito[productoId];
    if (seleccion == null || seleccion.porcentajeDisponible == null) return;
    setState(() {
      _carrito[productoId] = SeleccionVenta(
        producto: seleccion.producto,
        cantidad: seleccion.cantidad,
        aplicarDescuento: aplicar,
      );
    });
  }

  Future<void> _abrirCobroLibre() async {
    if (_cargandoLibre) return;
    var producto = _productoLibre;
    if (producto == null) {
      setState(() => _cargandoLibre = true);
      try {
        producto = await widget.gestion.productoLibre(widget.sucursalId);
      } on VentaFailure catch (error) {
        if (!mounted) return;
        setState(() => _cargandoLibre = false);
        if (error.sesionExpirada) {
          widget.onSesionExpirada();
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.mensaje)));
        return;
      }
      if (!mounted) return;
      setState(() {
        _productoLibre = producto;
        _cargandoLibre = false;
      });
    }
    final resultado = await mostrarCobroLibre(
      context,
      actual: _libre,
      nombrePorDefecto: producto.nombre,
    );
    if (!mounted || resultado == null) return;
    final cobro = resultado.cobro;
    setState(() {
      _libre = resultado.quitar || cobro == null
          ? null
          : SeleccionVenta(
              producto: producto!,
              cantidad: cobro.cantidad,
              precioLibre: cobro.precio,
              nombreLibre: cobro.nombre,
            );
    });
  }

  Future<void> _continuar(List<SeleccionVenta> seleccion) async {
    if (_abriendoPago || !_formulario.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _abriendoPago = true);
    final venta = await Navigator.of(context).push<VentaRegistrada>(
      MaterialPageRoute(
        builder: (_) => ConfirmarVentaPage(
          contexto: widget.contexto,
          gestion: widget.gestion,
          sucursalId: widget.sucursalId,
          productos: seleccion,
          onSesionExpirada: widget.onSesionExpirada,
          impresion: widget.impresion,
        ),
      ),
    );
    if (!mounted) return;
    if (venta != null) {
      Navigator.of(context).pop(venta);
      return;
    }
    setState(() => _abriendoPago = false);
    await _cargar(_paginaSolicitada);
  }

  @override
  Widget build(BuildContext context) {
    final seleccion = [
      ..._carrito.values,
      ?_libre,
    ];
    final piezas = seleccion.fold(0, (suma, linea) => suma + linea.cantidad);
    final total = seleccion.fold<num>(0, (suma, linea) => suma + linea.importe);
    final pagina = _pagina;
    final productos = _soloSeleccionados
        ? BusquedaProductosVenta(_busqueda).filtrar(
            seleccion.map((linea) => linea.producto).where(_filtros.coincide),
          )
        : pagina?.productos ?? const <ProductoVenta>[];

    final pantalla = VentaScaffold(
      contexto: widget.contexto,
      paso: '1 de 2 · Selecciona productos de tu sucursal.',
      accion: 'Continuar al pago',
      iconoAccion: Icons.arrow_forward_rounded,
      espacioAntesContenido: 0,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      onAccion: (!_cargando || _soloSeleccionados) && seleccion.isNotEmpty
          ? () => _continuar(seleccion)
          : null,
      onCancelar: () => Navigator.of(context).pop(),
      resumen: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              children: [
                Badge(
                  isLabelVisible: seleccion.isNotEmpty,
                  backgroundColor: BarroTheme.primary,
                  label: Text('${seleccion.length}'),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: productoSuave,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.shopping_cart_outlined,
                      size: 22,
                      color: BarroTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    '$piezas piezas · ${seleccion.length} productos',
                    style: BarroTheme.type(14, 20, color: BarroTheme.secondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Total estimado:\n${dineroVenta(total)} MXN',
              textAlign: TextAlign.end,
              style: BarroTheme.type(18, 24, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
      children: [
        TarjetaCobroLibre(
          seleccion: _libre,
          cargando: _cargandoLibre,
          onAbrir: _abrirCobroLibre,
          onQuitar: _libre == null
              ? null
              : () => setState(() => _libre = null),
        ),
        const SizedBox(height: 20),
        VentaCampo(
          etiqueta: 'Buscar producto',
          accionEtiqueta: FilterChip(
            avatar: Icon(
              _soloSeleccionados
                  ? Icons.shopping_basket
                  : Icons.shopping_basket_outlined,
              size: 18,
              color: BarroTheme.primary,
            ),
            label: const Text('Seleccionados'),
            selected: _soloSeleccionados,
            selectedColor: productoSuave,
            showCheckmark: false,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            visualDensity: VisualDensity.standard,
            onSelected: seleccion.isNotEmpty || _soloSeleccionados
                ? _alternarSeleccionados
                : null,
          ),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _buscador,
            builder: (context, valor, _) => TextField(
              controller: _buscador,
              maxLength: 150,
              onChanged: _buscar,
              textInputAction: TextInputAction.search,
              decoration:
                  decoracionCampoVenta(
                    indicacion: 'Nombre o ID del producto',
                  ).copyWith(
                    counterText: '',
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 22,
                      color: BarroTheme.primary,
                    ),
                    suffixIcon: valor.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar búsqueda',
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: _limpiarBusqueda,
                          ),
                  ),
            ),
          ),
        ),
        FiltrosProductosVenta(
          aplicados: _filtros,
          cargarCategorias: () =>
              widget.gestion.cargarCategorias(widget.sucursalId),
          onAplicar: (filtros) => _reiniciarListado(filtros: filtros),
          onSesionExpirada: widget.onSesionExpirada,
        ),
        if (!_soloSeleccionados &&
            pagina != null &&
            (pagina.pagina > 0 || !pagina.ultima)) ...[
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: BarroTheme.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _cargando || _error != null || pagina.pagina == 0
                      ? null
                      : () => _cargar(pagina.pagina - 1),
                  tooltip: 'Página anterior',
                  color: BarroTheme.primary,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    'Página ${pagina.pagina + 1} · ${pagina.totalElementos} productos',
                    textAlign: TextAlign.center,
                    style: BarroTheme.type(13, 18, weight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  onPressed: _cargando || _error != null || pagina.ultima
                      ? null
                      : () => _cargar(pagina.pagina + 1),
                  tooltip: 'Página siguiente',
                  color: BarroTheme.primary,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (!_soloSeleccionados && _cargando)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Cargando productos',
              ),
            ),
          )
        else if (!_soloSeleccionados && _error != null)
          AvisoVenta(_error!, onReintentar: () => _cargar(_paginaSolicitada))
        else if (productos.isEmpty)
          _SinProductos(
            mensaje: _mensajeSinProductos(seleccion.isEmpty),
            icono: _soloSeleccionados
                ? Icons.remove_shopping_cart_outlined
                : _busqueda.isEmpty && !_filtros.activo
                ? Icons.inventory_2_outlined
                : Icons.search_off_rounded,
          )
        else
          for (final producto in productos) _tarjeta(producto),
      ],
    );
    return Form(key: _formulario, child: pantalla);
  }

  String _mensajeSinProductos(bool carritoVacio) {
    if (_soloSeleccionados) {
      return carritoVacio
          ? 'Aún no has seleccionado productos.'
          : _filtros.activo
          ? 'Ningún producto seleccionado coincide con los filtros.'
          : 'Ningún producto seleccionado coincide con la búsqueda.';
    }
    if (_filtros.activo) return 'No hay productos con estos filtros.';
    return _busqueda.isEmpty
        ? 'Esta sucursal no tiene productos disponibles.'
        : 'No se encontraron productos.';
  }

  Widget _tarjeta(ProductoVenta producto) {
    final seleccion = _carrito[producto.id];
    final cantidad = seleccion?.cantidad ?? 0;
    final porcentaje = seleccion?.porcentajeDisponible;
    final puedeSeleccionar =
        producto.existencia > 0 &&
        (cantidad > 0 ||
            _carrito.length + (_libre == null ? 0 : 1) <
                SeleccionVenta.maximoProductos);
    final puedeAgregar = puedeSeleccionar && cantidad < producto.existencia;
    return Padding(
      key: ValueKey(producto.id),
      padding: const EdgeInsets.only(bottom: 10),
      child: VentaProductoCard(
        nombre: producto.nombre,
        imagenUrl: producto.imagenUrl,
        areaNombre: producto.areaNombre,
        categoriaNombre: producto.categoriaNombre,
        precio: dineroVenta(producto.precio),
        existencia: producto.existencia,
        cantidad: cantidad,
        onCambiarCantidad: puedeSeleccionar
            ? (valor) => _cambiarCantidad(producto, valor)
            : null,
        subtotal: dineroVenta(seleccion?.importe ?? 0),
        porcentajeDescuento: porcentaje,
        aplicarDescuento: seleccion?.aplicarDescuento ?? false,
        onCambiarDescuento: porcentaje == null
            ? null
            : (aplicar) => _cambiarDescuento(producto.id, aplicar),
        onQuitar: cantidad > 0
            ? () => _cambiarCantidad(producto, cantidad - 1)
            : null,
        onAgregar: puedeAgregar
            ? () => _cambiarCantidad(producto, cantidad + 1)
            : null,
      ),
    );
  }
}

class _SinProductos extends StatelessWidget {
  const _SinProductos({required this.mensaje, required this.icono});

  final String mensaje;
  final IconData icono;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: productoSuave,
            shape: BoxShape.circle,
          ),
          child: Icon(icono, size: 30, color: BarroTheme.primary),
        ),
        const SizedBox(height: 12),
        Text(
          mensaje,
          textAlign: TextAlign.center,
          style: BarroTheme.type(14, 20, color: BarroTheme.secondary),
        ),
      ],
    ),
  );
}

class VentaProductoCard extends StatelessWidget {
  const VentaProductoCard({
    required this.nombre,
    required this.precio,
    required this.existencia,
    required this.cantidad,
    required this.subtotal,
    this.imagenUrl,
    this.areaNombre,
    this.categoriaNombre,
    this.porcentajeDescuento,
    this.aplicarDescuento = false,
    this.onCambiarDescuento,
    this.onQuitar,
    this.onAgregar,
    this.onCambiarCantidad,
    super.key,
  });

  final String nombre;

  /// Precio unitario ya formateado.
  final String precio;
  final int existencia;
  final int cantidad;
  final String subtotal;
  final String? imagenUrl;
  final String? areaNombre;
  final String? categoriaNombre;
  final num? porcentajeDescuento;
  final bool aplicarDescuento;
  final ValueChanged<bool>? onCambiarDescuento;
  final VoidCallback? onQuitar;
  final VoidCallback? onAgregar;
  final ValueChanged<int>? onCambiarCantidad;

  /// Lado de la foto: la imagen es lo primero que se reconoce del producto.
  static const double ladoImagen = 108;

  @override
  Widget build(BuildContext context) {
    final seleccionado = cantidad > 0;
    final radio = BorderRadius.circular(20);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radio,
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F57423D),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: seleccionado ? const Color(0xFFFFFCFA) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: radio,
          side: BorderSide(
            color: seleccionado ? BarroTheme.primary : BarroTheme.border,
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: _contenido(seleccionado),
        ),
      ),
    );
  }

  Widget _contenido(bool seleccionado) {
    final nivel = NivelExistencia.de(existencia);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Stack(
                children: [
                  ProductoImagen(size: ladoImagen, url: imagenUrl),
                  if (seleccionado)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: BarroTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: BarroTheme.type(16, 22, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        precio,
                        style: BarroTheme.type(
                          18,
                          24,
                          weight: FontWeight.w800,
                          color: BarroTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'c/u',
                        style: BarroTheme.type(
                          12,
                          17,
                          color: BarroTheme.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _DatoProducto(
                    icono: nivel.icono,
                    texto: '$existencia disponibles',
                    color: nivel.color,
                    negritas: true,
                  ),
                  if (areaNombre case final area?)
                    _DatoProducto(
                      icono: Icons.grid_view_outlined,
                      texto: area,
                      etiqueta: 'Área: $area',
                    ),
                  if (categoriaNombre case final categoria?)
                    _DatoProducto(
                      icono: Icons.label_outline,
                      texto: categoria,
                      etiqueta: 'Categoría: $categoria',
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
          decoration: BoxDecoration(
            color: seleccionado
                ? productoSuave
                : BarroTheme.border.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton.outlined(
                icon: const Icon(Icons.remove_rounded),
                tooltip: 'Quitar una pieza de $nombre',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: BarroTheme.primary,
                  side: const BorderSide(color: BarroTheme.border),
                ),
                onPressed: onQuitar,
              ),
              _CantidadVenta(
                nombre: nombre,
                cantidad: cantidad,
                maximo: existencia,
                onChanged: onCambiarCantidad,
              ),
              IconButton.filled(
                icon: const Icon(Icons.add_rounded),
                tooltip: 'Agregar una pieza de $nombre',
                style: IconButton.styleFrom(
                  backgroundColor: BarroTheme.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: onAgregar,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Subtotal',
                      style: BarroTheme.type(
                        12,
                        16,
                        color: BarroTheme.secondary,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        subtotal,
                        style: BarroTheme.type(18, 24, weight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (porcentajeDescuento case final porcentaje?)
          CheckboxListTile(
            contentPadding: const EdgeInsets.only(left: 4),
            minTileHeight: 48,
            dense: true,
            controlAffinity: ListTileControlAffinity.trailing,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            activeColor: BarroTheme.primary,
            value: aplicarDescuento,
            onChanged: onCambiarDescuento == null
                ? null
                : (valor) => onCambiarDescuento!(valor ?? false),
            secondary: const Icon(
              Icons.local_offer_outlined,
              size: 20,
              color: BarroTheme.success,
            ),
            title: Text(
              'Aplicar descuento · ${_formatearPorcentaje(porcentaje)} %',
              style: BarroTheme.type(
                13,
                18,
                weight: FontWeight.w600,
                color: BarroTheme.success,
              ),
            ),
          ),
      ],
    );
  }

  static String _formatearPorcentaje(num valor) =>
      valor.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}

class _CantidadVenta extends StatefulWidget {
  const _CantidadVenta({
    required this.nombre,
    required this.cantidad,
    required this.maximo,
    required this.onChanged,
  });

  final String nombre;
  final int cantidad;
  final int maximo;
  final ValueChanged<int>? onChanged;

  @override
  State<_CantidadVenta> createState() => _CantidadVentaState();
}

class _CantidadVentaState extends State<_CantidadVenta>
    with AutomaticKeepAliveClientMixin {
  static final _entero = RegExp(r'^\d{0,10}$');
  late final _controlador = TextEditingController(text: '${widget.cantidad}');
  final _foco = FocusNode();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _foco.addListener(_restaurarSiVacio);
  }

  @override
  void didUpdateWidget(covariant _CantidadVenta oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cantidad != widget.cantidad &&
        int.tryParse(_controlador.text) != widget.cantidad) {
      // El formulario recibe la nueva cantidad cuando termina su reconstrucción.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controlador.text = '${widget.cantidad}';
        }
      });
    }
  }

  void _restaurarSiVacio() {
    if (!_foco.hasFocus && _controlador.text.isEmpty) {
      _controlador.text = '${widget.cantidad}';
    }
  }

  String? _validar(String? texto) {
    if (texto == null || texto.isEmpty) return null;
    final cantidad = int.tryParse(texto);
    if (cantidad == null || cantidad > widget.maximo) {
      return 'Máximo ${widget.maximo}';
    }
    return null;
  }

  void _cambiar(String texto) {
    final cantidad = int.tryParse(texto);
    if (cantidad != null && cantidad <= widget.maximo) {
      widget.onChanged?.call(cantidad);
    }
  }

  @override
  void dispose() {
    _foco.removeListener(_restaurarSiVacio);
    _foco.dispose();
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SizedBox(
      width: 64,
      child: Semantics(
        label: 'Cantidad de ${widget.nombre}',
        child: TextFormField(
          controller: _controlador,
          focusNode: _foco,
          enabled: widget.onChanged != null,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          textAlign: TextAlign.center,
          style: BarroTheme.type(18, 24, weight: FontWeight.w700),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: _validar,
          inputFormatters: [
            TextInputFormatter.withFunction(
              (anterior, nuevo) =>
                  _entero.hasMatch(nuevo.text) ? nuevo : anterior,
            ),
          ],
          decoration: decoracionCampoVenta().copyWith(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 12,
            ),
          ),
          onChanged: _cambiar,
          onTap: () => _controlador.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controlador.text.length,
          ),
          onTapOutside: (_) => _foco.unfocus(),
          onFieldSubmitted: (_) => _foco.unfocus(),
        ),
      ),
    );
  }
}

/// Dato breve del producto acompañado de un ícono (existencia, área, etc.).
class _DatoProducto extends StatelessWidget {
  const _DatoProducto({
    required this.icono,
    required this.texto,
    this.etiqueta,
    this.color = BarroTheme.secondary,
    this.negritas = false,
  });

  final IconData icono;
  final String texto;

  /// Texto para lectores de pantalla cuando el ícono da el contexto.
  final String? etiqueta;
  final Color color;
  final bool negritas;

  @override
  Widget build(BuildContext context) => Semantics(
    label: etiqueta,
    excludeSemantics: etiqueta != null,
    child: Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(icono, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BarroTheme.type(
                12,
                17,
                weight: negritas ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
