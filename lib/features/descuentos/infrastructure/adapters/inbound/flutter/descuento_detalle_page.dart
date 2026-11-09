import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/productos/domain/producto.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_widgets.dart';
import '../../../../application/ports/inbound/gestion_descuentos_use_case.dart';
import '../../../../domain/descuento.dart';
import 'descuento_widgets.dart';

/// Administración de un descuento: a qué productos, categorías y áreas se aplica.
/// Se cierra con el [Descuento] actualizado.
class DescuentoDetallePage extends StatefulWidget {
  const DescuentoDetallePage({
    required this.negocio,
    required this.descuento,
    required this.gestion,
    required this.onSesionExpirada,
    super.key,
  });
  final NegocioProducto negocio;
  final Descuento descuento;
  final GestionDescuentosUseCase gestion;
  final VoidCallback onSesionExpirada;
  @override
  State<DescuentoDetallePage> createState() => _DescuentoDetallePageState();
}

class _DescuentoDetallePageState extends State<DescuentoDetallePage> {
  late Descuento _descuento = widget.descuento;
  CatalogoDescuento _catalogo = const CatalogoDescuento();
  bool _cargando = true;
  bool _busy = false;
  String? _error;
  String? _mensaje;

  @override
  void initState() {
    super.initState();
    _cargarCatalogo();
  }

  void _fallo(DescuentoFailure e) {
    if (e.sesionExpirada) {
      widget.onSesionExpirada();
      return;
    }
    setState(() {
      _error = e.message;
      _cargando = false;
      _busy = false;
    });
  }

  Future<void> _cargarCatalogo() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final catalogo = await widget.gestion.catalogo(widget.negocio.id);
      if (!mounted) return;
      setState(() {
        _catalogo = catalogo;
        _cargando = false;
      });
    } on DescuentoFailure catch (e) {
      if (mounted) _fallo(e);
    }
  }

  Future<void> _cambiar(
    Future<Descuento> Function() accion,
    String mensaje,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _mensaje = null;
    });
    try {
      final actualizado = await accion();
      if (!mounted) return;
      setState(() {
        _descuento = actualizado;
        _mensaje = mensaje;
        _busy = false;
      });
    } on DescuentoFailure catch (e) {
      if (mounted) _fallo(e);
    }
  }

  Future<void> _asignar(DestinoDescuento destino) async {
    final disponibles = [
      for (final e in _catalogo.de(destino))
        if (!_descuento.idsDe(destino).contains(e.id)) e,
    ];
    final elegido = await showModalBottomSheet<ElementoCatalogo>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => _SelectorElemento(destino: destino, opciones: disponibles),
    );
    if (elegido == null || !mounted) return;
    await _cambiar(
      () => widget.gestion.asignar(
        widget.negocio.id,
        _descuento.id,
        destino,
        elegido.id,
      ),
      'Descuento asignado a ${elegido.nombre}.',
    );
  }

  Future<void> _quitar(DestinoDescuento destino, int id, String nombre) =>
      _cambiar(
        () => widget.gestion.quitar(
          widget.negocio.id,
          _descuento.id,
          destino,
          id,
        ),
        'Se quitó $nombre del descuento.',
      );

  Widget _fila(DestinoDescuento destino, int id) {
    final elemento = _catalogo.de(destino).where((e) => e.id == id).firstOrNull;
    final nombre =
        elemento?.nombre ?? '${_mayuscula(destino.singular)} #$id';
    return Container(
      key: ValueKey('descuento-${destino.name}-$id'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BarroTheme.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: BarroTheme.type(14, 21, weight: FontWeight.w700),
                ),
                if (elemento != null && elemento.contexto.isNotEmpty)
                  Text(
                    elemento.contexto,
                    style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
                  ),
              ],
            ),
          ),
          IconButton(
            key: ValueKey('descuento-quitar-${destino.name}-$id'),
            tooltip: 'Quitar',
            icon: const Icon(Icons.close, size: 20),
            color: BarroTheme.error,
            onPressed: _busy ? null : () => _quitar(destino, id, nombre),
          ),
        ],
      ),
    );
  }

  String _mayuscula(String texto) =>
      texto.isEmpty ? texto : texto[0].toUpperCase() + texto.substring(1);

  Widget _seccion(DestinoDescuento destino) {
    final ids = _descuento.idsDe(destino);
    final titulo = _mayuscula(destino.plural);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          '$titulo (${ids.length})',
          style: BarroTheme.type(18, 26, weight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (ids.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              destino.textoVacio,
              style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
            ),
          ),
        for (final id in ids) _fila(destino, id),
        const SizedBox(height: 4),
        DescuentoBotonContorno(
          key: ValueKey('descuento-asignar-${destino.name}'),
          texto: '+ Asignar ${destino.singular}',
          onPressed: _busy ? null : () => _asignar(destino),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) Navigator.of(context).pop<Descuento>(_descuento);
    },
    child: ProductoScaffold(
      children: [
        const SizedBox(height: 14),
        DescuentoEnlaceVolver(
          onPressed: () => Navigator.of(context).pop<Descuento>(_descuento),
        ),
        ProductoNegocioPanel(negocio: widget.negocio),
        const SizedBox(height: 16),
        Text(
          'Administrar descuento',
          style: BarroTheme.type(28, 36, weight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Elige a qué productos, categorías o áreas se aplica.',
          style: BarroTheme.type(14, 21, color: BarroTheme.secondary),
        ),
        const SizedBox(height: 16),
        DescuentoResumen(descuento: _descuento),
        const SizedBox(height: 12),
        Text(
          'Un producto usa el descuento asignado a él; si no tiene, el de su categoría y, después, el de su área.',
          style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
        ),
        if (_mensaje != null) ...[
          const SizedBox(height: 16),
          ProductoAviso(_mensaje!),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          ProductoAviso(_error!, error: true),
          Center(
            child: TextButton(
              onPressed: _cargarCatalogo,
              child: const Text('Reintentar'),
            ),
          ),
        ],
        if (_cargando)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          for (final destino in DestinoDescuento.values) _seccion(destino),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop<Descuento>(_descuento),
            child: const Text('Volver'),
          ),
        ),
      ],
    ),
  );
}

