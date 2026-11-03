import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import '../../../../application/ports/inbound/gestion_productos_use_case.dart';
import '../../../../domain/producto.dart';
import 'producto_detalle_page.dart';
import 'producto_form_page.dart';
import 'producto_widgets.dart';

class ProductosPage extends StatefulWidget {
  const ProductosPage({
    required this.gestion,
    required this.onSesionExpirada,
    this.negocioInicial,
    super.key,
  });
  final GestionProductosUseCase gestion;
  final VoidCallback onSesionExpirada;
  final NegocioProducto? negocioInicial;
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
  int? _areaId;
  int? _categoriaId;
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
        widget.gestion.listar(negocio.id),
        opcional(widget.gestion.areas(negocio.id)),
        opcional(widget.gestion.categorias(negocio.id)),
      ]);
      if (!mounted || carga != _carga) return;
      setState(() {
        _productos = resultados[0] as List<Producto>;
        _areas = resultados[1] as List<AreaProducto>;
        _categorias = resultados[2] as List<CategoriaProducto>;
        _areaId = null;
        _categoriaId = null;
        _busy = false;
      });
    } on ProductoFailure catch (e) {
      if (mounted && carga == _carga) _fallo(e);
    }
  }

  CategoriaProducto? _categoria(int id) =>
      _categorias.where((c) => c.id == id).firstOrNull;

  String _clasificacion(Producto p) {
    final categoria = _categoria(p.categoriaId);
    if (categoria == null) return 'Sin clasificar';
    final area = _areas.where((a) => a.id == categoria.areaId).firstOrNull;
    return [if (area != null) area.nombre, categoria.nombre].join(' · ');
  }

  List<Producto> get _filtrados {
    final texto = _busqueda.text.trim().toLowerCase();
    return _productos.where((p) {
      final categoria = _categoria(p.categoriaId);
      if (texto.isNotEmpty && !p.nombre.toLowerCase().contains(texto)) {
        return false;
      }
      if (_areaId != null && categoria?.areaId != _areaId) return false;
      if (_categoriaId != null && p.categoriaId != _categoriaId) return false;
      return true;
    }).toList();
  }

  Future<void> _registrar() async {
    if (_busy || _negocio == null || _error != null) return;
    final guardado = await Navigator.of(context).push<Producto>(
      MaterialPageRoute(
        builder: (_) => ProductoFormPage(
          negocio: _negocio!,
          gestion: widget.gestion,
          onSesionExpirada: widget.onSesionExpirada,
        ),
      ),
    );
    if (!mounted || guardado == null) return;
    await _abrirDetalle(guardado, mensaje: 'Producto guardado correctamente.');
  }

  Future<void> _abrirDetalle(Producto producto, {String? mensaje}) async {
    final eliminado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductoDetallePage(
          negocio: _negocio!,
          producto: producto,
          gestion: widget.gestion,
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
        onChanged: _busy ? null : onChanged,
      ),
    ),
  );

  Widget _tarjeta(Producto p) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: BarroTheme.border),
      borderRadius: BorderRadius.circular(21),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(p.nombre, style: BarroTheme.type(16, 23, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          _clasificacion(p),
          style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              formatoPrecio(p.precio),
              style: BarroTheme.type(
                24,
                30,
                weight: FontWeight.w700,
                color: BarroTheme.primary,
              ),
            ),
            Text(
              formatoPiezas(p.existenciaTotal),
              style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
            ),
          ],
        ),
        if (p.descuento != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: productoSuave,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              p.descuento!.resumen,
              style: BarroTheme.type(
                11,
                16,
                weight: FontWeight.w700,
                color: BarroTheme.primary,
              ),
            ),
          ),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _abrirDetalle(p),
            child: const Text('Ver producto →'),
          ),
        ),
      ],
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
        'Registra su precio, clasificación y existencias para empezar a vender.',
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
    final filtrados = _filtrados;
    final categoriasVisibles = _categorias
        .where((c) => _areaId == null || c.areaId == _areaId)
        .toList();
    return ProductoScaffold(
      navegacion: true,
      onRefresh: _busy ? () async {} : _iniciar,
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
          vacioTotal
              ? 'Tu catálogo, organizado por negocio.'
              : 'Administra el catálogo de tu negocio.',
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
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _filtro(
                  'Todas las áreas',
                  _areaId,
                  [for (final a in _areas) (a.id, a.nombre)],
                  (id) => setState(() {
                    _areaId = id;
                    _categoriaId = null;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _filtro('Todas las categorías', _categoriaId, [
                  for (final c in categoriasVisibles) (c.id, c.nombre),
                ], (id) => setState(() => _categoriaId = id)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ProductoBoton(texto: '+ Registrar producto', onPressed: _registrar),
          const SizedBox(height: 20),
          Text(
            '${filtrados.length} ${filtrados.length == 1 ? 'producto registrado' : 'productos registrados'}',
            style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
          ),
          const SizedBox(height: 16),
          if (filtrados.isEmpty)
            const ProductoAviso('Ningún producto coincide con tu búsqueda.'),
          for (final p in filtrados) _tarjeta(p),
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
