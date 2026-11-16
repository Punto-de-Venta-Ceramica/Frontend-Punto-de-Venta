import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_widgets.dart';
import '../../../domain/pedido.dart';

/// Clave para ordenar y buscar sin distinguir mayúsculas ni acentos.
String claveProductoPedido(String texto) => texto
    .trim()
    .toLowerCase()
    .replaceAll(RegExp('[áàäâ]'), 'a')
    .replaceAll(RegExp('[éèëê]'), 'e')
    .replaceAll(RegExp('[íìïî]'), 'i')
    .replaceAll(RegExp('[óòöô]'), 'o')
    .replaceAll(RegExp('[úùüû]'), 'u')
    .replaceAll('ñ', 'n{');

/// Abre la hoja para elegir un producto del catálogo. Devuelve el id elegido o
/// null si se cierra sin elegir. Los productos de [agregados] ya están en el
/// pedido: se muestran marcados y no se pueden volver a elegir.
Future<int?> seleccionarProductoPedido(
  BuildContext context, {
  required List<ProductoPedido> productos,
  required Map<int, int> agregados,
  int? seleccionado,
}) => showModalBottomSheet<int>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  // Mismo ancho máximo que el contenido de la app (ProductoScaffold): sin este
  // límite, en pantallas anchas la hoja se extiende hasta 640 px.
  constraints: const BoxConstraints(maxWidth: 480),
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  clipBehavior: Clip.antiAlias,
  builder: (_) => _SelectorProductoPedido(
    productos: productos,
    agregados: agregados,
    seleccionado: seleccionado,
  ),
);

class _SelectorProductoPedido extends StatefulWidget {
  const _SelectorProductoPedido({
    required this.productos,
    required this.agregados,
    this.seleccionado,
  });
  final List<ProductoPedido> productos;
  final Map<int, int> agregados;
  final int? seleccionado;

  @override
  State<_SelectorProductoPedido> createState() =>
      _SelectorProductoPedidoState();
}

class _SelectorProductoPedidoState extends State<_SelectorProductoPedido> {
  final _busqueda = TextEditingController();
  late final List<ProductoPedido> _ordenados;
  int? _areaId, _categoriaId;

  @override
  void initState() {
    super.initState();
    _ordenados = List.of(widget.productos)
      ..sort((a, b) {
        final orden = claveProductoPedido(
          a.nombre,
        ).compareTo(claveProductoPedido(b.nombre));
        return orden != 0 ? orden : a.id.compareTo(b.id);
      });
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  /// Opciones (id, nombre) únicas, ordenadas por nombre.
  List<(int, String)> _opciones(
    Iterable<ProductoPedido> productos,
    (int, String)? Function(ProductoPedido) opcion,
  ) {
    final unicas = <int, String>{};
    for (final p in productos) {
      final o = opcion(p);
      if (o != null) unicas[o.$1] = o.$2;
    }
    return [for (final e in unicas.entries) (e.key, e.value)]..sort(
      (a, b) => claveProductoPedido(a.$2).compareTo(claveProductoPedido(b.$2)),
    );
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

  @override
  Widget build(BuildContext context) {
    final texto = claveProductoPedido(_busqueda.text);
    final coincidencias = _ordenados
        .where(
          (p) =>
              (_areaId == null || p.areaId == _areaId) &&
              (_categoriaId == null || p.categoriaId == _categoriaId) &&
              claveProductoPedido(p.nombre).contains(texto),
        )
        .toList();
    final areas = _areas;
    final conFiltros = areas.isNotEmpty;
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Elegir producto',
                          style: BarroTheme.type(
                            20,
                            28,
                            weight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Busca por nombre o filtra por área y categoría.',
                          style: BarroTheme.type(
                            13,
                            19,
                            color: BarroTheme.secondary,
                          ),
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
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: TextField(
                key: const ValueKey('pedido-buscar-producto'),
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
            if (conFiltros)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: ProductoFiltroDesplegable(
                        key: ValueKey('pedido-filtro-area-$_areaId'),
                        texto: 'Todas las áreas',
                        textoBuscador: 'Buscar área...',
                        valor: _areaId,
                        opciones: areas,
                        icono: Icons.grid_view_outlined,
                        onAntesDeAbrir: () =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        onChanged: (id) => setState(() {
                          _areaId = id;
                          _categoriaId = null;
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ProductoFiltroDesplegable(
                        key: ValueKey(
                          'pedido-filtro-categoria-$_areaId-$_categoriaId',
                        ),
                        texto: 'Todas las categorías',
                        textoBuscador: 'Buscar categoría...',
                        valor: _categoriaId,
                        opciones: _categorias,
                        icono: Icons.label_outline,
                        conBuscador: true,
                        onAntesDeAbrir: () =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        onChanged: (id) => setState(() => _categoriaId = id),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      coincidencias.length == 1
                          ? '1 producto'
                          : '${coincidencias.length} productos',
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
            ),
            const Divider(height: 1, color: BarroTheme.border),
            Expanded(
              child: coincidencias.isEmpty
                  ? _sinResultados()
                  : ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                      itemCount: coincidencias.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, i) => _fila(coincidencias[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sinResultados() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 40,
            color: BarroTheme.placeholder,
          ),
          const SizedBox(height: 10),
          Text(
            'No se encontraron productos.',
            textAlign: TextAlign.center,
            style: BarroTheme.type(15, 22, weight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Prueba con otro nombre o quita los filtros.',
            textAlign: TextAlign.center,
            style: BarroTheme.type(13, 19, color: BarroTheme.secondary),
          ),
        ],
      ),
    ),
  );

  Widget _fila(ProductoPedido p) {
    final enPedido = widget.agregados[p.id];
    final elegido = p.id == widget.seleccionado;
    final ubicacion = [
      p.area,
      p.categoria,
    ].whereType<String>().where((t) => t.trim().isNotEmpty).join(' · ');
    final mayoreo = p.descuentos.isNotEmpty && p.siguienteEscalon(0) != null;
    return Material(
      color: elegido ? productoSuave : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: elegido ? BarroTheme.primary : BarroTheme.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('pedido-opcion-producto-${p.id}'),
        onTap: enPedido != null ? null : () => Navigator.pop(context, p.id),
        child: Opacity(
          opacity: enPedido != null ? 0.6 : 1,
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
                      if (ubicacion.isNotEmpty)
                        Text(
                          ubicacion,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BarroTheme.type(
                            12,
                            18,
                            color: BarroTheme.secondary,
                          ),
                        ),
                      if (enPedido != null || mayoreo) ...[
                        const SizedBox(height: 4),
                        _Etiqueta(
                          enPedido != null
                              ? 'En el pedido · ${formatoPiezas(enPedido)}'
                              : 'Mayoreo desde ${p.siguienteEscalon(0)} pzas',
                          icono: enPedido != null
                              ? Icons.check_circle_outline
                              : Icons.sell_outlined,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatoPrecio(p.precio),
                  style: BarroTheme.type(
                    15,
                    21,
                    weight: FontWeight.w700,
                    color: BarroTheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto, {required this.icono});
  final String texto;
  final IconData icono;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: productoSuave,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 13, color: BarroTheme.primary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            texto,
            overflow: TextOverflow.ellipsis,
            style: BarroTheme.type(
              11,
              16,
              weight: FontWeight.w700,
              color: BarroTheme.primary,
            ),
          ),
        ),
      ],
    ),
  );
}