/// Hoja inferior con búsqueda para elegir qué asignar.
class _SelectorElemento extends StatefulWidget {
  const _SelectorElemento({required this.destino, required this.opciones});
  final DestinoDescuento destino;
  final List<ElementoCatalogo> opciones;
  @override
  State<_SelectorElemento> createState() => _SelectorElementoState();
}

class _SelectorElementoState extends State<_SelectorElemento> {
  final _busqueda = TextEditingController();

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final texto = _busqueda.text.trim().toLowerCase();
    final filtradas = [
      for (final o in widget.opciones)
        if (texto.isEmpty ||
            o.nombre.toLowerCase().contains(texto) ||
            o.contexto.toLowerCase().contains(texto))
          o,
    ];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Asignar ${widget.destino.singular}',
                style: BarroTheme.type(22, 30, weight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              if (widget.opciones.isNotEmpty) ...[
                TextField(
                  key: const ValueKey('descuento-selector-busqueda'),
                  controller: _busqueda,
                  style: BarroTheme.type(14, 21),
                  decoration: productoDecoracion(
                    hint: 'Buscar ${widget.destino.singular}...',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
              ],
              if (widget.opciones.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No hay más ${widget.destino.plural} disponibles para asignar.',
                    style: BarroTheme.type(14, 21, color: BarroTheme.secondary),
                  ),
                )
              else if (filtradas.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Ningún resultado coincide con tu búsqueda.',
                    style: BarroTheme.type(14, 21, color: BarroTheme.secondary),
                  ),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final o in filtradas)
                        ListTile(
                          key: ValueKey('descuento-opcion-${o.id}'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            o.nombre,
                            style: BarroTheme.type(
                              14,
                              21,
                              weight: FontWeight.w700,
                            ),
                          ),
                          subtitle: o.contexto.isEmpty ? null : Text(o.contexto),
                          trailing: const Icon(
                            Icons.add_circle_outline,
                            color: BarroTheme.primary,
                          ),
                          onTap: () => Navigator.pop(context, o),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
