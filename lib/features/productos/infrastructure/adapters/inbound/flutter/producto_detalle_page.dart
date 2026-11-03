import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import '../../../../application/ports/inbound/gestion_productos_use_case.dart';
import '../../../../domain/producto.dart';
import 'producto_form_page.dart';
import 'producto_widgets.dart';

/// Se cierra con `true` cuando el producto fue eliminado.
class ProductoDetallePage extends StatefulWidget {
  const ProductoDetallePage({
    required this.negocio,
    required this.producto,
    required this.gestion,
    required this.onSesionExpirada,
    this.mensajeInicial,
    super.key,
  });
  final NegocioProducto negocio;
  final Producto producto;
  final GestionProductosUseCase gestion;
  final VoidCallback onSesionExpirada;
  final String? mensajeInicial;
  @override
  State<ProductoDetallePage> createState() => _ProductoDetallePageState();
}

class _ProductoDetallePageState extends State<ProductoDetallePage> {
  late Producto _producto = widget.producto;
  String _clasificacion = '';
  String? _mensaje;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _mensaje = widget.mensajeInicial;
    _cargarClasificacion();
  }

  void _fallo(ProductoFailure e) {
    if (e.sesionExpirada) {
      widget.onSesionExpirada();
      return;
    }
    setState(() {
      _error = e.message;
      _mensaje = null;
    });
  }

  Future<void> _cargarClasificacion() async {
    try {
      final areas = await widget.gestion.areas(widget.negocio.id);
      final categorias = await widget.gestion.categorias(widget.negocio.id);
      if (!mounted) return;
      final categoria = categorias
          .where((c) => c.id == _producto.categoriaId)
          .firstOrNull;
      final area = areas.where((a) => a.id == categoria?.areaId).firstOrNull;
      setState(() {
        _clasificacion = categoria == null
            ? ''
            : [if (area != null) area.nombre, categoria.nombre].join(' · ');
      });
    } on ProductoFailure catch (e) {
      if (mounted) _fallo(e);
    }
  }

  Future<void> _editar() async {
    if (_busy) return;
    final editado = await Navigator.of(context).push<Producto>(
      MaterialPageRoute(
        builder: (_) => ProductoFormPage(
          negocio: widget.negocio,
          gestion: widget.gestion,
          onSesionExpirada: widget.onSesionExpirada,
          producto: _producto,
        ),
      ),
    );
    if (!mounted || editado == null) return;
    setState(() {
      _producto = editado;
      _mensaje = 'Cambios guardados correctamente.';
      _error = null;
    });
    _cargarClasificacion();
  }

  Future<void> _eliminar() async {
    if (_busy) return;
    final confirmar = await confirmarEliminarProducto(
      context,
      producto: _producto,
      negocio: widget.negocio,
    );
    if (!confirmar || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.gestion.eliminar(_producto.id);
      if (!mounted) return;
      setState(() => _busy = false);
      Navigator.of(context).pop(true);
    } on ProductoFailure catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _fallo(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _producto;
    return PopScope(
      canPop: !_busy,
      child: ProductoScaffold(
        children: [
          const SizedBox(height: 14),
          ProductoEnlaceVolver(
            onPressed: _busy ? null : () => Navigator.pop(context),
          ),
          ProductoNegocioPanel(negocio: widget.negocio),
          const SizedBox(height: 16),
          Text(
            'Detalle del producto',
            style: BarroTheme.type(28, 36, weight: FontWeight.w700),
          ),
          if (_clasificacion.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _clasificacion,
              style: BarroTheme.type(14, 21, color: BarroTheme.secondary),
            ),
          ],
          const SizedBox(height: 20),
          if (_mensaje != null) ...[
            ProductoAviso(_mensaje!),
            const SizedBox(height: 20),
          ],
          if (_error != null) ...[
            ProductoAviso(_error!, error: true),
            const SizedBox(height: 20),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: BarroTheme.border),
              borderRadius: BorderRadius.circular(21),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.nombre,
                  style: BarroTheme.type(22, 30, weight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatoPrecio(p.precio),
                      style: BarroTheme.type(
                        30,
                        38,
                        weight: FontWeight.w700,
                        color: BarroTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        'MXN / pieza',
                        style: BarroTheme.type(
                          12,
                          18,
                          color: BarroTheme.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (p.descuento != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: productoSuave,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${p.descuento!.porcentajeTexto} % a partir de ${p.descuento!.cantidadMinima} piezas',
                      style: BarroTheme.type(
                        11,
                        16,
                        weight: FontWeight.w700,
                        color: BarroTheme.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Existencias por sucursal',
            style: BarroTheme.type(18, 26, weight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: BarroTheme.border),
              borderRadius: BorderRadius.circular(21),
            ),
            child: p.existencias.isEmpty
                ? Text(
                    'Este producto aún no tiene existencias registradas.',
                    style: BarroTheme.type(14, 21, color: BarroTheme.secondary),
                  )
                : Column(
                    children: [
                      for (final e in p.existencias)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  e.sucursalNombre,
                                  style: BarroTheme.type(14, 21),
                                ),
                              ),
                              Text(
                                formatoPiezas(e.existencia),
                                style: BarroTheme.type(
                                  14,
                                  21,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total disponible',
                style: BarroTheme.type(14, 21, color: BarroTheme.secondary),
              ),
              Text(
                formatoPiezas(p.existenciaTotal),
                style: BarroTheme.type(16, 23, weight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ProductoBoton(
            key: const ValueKey('producto-editar'),
            texto: 'Editar producto',
            onPressed: _busy ? null : _editar,
          ),
          const SizedBox(height: 12),
          ProductoBotonPeligro(
            key: const ValueKey('producto-eliminar'),
            texto: 'Eliminar producto',
            onPressed: _busy ? null : _eliminar,
          ),
        ],
      ),
    );
  }
}
