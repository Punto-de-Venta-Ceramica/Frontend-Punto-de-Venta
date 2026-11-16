import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_widgets.dart';
import '../../../../domain/descuento.dart';

/// Abre la hoja para elegir el producto al que se asigna un descuento, con
/// búsqueda por nombre y filtros de área y categoría. Devuelve el producto
/// elegido o null si se cierra sin elegir.
Future<ElementoCatalogo?> seleccionarProductoDescuento(
  BuildContext context, {
  required List<ElementoCatalogo> productos,
}) => showModalBottomSheet<ElementoCatalogo>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  constraints: const BoxConstraints(maxWidth: 480),
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  clipBehavior: Clip.antiAlias,
  builder: (_) => _SelectorProductoDescuento(productos: productos),
);

class _SelectorProductoDescuento extends StatefulWidget {
  const _SelectorProductoDescuento({required this.productos});
  final List<ElementoCatalogo> productos;

  @override
  State<_SelectorProductoDescuento> createState() =>
      _SelectorProductoDescuentoState();
}

class _SelectorProductoDescuentoState
    extends State<_SelectorProductoDescuento> {
  final _busqueda = TextEditingController();
  late final List<ElementoCatalogo> _ordenados = List.of(widget.productos)
    ..sort((a, b) {
      final orden = claveBusqueda(a.nombre).compareTo(claveBusqueda(b.nombre));
      return orden != 0 ? orden : a.id.compareTo(b.id);
    });
  int? _areaId, _categoriaId;

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  /// Opciones (id, nombre) únicas, ordenadas por nombre.
  List<(int, String)> _opciones(
    Iterable<ElementoCatalogo> productos,
    (int, String)? Function(ElementoCatalogo) opcion,
  ) {
    final unicas = <int, String>{};
    for (final p in productos) {
      final o = opcion(p);
      if (o != null) unicas[o.$1] = o.$2;
    }
    return [for (final e in unicas.entries) (e.key, e.value)]
      ..sort((a, b) => claveBusqueda(a.$2).compareTo(claveBusqueda(b.$2)));
  }

  List<(int, String)> get _areas => _opciones(
    _ordenados,
    (p) => p.areaId == null ? null : (p.areaId!, p.area ?? 'Sin nombre'),
  );

  List<(int, String)> get _categorias => _opciones(
    _ordenados.where((p) => _areaId == null || p.areaId == _areaId),
    (p) => p.categoriaId == null
        ? null
        : (p.categoriaId!, p.categoria ?? 'Sin nombre'),
  );

  bool get _hayFiltros =>
      _busqueda.text.trim().isNotEmpty ||
      _areaId != null ||
      _categoriaId != null;

  void _limpiarFiltros() => setState(() {
    _busqueda.clear();
    _areaId = null;
    _categoriaId = null;
  });

  void _soltarTeclado() => FocusManager.instance.primaryFocus?.unfocus();

  @override
  Widget build(BuildContext context) {
    final texto = claveBusqueda(_busqueda.text);
    final coincidencias = [
      for (final p in _ordenados)
        if ((_areaId == null || p.areaId == _areaId) &&
            (_categoriaId == null || p.categoriaId == _categoriaId) &&
            claveBusqueda(p.nombre).contains(texto))
          p,
    ];
    final areas = _areas;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: BarroTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            _encabezado(),
            if (widget.productos.isEmpty)
              Expanded(
                child: _Vacio(
                  icono: Icons.inventory_2_outlined,
                  titulo: 'No hay más productos para asignar.',
                  detalle: 'Todos los productos ya tienen este descuento.',
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: TextField(
                  key: const ValueKey('descuento-selector-busqueda'),
                  controller: _busqueda,
                  textInputAction: TextInputAction.search,
                  style: BarroTheme.type(14, 21),
                  decoration: productoDecoracion(hint: 'Buscar producto...')
                      .copyWith(
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 22,
                          color: BarroTheme.primary,
                        ),
                        suffixIcon: _busqueda.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Limpiar búsqueda',
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () =>
                                    setState(() => _busqueda.clear()),
                              ),
                      ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (areas.isNotEmpty) _filtros(areas),
              _conteo(coincidencias.length),
              const Divider(height: 1, color: BarroTheme.border),
              Expanded(
                child: coincidencias.isEmpty
                    ? const _Vacio(
                        icono: Icons.search_off_rounded,
                        titulo: 'No se encontraron productos.',
                        detalle: 'Prueba con otro nombre o quita los filtros.',
                      )
                    : ListView.separated(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                        itemCount: coincidencias.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (_, i) => _fila(coincidencias[i]),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _encabezado() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Asignar producto',
                style: BarroTheme.type(20, 28, weight: FontWeight.w700),
              ),
              Text(
                'Busca por nombre o filtra por área y categoría.',
                style: BarroTheme.type(13, 19, color: BarroTheme.secondary),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Cerrar',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    ),
  );

  Widget _filtros(List<(int, String)> areas) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
    child: Row(
      children: [
        Expanded(
          child: ProductoFiltroDesplegable(
            key: ValueKey('descuento-filtro-area-$_areaId'),
            texto: 'Todas las áreas',
            textoBuscador: 'Buscar área...',
            valor: _areaId,
            opciones: areas,
            icono: Icons.grid_view_outlined,
            onAntesDeAbrir: _soltarTeclado,
            onChanged: (id) => setState(() {
              _areaId = id;
              _categoriaId = null;
            }),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ProductoFiltroDesplegable(
            key: ValueKey('descuento-filtro-categoria-$_areaId-$_categoriaId'),
            texto: 'Todas las categorías',
            textoBuscador: 'Buscar categoría...',
            valor: _categoriaId,
            opciones: _categorias,
            icono: Icons.label_outline,
            conBuscador: true,
            onAntesDeAbrir: _soltarTeclado,
            onChanged: (id) => setState(() => _categoriaId = id),
          ),
        ),
      ],
    ),
  );

  Widget _conteo(int total) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 12, 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            total == 1 ? '1 producto' : '$total productos',
            style: BarroTheme.type(
              12,
              18,
              weight: FontWeight.w700,
              color: BarroTheme.secondary,
            ),
          ),
        ),
        if (_hayFiltros)
          TextButton(
            onPressed: _limpiarFiltros,
            child: const Text('Limpiar filtros'),
          ),
      ],
    ),
  );

  Widget _fila(ElementoCatalogo p) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: BarroTheme.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: ValueKey('descuento-opcion-${p.id}'),
      onTap: () => Navigator.pop(context, p),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ProductoImagen(size: 52, url: p.imagenUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: BarroTheme.type(15, 21, weight: FontWeight.w700),
                  ),
                  if (p.contexto.isNotEmpty)
                    Text(
                      p.contexto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BarroTheme.type(
                        12,
                        18,
                        color: BarroTheme.secondary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.add_circle_outline, color: BarroTheme.primary),
          ],
        ),
      ),
    ),
  );
}

class _Vacio extends StatelessWidget {
  const _Vacio({
    required this.icono,
    required this.titulo,
    required this.detalle,
  });
  final IconData icono;
  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 40, color: BarroTheme.placeholder),
          const SizedBox(height: 10),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: BarroTheme.type(15, 22, weight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            detalle,
            textAlign: TextAlign.center,
            style: BarroTheme.type(13, 19, color: BarroTheme.secondary),
          ),
        ],
      ),
    ),
  );
}
