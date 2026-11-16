import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:punto_de_venta/core/infrastructure/services/notificacion_servicio.dart';
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
    this.onCaja,
    this.descuentos,
    this.imagenes,
    this.soloLectura = false,
    this.puedeRegistrar = false,
    super.key,
  });
  final GestionProductosUseCase gestion;

  /// Vista del empleado: mismo listado y detalle, sin editar ni eliminar
  /// productos; solo ajusta existencias de su sucursal (y registra, si
  /// [puedeRegistrar]).
  final bool soloLectura;

  /// Con [soloLectura] (empleado) permite además registrar productos en su
  /// sucursal. Editar y eliminar siguen siendo exclusivos del propietario.
  final bool puedeRegistrar;

  bool get _registra => !soloLectura || puedeRegistrar;

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
  final VoidCallback? onCaja;
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
  final _precioMin = TextEditingController();
  final _precioMax = TextEditingController();
  String? _errorPrecio;
  Timer? _espera;
  int? _areaId;
  int? _categoriaId;

  /// Solo en modo negocio: sucursales para filtrar el catálogo por sucursal.
  List<SucursalProducto> _sucursales = [];
  int? _sucursalFiltroId;
  int _pagina = 0;
  int _total = 0;
  bool _ultima = true;

  /// Recargando la lista por un filtro, o pidiendo la página siguiente.
  bool _listando = false;

  /// El servidor confirmó que no hay ningún producto (consulta sin búsqueda ni
  /// filtros). Solo entonces se muestra la pantalla de «primer producto»: una
  /// búsqueda o un filtro sin resultados nunca la activa, aunque mientras llega
  /// la respuesta la lista siga vacía por la consulta anterior.
  bool _catalogoVacio = false;
  bool _cargandoMas = false;
  bool _busy = true;
  String? _error;
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
    _precioMin.dispose();
    _precioMax.dispose();
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

  Future<void> _cargar(NegocioProducto negocio) async {
    final carga = ++_carga;
    setState(() {
      _negocio = negocio;
      _busy = true;
      _error = null;
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
        // Con sucursal fija (administrar sucursal o empleado) no hay selector.
        if (widget.sucursal == null)
          opcional(widget.gestion.sucursales(negocio.id)),
      ]);
      if (!mounted || carga != _carga) return;
      final pagina = resultados[0] as PaginaProductos;
      setState(() {
        _productos = pagina.productos;
        _catalogoVacio = pagina.productos.isEmpty;
        _pagina = pagina.pagina;
        _ultima = pagina.ultima;
        _total = pagina.total;
        _areas = resultados[1] as List<AreaProducto>;
        _categorias = resultados[2] as List<CategoriaProducto>;
        _sucursales = widget.sucursal == null
            ? resultados[3] as List<SucursalProducto>
            : const [];
        _areaId = null;
        _sucursalFiltroId = null;
        _categoriaId = null;
        _busqueda.clear();
        _busquedaConTexto = false;
        _precioMin.clear();
        _precioMax.clear();
        _errorPrecio = null;
        _busy = false;
      });
    } on ProductoFailure catch (e) {
      if (mounted && carga == _carga) _fallo(e);
    }
  }

  /// Al volver del detalle o del registro: se actualiza solo la lista, en
  /// silencio. No hay pantalla de carga, se conserva el scroll, y la búsqueda y
  /// los filtros siguen aplicados; áreas, categorías y sucursales no cambian
  /// desde esas pantallas, así que no se vuelven a pedir.
  Future<void> _refrescar() async {
    final negocio = _negocio;
    if (negocio == null) return;
    final carga = ++_carga;
    final filtro = _filtroActual;
    try {
      final pagina = await widget.gestion.listar(negocio.id, filtro: filtro);
      if (!mounted || carga != _carga) return;
      setState(() {
        _productos = pagina.productos;
        _actualizarCatalogoVacio(filtro, pagina);
        _pagina = pagina.pagina;
        _ultima = pagina.ultima;
        _total = pagina.total;
        _listando = false;
      });
    } on ProductoFailure catch (e) {
      if (mounted && carga == _carga) _fallo(e);
    }
  }

  FiltroProductos get _filtroActual => FiltroProductos(
    areaId: _areaId,
    categoriaId: _categoriaId,
    buscar: _busqueda.text,
    sucursalId: widget.sucursal?.id ?? _sucursalFiltroId,
    precioMinimo: _precio(_precioMin),
    precioMaximo: _precio(_precioMax),
  );

  /// Si la consulta no llevaba búsqueda ni filtros del usuario (la sucursal
  /// fija de la pantalla no cuenta como filtro).
  bool _consultaSinFiltros(FiltroProductos f) =>
      f.buscar.isEmpty &&
      f.areaId == null &&
      f.categoriaId == null &&
      f.precioMinimo == null &&
      f.precioMaximo == null &&
      f.sucursalId == widget.sucursal?.id;

  /// Solo una consulta sin filtros dice si el catálogo está vacío; cualquier
  /// resultado con productos confirma que no lo está.
  void _actualizarCatalogoVacio(FiltroProductos filtro, PaginaProductos p) {
    if (_consultaSinFiltros(filtro)) {
      _catalogoVacio = p.productos.isEmpty;
    } else if (p.productos.isNotEmpty) {
      _catalogoVacio = false;
    }
  }

  static double? _precio(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  /// Espera a que termine de escribir; un rango invertido no se consulta.
  void _alCambiarPrecio(String _) {
    _espera?.cancel();
    final min = _precio(_precioMin);
    final max = _precio(_precioMax);
    final error = min != null && max != null && min > max
        ? 'El precio mínimo no puede ser mayor que el máximo.'
        : null;
    if (error != _errorPrecio) setState(() => _errorPrecio = error);
    if (error == null) {
      _espera = Timer(const Duration(milliseconds: 500), _aplicarFiltros);
    }
  }

  Widget _campoPrecio(String hint, TextEditingController c, String clave) =>
      TextField(
        key: ValueKey(clave),
        controller: c,
        enabled: !_busy,
        style: BarroTheme.type(14, 21),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d{0,9}([.,]\d{0,2})?')),
        ],
        decoration: productoDecoracion(hint: hint).copyWith(
          prefixIcon: Icon(
            hint.contains('mín') ? Icons.arrow_downward : Icons.arrow_upward,
            size: 18,
            color: BarroTheme.primary,
          ),
          prefixText: '\$ ',
        ),
        onChanged: _alCambiarPrecio,
      );

  /// Los filtros se aplican en el servidor y reinician la paginación.
  Future<void> _aplicarFiltros() async {
    final negocio = _negocio;
    if (negocio == null) return;
    final carga = ++_carga;
    final filtro = _filtroActual;
    setState(() {
      _listando = true;
      _error = null;
    });
    try {
      final pagina = await widget.gestion.listar(negocio.id, filtro: filtro);
      if (!mounted || carga != _carga) return;
      setState(() {
        _productos = pagina.productos;
        _actualizarCatalogoVacio(filtro, pagina);
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

  bool _busquedaConTexto = false;

  void _alBuscar(String texto) {
    _espera?.cancel();
    // Solo se reconstruye la pantalla cuando aparece o desaparece el botón de
    // limpiar (no en cada tecla): evita repintar todas las tarjetas al escribir.
    final conTexto = texto.isNotEmpty;
    if (conTexto != _busquedaConTexto) {
      setState(() => _busquedaConTexto = conTexto);
    }
    _espera = Timer(const Duration(milliseconds: 400), _aplicarFiltros);
  }

  bool get _hayFiltros =>
      _busqueda.text.isNotEmpty ||
      _areaId != null ||
      _categoriaId != null ||
      _sucursalFiltroId != null ||
      _precioMin.text.isNotEmpty ||
      _precioMax.text.isNotEmpty;

  /// Quita la búsqueda y todos los filtros y recarga la lista completa.
  void _limpiarFiltros() {
    _espera?.cancel();
    _quitarFoco();
    setState(() {
      _busqueda.clear();
      _busquedaConTexto = false;
      _precioMin.clear();
      _precioMax.clear();
      _areaId = null;
      _categoriaId = null;
      _sucursalFiltroId = null;
      _errorPrecio = null;
    });
    _aplicarFiltros();
  }

  /// Aviso cuando la búsqueda o los filtros aplicados no traen productos.
  Widget _sinResultados() => Container(
    key: const ValueKey('productos-sin-resultados'),
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: BarroTheme.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        const Icon(Icons.search_off, size: 40, color: BarroTheme.primary),
        const SizedBox(height: 12),
        Text(
          'No hay productos con estos filtros',
          textAlign: TextAlign.center,
          style: BarroTheme.type(16, 24, weight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Prueba con otra búsqueda o cambia los filtros aplicados.',
          textAlign: TextAlign.center,
          style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
        ),
        if (_hayFiltros) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _limpiarFiltros,
            icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
            label: const Text('Limpiar filtros'),
          ),
        ],
      ],
    ),
  );

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
    if (!widget._registra || _busy || _negocio == null || _error != null) {
      return;
    }
    var registrados = 0;
    _quitarFoco();
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
    _quitarFoco();
    if (!mounted || guardado == null) return;
    if (registrados > 1) {
      // Registro por lotes: se vuelve a la lista en lugar de abrir un solo producto.
      NotificacionServicio.registro(
        context,
        '$registrados productos registrados correctamente.',
      );
      await _refrescar();
      return;
    }
    // El formulario ya avisó del registro de este producto.
    await _abrirDetalle(
      widget.sucursal == null
          ? guardado
          : guardado.soloSucursal(widget.sucursal!.id),
    );
  }

  Future<void> _abrirDetalle(Producto producto) async {
    // Sin foco al salir, Flutter no devuelve el cursor (ni el teclado) al buscador.
    _quitarFoco();
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
          soloLectura: widget.soloLectura,
        ),
      ),
    );
    _quitarFoco();
    if (!mounted) return;
    if (eliminado == true) {
      NotificacionServicio.eliminacion(
        context,
        'Producto eliminado correctamente.',
      );
    }
    await _refrescar();
  }

  /// Flutter devuelve el foco al campo que lo tenía al cerrar un menú o volver
  /// de otra pantalla, y con él reaparece el teclado. Se suelta el foco antes de
  /// abrir y, tras cerrar, en el siguiente frame.
  void _quitarFoco() {
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => FocusManager.instance.primaryFocus?.unfocus(),
    );
  }

  Widget _filtro(
    String texto,
    int? valor,
    List<(int, String)> opciones,
    ValueChanged<int?> onChanged,
    IconData icono,
  ) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: productoSuave,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(icono, size: 16, color: BarroTheme.primary),
        const SizedBox(width: 6),
        Expanded(child: _desplegable(texto, valor, opciones, onChanged)),
      ],
    ),
  );

  Widget _desplegable(
    String texto,
    int? valor,
    List<(int, String)> opciones,
    ValueChanged<int?> onChanged,
  ) => DropdownButtonHideUnderline(
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
      onTap: _quitarFoco,
      onChanged: _busy || _listando ? null : onChanged,
    ),
  );

  /// Desplegable de filtro con diseño propio. Con [conBuscador] muestra un
  /// campo para filtrar por nombre en el cliente (la lista ya viene completa).
  /// El botón "x" limpia el filtro (equivale a "Todas ...").
  Widget _filtroDesplegable({
    required Key key,
    required String texto,
    required String textoBuscador,
    required int? valor,
    required List<(int, String)> opciones,
    required ValueChanged<int?> onChanged,
    required IconData icono,
    bool conBuscador = false,
  }) => ProductoFiltroDesplegable(
    key: key,
    texto: texto,
    textoBuscador: textoBuscador,
    valor: valor,
    opciones: opciones,
    onChanged: (id) {
      onChanged(id);
      _quitarFoco();
    },
    icono: icono,
    conBuscador: conBuscador,
    habilitado: !(_busy || _listando),
    onAntesDeAbrir: _quitarFoco,
  );

  Widget _tarjeta(Producto p) => RepaintBoundary(
    key: ValueKey('producto-tarjeta-${p.id}'),
    child: _tarjetaContenido(p),
  );

  Widget _tarjetaContenido(Producto p) => Container(
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
        widget.soloLectura && !widget.puedeRegistrar
            ? 'Esta sucursal aún no tiene productos'
            : 'Agrega tu primer producto',
        textAlign: TextAlign.center,
        style: BarroTheme.type(20, 28, weight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      if (widget._registra) ...[
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
    ],
  );

  @override
  Widget build(BuildContext context) {
    // Solo es "catálogo vacío" si el servidor lo confirmó sin filtros. Con una
    // búsqueda o filtro sin resultados (o mientras se recarga tras quitarlos)
    // se mantiene la pantalla de filtros y se avisa que no hay coincidencias.
    final vacioTotal =
        !_busy &&
        _error == null &&
        _negocio != null &&
        _catalogoVacio &&
        _productos.isEmpty &&
        !_hayFiltros;
    final categoriasVisibles = _categorias
        .where((c) => _areaId == null || c.areaId == _areaId)
        .toList();
    return ProductoScaffold(
      // El menú solo aparece al administrar una sucursal, no en el catálogo del negocio.
      barraInferior: widget.sucursal == null || widget.soloLectura
          ? null
          : SucursalNavegacion(
              seleccionada: 'Inventario',
              onInicio:
                  widget.onInicio ?? () => Navigator.of(context).maybePop(),
              onPedidos: widget.onPedidos,
              onCaja: widget.onCaja,
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
            sucursal: widget.sucursal?.nombre,
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
            decoration: productoDecoracion(hint: 'Buscar producto...').copyWith(
              prefixIcon: const Icon(
                Icons.search,
                size: 22,
                color: BarroTheme.primary,
              ),
              suffixIcon: !_busquedaConTexto
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar búsqueda',
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _busy
                          ? null
                          : () {
                              _busqueda.clear();
                              _alBuscar('');
                            },
                    ),
            ),
            onChanged: _alBuscar,
          ),
          const SizedBox(height: 12),
          if (widget.sucursal == null && _sucursales.isNotEmpty) ...[
            _filtro(
              'Todas las sucursales',
              _sucursalFiltroId,
              [for (final s in _sucursales) (s.id, s.nombre)],
              (id) {
                setState(() => _sucursalFiltroId = id);
                _aplicarFiltros();
              },
              Icons.storefront_outlined,
            ),
            const SizedBox(height: 12),
          ],
          _filtroDesplegable(
            key: ValueKey('filtro-area-$_areaId'),
            texto: 'Todas las áreas',
            textoBuscador: 'Buscar área...',
            valor: _areaId,
            opciones: [for (final a in _areas) (a.id, a.nombre)],
            onChanged: (id) {
              setState(() {
                _areaId = id;
                _categoriaId = null;
              });
              _aplicarFiltros();
            },
            icono: Icons.grid_view_outlined,
          ),
          const SizedBox(height: 12),
          _filtroDesplegable(
            key: ValueKey('filtro-categoria-$_areaId-$_categoriaId'),
            texto: 'Todas las categorías',
            textoBuscador: 'Buscar categoría...',
            valor: _categoriaId,
            opciones: [for (final c in categoriasVisibles) (c.id, c.nombre)],
            onChanged: (id) {
              setState(() => _categoriaId = id);
              _aplicarFiltros();
            },
            icono: Icons.label_outline,
            conBuscador: true,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _campoPrecio('Precio mín.', _precioMin, 'precio-min'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _campoPrecio('Precio máx.', _precioMax, 'precio-max'),
              ),
            ],
          ),
          if (_errorPrecio != null) ...[
            const SizedBox(height: 6),
            Text(
              _errorPrecio!,
              style: BarroTheme.type(12, 18, color: BarroTheme.error),
            ),
          ],
          if (_hayFiltros) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const ValueKey('limpiar-filtros'),
                onPressed: _busy || _listando ? null : _limpiarFiltros,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: const Text('Limpiar filtros'),
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (widget._registra) ...[
            ProductoBoton(texto: '+ Registrar producto', onPressed: _registrar),
            const SizedBox(height: 20),
          ] else
            const SizedBox(height: 4),
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
            if (_productos.isEmpty) _sinResultados(),
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
        // El empleado llega por la barra inferior: no hay pantalla a la que volver.
        if (!widget.soloLectura) ...[
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver'),
            ),
          ),
        ],
      ],
    );
  }
}
