import 'dart:async';

import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/descuentos/application/ports/inbound/gestion_descuentos_use_case.dart';
import '../../../../application/ports/inbound/gestion_productos_use_case.dart';
import '../../../../application/services/imagenes_producto.dart';
import '../../../../domain/producto.dart';
import 'producto_detalle_page.dart';
import 'producto_form_page.dart';
import 'package:punto_de_venta/features/sucursal/infrastructure/adapters/inbound/flutter/sucursal_widgets.dart';
import 'producto_widgets.dart';

class ProductosPage extends StatefulWidget {
  const ProductosPage({
    required this.gestion,
    required this.onSesionExpirada,
    this.sucursal,
    this.negocioInicial,
    this.onInicio,
    this.onPedidos,
    this.descuentos,
    this.imagenes,
    super.key,
  });
  final GestionProductosUseCase gestion;

  /// Para registrar y editar los descuentos (varios, opcionales) de cada producto.
  final GestionDescuentosUseCase? descuentos;
  final ImagenesProducto? imagenes;
  final VoidCallback onSesionExpirada;
  final NegocioProducto? negocioInicial;

  /// Con sucursal: solo sus productos y su existencia (acceso desde Administrar
  /// sucursal). Sin sucursal: catálogo completo del negocio con todas las sucursales.
  final SucursalProducto? sucursal;
  final VoidCallback? onInicio;
  final VoidCallback? onPedidos;
  @override
  State<ProductosPage> createState() => _ProductosPageState();
}

class _ProductosPageState extends State<ProductosPage> {
  List<NegocioProducto> _negocios = [];
  NegocioProducto? _negocio;
  List<Producto> _productos = [];
  List<AreaProducto> _areas = [];
  List<CategoriaProducto> _categorias = [];
  final _busqueda = TextEditingController();
  Timer? _espera;
  int? _areaId;
  int? _categoriaId;
  int _pagina = 0;
  int _total = 0;
  bool _ultima = true;

  /// Recargando la lista por un filtro, o pidiendo la página siguiente.
  bool _listando = false;
  bool _cargandoMas = false;
  bool _busy = true;
  String? _error;
  String? _mensaje;
  int _carga = 0;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  @override
  void dispose() {
    _espera?.cancel();
    _busqueda.dispose();
    super.dispose();
  }

  void _fallo(ProductoFailure e) {
    if (e.sesionExpirada) {
      widget.onSesionExpirada();
      return;
    }
    setState(() {
      _error = e.message;
      _busy = false;
    });
  }

