import 'dart:async';

import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_widgets.dart'
    show NivelExistencia, ProductoImagen, productoSuave;
import 'package:punto_de_venta/features/tickets/application/impresion_tickets.dart';
import 'package:punto_de_venta/features/tickets/infrastructure/impresion_tickets_bluetooth.dart';

import '../../../../application/services/gestion_ventas.dart';
import '../../../../domain/venta.dart';
import 'confirmar_venta_page.dart';
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
  final _carrito = <int, SeleccionVenta>{};
  final _buscador = TextEditingController();
  PaginaProductosVenta? _pagina;
  Timer? _esperaBusqueda;
  int _solicitud = 0;
  int _paginaSolicitada = 0;
  String _busqueda = '';
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
    _esperaBusqueda?.cancel();
    _solicitud++;
    setState(() {
      _busqueda = busqueda;
      _pagina = null;
      _paginaSolicitada = 0;
      _error = null;
      _cargando = !_soloSeleccionados;
    });
    if (_soloSeleccionados) return;
    _esperaBusqueda = Timer(
      const Duration(milliseconds: 300),
      () => _cargar(0),
    );
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

  Future<void> _continuar(List<SeleccionVenta> seleccion) async {
    if (_abriendoPago) return;
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
    final seleccion = List<SeleccionVenta>.of(_carrito.values);
    final piezas = seleccion.fold(0, (suma, linea) => suma + linea.cantidad);
    final total = seleccion.fold<num>(0, (suma, linea) => suma + linea.importe);
    final pagina = _pagina;
    final consulta = _busqueda.toLowerCase();
    final idBuscado = int.tryParse(consulta);
    final productos = _soloSeleccionados
        ? [
            for (final linea in seleccion)
              if (linea.producto.nombre.toLowerCase().contains(consulta) ||
                  linea.producto.id == idBuscado)
                linea.producto,
          ]
        : pagina?.productos ?? const <ProductoVenta>[];

    return VentaScaffold(
      contexto: widget.contexto,
      paso: '1 de 2 · Selecciona productos de tu sucursal.',
      accion: 'Continuar al pago',
      iconoAccion: Icons.arrow_forward_rounded,
      espacioAntesContenido: 0,
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
                : _busqueda.isEmpty
                ? Icons.inventory_2_outlined
                : Icons.search_off_rounded,
          )
        else
          for (final producto in productos) _tarjeta(producto),
      ],
    );
  }

  String _mensajeSinProductos(bool carritoVacio) {
    if (_soloSeleccionados) {
      return carritoVacio
          ? 'Aún no has seleccionado productos.'
          : 'Ningún producto seleccionado coincide con la búsqueda.';
    }
    return _busqueda.isEmpty
        ? 'Esta sucursal no tiene productos disponibles.'
        : 'No se encontraron productos.';
  }

  Widget _tarjeta(ProductoVenta producto) {
    final seleccion = _carrito[producto.id];
    final cantidad = seleccion?.cantidad ?? 0;
    final porcentaje = seleccion?.porcentajeDisponible;
    final puedeAgregar =
        cantidad < producto.existencia &&
        (cantidad > 0 || _carrito.length < SeleccionVenta.maximoProductos);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: VentaProductoCard(
        nombre: producto.nombre,
        imagenUrl: producto.imagenUrl,
        areaNombre: producto.areaNombre,
        categoriaNombre: producto.categoriaNombre,
        precio: dineroVenta(producto.precio),
        existencia: producto.existencia,
        cantidad: cantidad,
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
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 36),
                child: Text(
                  '$cantidad',
                  textAlign: TextAlign.center,
                  style: BarroTheme.type(18, 24, weight: FontWeight.w700),
                ),
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
