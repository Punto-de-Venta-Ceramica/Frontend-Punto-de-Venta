import 'dart:async';

import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_widgets.dart'
    show ProductoImagen;

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
    super.key,
  });

  final VentaContexto contexto;
  final GestionVentas gestion;
  final int sucursalId;
  final VoidCallback onSesionExpirada;

  @override
  State<RegistrarVentaPage> createState() => _RegistrarVentaPageState();
}

class _RegistrarVentaPageState extends State<RegistrarVentaPage> {
  final _carrito = <int, SeleccionVenta>{};
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
      espacioAntesContenido: 0,
      onAccion: (!_cargando || _soloSeleccionados) && seleccion.isNotEmpty
          ? () => _continuar(seleccion)
          : null,
      onCancelar: () => Navigator.of(context).pop(),
      resumen: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              '$piezas piezas · ${seleccion.length} productos',
              style: BarroTheme.type(14, 20, color: BarroTheme.secondary),
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
            label: const Text('Seleccionados'),
            selected: _soloSeleccionados,
            showCheckmark: false,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            visualDensity: VisualDensity.standard,
            onSelected: seleccion.isNotEmpty || _soloSeleccionados
                ? _alternarSeleccionados
                : null,
          ),
          child: TextField(
            maxLength: 150,
            onChanged: _buscar,
            decoration: decoracionCampoVenta(
              indicacion: 'Nombre o ID del producto',
            ).copyWith(counterText: ''),
          ),
        ),
        if (!_soloSeleccionados &&
            pagina != null &&
            (pagina.pagina > 0 || !pagina.ultima))
          Row(
            children: [
              IconButton(
                onPressed: _cargando || _error != null || pagina.pagina == 0
                    ? null
                    : () => _cargar(pagina.pagina - 1),
                tooltip: 'Página anterior',
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  'Página ${pagina.pagina + 1} · ${pagina.totalElementos} productos',
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                onPressed: _cargando || _error != null || pagina.ultima
                    ? null
                    : () => _cargar(pagina.pagina + 1),
                tooltip: 'Página siguiente',
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        const SizedBox(height: 24),
        if (!_soloSeleccionados && _cargando)
          const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Cargando productos',
            ),
          )
        else if (!_soloSeleccionados && _error != null)
          AvisoVenta(_error!, onReintentar: () => _cargar(_paginaSolicitada))
        else if (productos.isEmpty)
          VentaPanel(
            child: Text(
              _mensajeSinProductos(seleccion.isEmpty),
              style: BarroTheme.type(14, 20, color: BarroTheme.secondary),
            ),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: VentaProductoCard(
        nombre: producto.nombre,
        imagenUrl: producto.imagenUrl,
        areaNombre: producto.areaNombre,
        categoriaNombre: producto.categoriaNombre,
        disponibilidad:
            '${dineroVenta(producto.precio)} c/u · ${producto.existencia} disponibles',
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

class VentaProductoCard extends StatelessWidget {
  const VentaProductoCard({
    required this.nombre,
    required this.disponibilidad,
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
  final String disponibilidad;
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

  static const double _altoImagen = 72;
  static const double _anchoMaximoImagen = 92;

  @override
  Widget build(BuildContext context) => VentaPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: SizedBox(
                width: _anchoMaximoImagen,
                height: _altoImagen,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ProductoImagen(
                    size: _altoImagen,
                    url: imagenUrl,
                    conservarProporcion: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    nombre,
                    textAlign: TextAlign.end,
                    style: BarroTheme.type(14, 19, weight: FontWeight.w700),
                  ),
                  Text(
                    disponibilidad,
                    textAlign: TextAlign.end,
                    style: BarroTheme.type(12, 17, color: BarroTheme.secondary),
                  ),
                  if (areaNombre != null || categoriaNombre != null)
                    DefaultTextStyle(
                      style: BarroTheme.type(
                        12,
                        17,
                        color: BarroTheme.secondary,
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 12,
                        runSpacing: 2,
                        children: [
                          if (areaNombre case final area?)
                            Text('Área: $area', textAlign: TextAlign.end),
                          if (categoriaNombre case final categoria?)
                            Text(
                              'Categoría: $categoria',
                              textAlign: TextAlign.end,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: BarroTheme.border.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      tooltip: 'Quitar una pieza de $nombre',
                      onPressed: onQuitar,
                    ),
                    Flexible(
                      child: Text(
                        '$cantidad',
                        style: BarroTheme.type(14, 20, weight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: 'Agregar una pieza de $nombre',
                      onPressed: onAgregar,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 2,
                children: [
                  Text(
                    'Subtotal',
                    style: BarroTheme.type(13, 18, color: BarroTheme.secondary),
                  ),
                  Text(
                    subtotal,
                    textAlign: TextAlign.end,
                    style: BarroTheme.type(16, 22, weight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (porcentajeDescuento case final porcentaje?)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            minTileHeight: 48,
            dense: true,
            controlAffinity: ListTileControlAffinity.trailing,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            activeColor: BarroTheme.primary,
            value: aplicarDescuento,
            onChanged: onCambiarDescuento == null
                ? null
                : (valor) => onCambiarDescuento!(valor ?? false),
            title: Text(
              'Aplicar descuento · ${_formatearPorcentaje(porcentaje)} %',
              textAlign: TextAlign.end,
              style: BarroTheme.type(13, 18, weight: FontWeight.w500),
            ),
          ),
      ],
    ),
  );

  static String _formatearPorcentaje(num valor) =>
      valor.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}