  Future<void> _iniciar() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final negocios = widget.negocioInicial == null
          ? await widget.gestion.negocios()
          : [widget.negocioInicial!];
      if (!mounted) return;
      setState(() {
        _negocios = negocios;
        _negocio = negocios.firstOrNull;
      });
      if (_negocio != null) {
        await _cargar(_negocio!);
      } else {
        setState(() => _busy = false);
      }
    } on ProductoFailure catch (e) {
      if (mounted) _fallo(e);
    }
  }

  Future<void> _cargar(
    NegocioProducto negocio, {
    bool conservarMensaje = false,
  }) async {
    final carga = ++_carga;
    setState(() {
      _negocio = negocio;
      _busy = true;
      _error = null;
      if (!conservarMensaje) _mensaje = null;
    });
    try {
      // La clasificación es complementaria: si áreas/categorías no responden
      // se muestran los productos como "Sin clasificar".
      Future<List<T>> opcional<T>(Future<List<T>> consulta) =>
          consulta.catchError((Object e) {
            if (e is ProductoFailure && e.sesionExpirada) throw e;
            return <T>[];
          });
      final resultados = await Future.wait<Object>([
        widget.gestion.listar(
          negocio.id,
          filtro: FiltroProductos(sucursalId: widget.sucursal?.id),
        ),
        opcional(widget.gestion.areas(negocio.id)),
        opcional(widget.gestion.categorias(negocio.id)),
      ]);
      if (!mounted || carga != _carga) return;
      final pagina = resultados[0] as PaginaProductos;
      setState(() {
        _productos = pagina.productos;
        _pagina = pagina.pagina;
        _ultima = pagina.ultima;
        _total = pagina.total;
        _areas = resultados[1] as List<AreaProducto>;
        _categorias = resultados[2] as List<CategoriaProducto>;
        _areaId = null;
        _categoriaId = null;
        _busqueda.clear();
        _busy = false;
      });
    } on ProductoFailure catch (e) {
      if (mounted && carga == _carga) _fallo(e);
    }
  }

  FiltroProductos get _filtroActual => FiltroProductos(
    areaId: _areaId,
    categoriaId: _categoriaId,
    buscar: _busqueda.text,
    sucursalId: widget.sucursal?.id,
  );

  /// Los filtros se aplican en el servidor y reinician la paginación.
  Future<void> _aplicarFiltros() async {
    final negocio = _negocio;
    if (negocio == null) return;
    final carga = ++_carga;
    setState(() {
      _listando = true;
      _error = null;
    });
    try {
      final pagina = await widget.gestion.listar(
        negocio.id,
        filtro: _filtroActual,
      );
      if (!mounted || carga != _carga) return;
      setState(() {
        _productos = pagina.productos;
        _pagina = pagina.pagina;
        _ultima = pagina.ultima;
        _total = pagina.total;
        _listando = false;
      });
    } on ProductoFailure catch (e) {
      if (mounted && carga == _carga) {
        setState(() => _listando = false);
        _fallo(e);
      }
    }
  }

  void _alBuscar(String _) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 400), _aplicarFiltros);
  }

  Future<void> _masProductos() async {
    final negocio = _negocio;
    if (negocio == null || _cargandoMas || _listando || _ultima) return;
    final carga = _carga;
    setState(() => _cargandoMas = true);
    try {
      final pagina = await widget.gestion.listar(
        negocio.id,
        pagina: _pagina + 1,
        filtro: _filtroActual,
      );
      if (!mounted || carga != _carga) return;
      setState(() {
        _productos = [..._productos, ...pagina.productos];
        _pagina = pagina.pagina;
        _ultima = pagina.ultima;
        _total = pagina.total;
        _cargandoMas = false;
      });
    } on ProductoFailure catch (e) {
      if (mounted) {
        setState(() => _cargandoMas = false);
        _fallo(e);
      }
    }
  }

  Future<void> _registrar() async {
    if (_busy || _negocio == null || _error != null) return;
    var registrados = 0;
    final guardado = await Navigator.of(context).push<Producto>(
      MaterialPageRoute(
        builder: (_) => ProductoFormPage(
          negocio: _negocio!,
          gestion: widget.gestion,
          descuentos: widget.descuentos,
          imagenes: widget.imagenes,
          onSesionExpirada: widget.onSesionExpirada,
          sucursal: widget.sucursal,
          onRegistrados: (cantidad) => registrados = cantidad,
        ),
      ),
    );
    if (!mounted || guardado == null) return;
    if (registrados > 1) {
      // Registro por lotes: se vuelve a la lista en lugar de abrir un solo producto.
      _mensaje = '$registrados productos registrados correctamente.';
      await _cargar(_negocio!, conservarMensaje: true);
      return;
    }
    await _abrirDetalle(
      widget.sucursal == null
          ? guardado
          : guardado.soloSucursal(widget.sucursal!.id),
      mensaje: 'Producto guardado correctamente.',
    );
  }

  Future<void> _abrirDetalle(Producto producto, {String? mensaje}) async {
    final eliminado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductoDetallePage(
          negocio: _negocio!,
          producto: producto,
          sucursal: widget.sucursal,
          gestion: widget.gestion,
          descuentos: widget.descuentos,
          imagenes: widget.imagenes,
          onSesionExpirada: widget.onSesionExpirada,
          mensajeInicial: mensaje,
        ),
      ),
    );
    if (!mounted) return;
    if (eliminado == true) _mensaje = 'Producto eliminado correctamente.';
    await _cargar(_negocio!, conservarMensaje: eliminado == true);
  }

  Widget _filtro(
    String texto,
    int? valor,
    List<(int, String)> opciones,
    ValueChanged<int?> onChanged,
  ) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: productoSuave,
      borderRadius: BorderRadius.circular(10),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<int?>(
        value: valor,
        isExpanded: true,
        isDense: true,
        icon: const Icon(
          Icons.keyboard_arrow_down,
          size: 16,
          color: BarroTheme.primary,
        ),
        style: BarroTheme.type(
          11,
          16,
          weight: FontWeight.w700,
          color: BarroTheme.primary,
        ),
        items: [
          DropdownMenuItem<int?>(value: null, child: Text(texto)),
          for (final o in opciones)
            DropdownMenuItem<int?>(
              value: o.$1,
              child: Text(o.$2, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: _busy || _listando ? null : onChanged,
      ),
    ),
  );

  Widget _tarjeta(Producto p) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: BarroTheme.border),
      borderRadius: BorderRadius.circular(21),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => _abrirDetalle(p),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProductoImagen(
              key: ValueKey('producto-imagen-${p.id}'),
              size: 200,
              ancho: double.infinity,
              url: p.imagenUrl,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.nombre,
                    style: BarroTheme.type(18, 25, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatoPrecio(p.precio),
                    style: BarroTheme.type(
                      24,
                      30,
                      weight: FontWeight.w700,
                      color: BarroTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _abrirDetalle(p),
                child: const Text('Ver producto →'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _vacio() => Column(
    children: [
      const SizedBox(height: 56),
      Container(
        width: 96,
        height: 96,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: productoSuave,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          'P',
          style: BarroTheme.type(
            38,
            46,
            weight: FontWeight.w700,
            color: BarroTheme.primary,
          ),
        ),
      ),
      const SizedBox(height: 24),
      Text(
        'Agrega tu primer producto',
        textAlign: TextAlign.center,
        style: BarroTheme.type(20, 28, weight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      Text(
        widget.sucursal != null
            ? 'Registra su precio, clasificación y existencia en esta sucursal para empezar a vender.'
            : 'Registra su precio, clasificación y la existencia en cada sucursal para empezar a vender.',
        textAlign: TextAlign.center,
        style: BarroTheme.type(14, 22, color: BarroTheme.secondary),
      ),
      const SizedBox(height: 32),
      ProductoBoton(
        texto: 'Registrar mi primer producto',
        onPressed: _registrar,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final vacioTotal =
        !_busy && _error == null && _negocio != null && _productos.isEmpty;
    final categoriasVisibles = _categorias
        .where((c) => _areaId == null || c.areaId == _areaId)
        .toList();
    return ProductoScaffold(
      // El menú solo aparece al administrar una sucursal, no en el catálogo del negocio.
      barraInferior: widget.sucursal == null
          ? null
          : SucursalNavegacion(
              seleccionada: 'Inventario',
              onInicio:
                  widget.onInicio ?? () => Navigator.of(context).maybePop(),
              onPedidos: widget.onPedidos,
            ),
      onRefresh: _busy
          ? () async {}
          : () {
              widget.gestion.descartarCache();
              return _iniciar();
            },
      children: [
        const SizedBox(height: 20),
        if (_negocio != null) ...[
          ProductoNegocioPanel(
            negocio: _negocio!,
            negocios: _negocios,
            onChanged: _busy ? null : _cargar,
          ),
          const SizedBox(height: 20),
        ],
        Text(
          'Productos',
          style: BarroTheme.type(34, 43, weight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          widget.sucursal != null
              ? 'Productos de ${widget.sucursal!.nombre}.'
              : vacioTotal
              ? 'Tu catálogo, organizado por negocio.'
              : 'Administra el catálogo y la existencia por sucursal.',
          style: BarroTheme.type(14, 22, color: BarroTheme.secondary),
        ),
        const SizedBox(height: 20),
        if (_mensaje != null) ...[
          ProductoAviso(_mensaje!),
          const SizedBox(height: 20),
        ],
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null) ...[
          ProductoAviso(_error!, error: true),
          Center(
            child: TextButton(
              onPressed: _iniciar,
              child: const Text('Reintentar'),
            ),
          ),
        ] else if (_negocio == null)
          const ProductoAviso(
            'Aún no tienes negocios vinculados. Registra un negocio para gestionar su catálogo.',
          )
        else if (vacioTotal)
          _vacio()
        else ...[
          TextField(
            key: const ValueKey('producto-busqueda'),
            controller: _busqueda,
            style: BarroTheme.type(14, 21),
            decoration: productoDecoracion(hint: 'Buscar producto...'),
            onChanged: _alBuscar,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _filtro(
                  'Todas las áreas',
                  _areaId,
                  [for (final a in _areas) (a.id, a.nombre)],
                  (id) {
                    setState(() {
                      _areaId = id;
                      _categoriaId = null;
                    });
                    _aplicarFiltros();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _filtro(
                  'Todas las categorías',
                  _categoriaId,
                  [for (final c in categoriasVisibles) (c.id, c.nombre)],
                  (id) {
                    setState(() => _categoriaId = id);
                    _aplicarFiltros();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ProductoBoton(texto: '+ Registrar producto', onPressed: _registrar),
          const SizedBox(height: 20),
          Text(
            '$_total ${_total == 1 ? 'producto registrado' : 'productos registrados'}',
            style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
          ),
          const SizedBox(height: 16),
          if (_listando)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (_productos.isEmpty)
              const ProductoAviso('Ningún producto coincide con tu búsqueda.'),
            for (final p in _productos) _tarjeta(p),
            if (!_ultima)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _cargandoMas
                    ? const Center(child: CircularProgressIndicator())
                    : OutlinedButton(
                        key: const ValueKey('productos-ver-mas'),
                        onPressed: _masProductos,
                        child: const Text('Ver más productos'),
                      ),
              ),
          ],
        ],
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Volver'),
          ),
        ),
      ],
    );
  }
}
