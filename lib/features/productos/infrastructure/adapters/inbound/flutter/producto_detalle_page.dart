import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/descuentos/application/ports/inbound/gestion_descuentos_use_case.dart';
import '../../../../application/ports/inbound/gestion_productos_use_case.dart';
import '../../../../application/services/imagenes_producto.dart';
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
    this.sucursal,
    this.mensajeInicial,
    this.descuentos,
    this.imagenes,
    this.soloLectura = false,
    super.key,
  });
  final NegocioProducto negocio;

  /// Vista del empleado: solo ajusta existencias; no edita ni elimina.
  final bool soloLectura;
  final Producto producto;
  final GestionProductosUseCase gestion;

  /// Para editar los descuentos (varios, opcionales) del producto.
  final GestionDescuentosUseCase? descuentos;
  final ImagenesProducto? imagenes;
  final VoidCallback onSesionExpirada;
  final String? mensajeInicial;

  /// Con sucursal solo se gestiona su existencia; sin ella (modo negocio) se
  /// ven todas las sucursales y se puede asignar el producto a las que faltan.
  final SucursalProducto? sucursal;
  @override
  State<ProductoDetallePage> createState() => _ProductoDetallePageState();
}

class _ProductoDetallePageState extends State<ProductoDetallePage> {
  late Producto _producto = widget.producto;
  bool _cargando = true;
  String? _mensaje;
  String? _error;
  bool _busy = false;
  int? _ajustandoId;
  List<SucursalProducto> _sucursales = [];

  bool get _modoSucursal => widget.sucursal != null;

  /// Sucursales del negocio donde el producto aún no tiene registro de existencia.
  List<SucursalProducto> get _sinAsignar {
    final asignadas = {for (final e in _producto.existencias) e.sucursalId};
    return [
      for (final s in _sucursales)
        if (!asignadas.contains(s.id)) s,
    ];
  }

  @override
  void initState() {
    super.initState();
    _mensaje = widget.mensajeInicial;
    // Lo guardado se muestra de inmediato; _cargarDetalle trae existencias frescas.
    final guardado = widget.gestion.detalleGuardado(widget.producto.id);
    if (guardado != null) {
      _producto = _modoSucursal
          ? guardado.soloSucursal(widget.sucursal!.id)
          : guardado;
      _cargando = false;
    }
    _cargarDetalle();
    if (!_modoSucursal && !widget.soloLectura) _cargarSucursales();
  }

  Future<void> _cargarSucursales() async {
    try {
      final sucursales = await widget.gestion.sucursales(widget.negocio.id);
      if (mounted) setState(() => _sucursales = sucursales);
    } on ProductoFailure catch (e) {
      if (mounted) _fallo(e);
    }
  }

  Future<void> _asignar(SucursalProducto sucursal) async {
    if (_busy || _ajustandoId != null) return;
    final cantidad = await showDialog<int>(
      context: context,
      builder: (_) => _AsignarDialog(sucursal: sucursal),
    );
    if (cantidad == null || !mounted) return;
    setState(() {
      _ajustandoId = -sucursal.id;
      _error = null;
      _mensaje = null;
    });
    try {
      final nueva = await widget.gestion.asignarASucursal(
        _producto.id,
        sucursal,
        cantidad,
      );
      if (!mounted) return;
      setState(() {
        _producto = _producto.conExistencias(
          [..._producto.existencias, nueva]
            ..sort((a, b) => a.sucursalNombre.compareTo(b.sucursalNombre)),
        );
        _ajustandoId = null;
        _mensaje =
            'Producto asignado a ${sucursal.nombre} con ${formatoPiezas(cantidad)}.';
      });
    } on ProductoFailure catch (f) {
      if (!mounted) return;
      setState(() => _ajustandoId = null);
      _fallo(f);
    }
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

  /// El listado trae solo lo mínimo: categoría, área y existencias se piden aquí.
  Future<void> _cargarDetalle() async {
    try {
      final detalle = await widget.gestion.consultar(
        widget.producto.id,
        widget.negocio.id,
      );
      if (!mounted) return;
      setState(() {
        _producto = _modoSucursal
            ? detalle.soloSucursal(widget.sucursal!.id)
            : detalle;
        _cargando = false;
      });
    } on ProductoFailure catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      _fallo(e);
    }
  }

  /// Suma (positiva) o resta (negativa) piezas en una sucursal.
  Future<void> _ajustar(ExistenciaSucursal e, int cantidad) async {
    if (_busy || _ajustandoId != null) return;
    setState(() {
      _ajustandoId = e.inventarioId;
      _error = null;
      _mensaje = null;
    });
    try {
      final nueva = await widget.gestion.ajustarExistencia(
        e.inventarioId,
        cantidad,
      );
      if (!mounted) return;
      setState(() {
        _producto = _producto.conExistencias([
          for (final x in _producto.existencias)
            x.inventarioId == e.inventarioId ? x.conExistencia(nueva) : x,
        ]);
        _ajustandoId = null;
        _mensaje =
            '${e.sucursalNombre}: ${cantidad > 0 ? '+' : '−'}${cantidad.abs()}, ahora ${formatoPiezas(nueva)}.';
      });
    } on ProductoFailure catch (f) {
      if (!mounted) return;
      setState(() => _ajustandoId = null);
      _fallo(f);
    }
  }

  Future<void> _ajustarCantidad(ExistenciaSucursal e) async {
    if (_busy || _ajustandoId != null) return;
    final cantidad = await showDialog<int>(
      context: context,
      builder: (_) => _AjusteDialog(existencia: e),
    );
    if (cantidad != null && mounted) _ajustar(e, cantidad);
  }

  Future<void> _editar() async {
    if (_busy) return;
    final editado = await Navigator.of(context).push<Producto>(
      MaterialPageRoute(
        builder: (_) => ProductoFormPage(
          negocio: widget.negocio,
          gestion: widget.gestion,
          descuentos: widget.descuentos,
          imagenes: widget.imagenes,
          onSesionExpirada: widget.onSesionExpirada,
          producto: _producto,
          sucursal: widget.sucursal,
        ),
      ),
    );
    if (!mounted || editado == null) return;
    setState(() {
      _producto = widget.sucursal == null
          ? editado
          : editado.soloSucursal(widget.sucursal!.id);
      _mensaje = 'Cambios guardados correctamente.';
      _error = null;
    });
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
      canPop: !_busy && _ajustandoId == null,
      child: ProductoScaffold(
        children: [
          const SizedBox(height: 14),
          ProductoEnlaceVolver(
            onPressed: _busy ? null : () => Navigator.pop(context),
          ),
          ProductoNegocioPanel(
            negocio: widget.negocio,
            sucursal: widget.sucursal?.nombre,
          ),
          const SizedBox(height: 16),
          Text(
            'Detalle del producto',
            style: BarroTheme.type(28, 36, weight: FontWeight.w700),
          ),
          if (p.areaNombre != null || p.categoriaNombre != null) ...[
            const SizedBox(height: 8),
            if (p.areaNombre != null)
              _DatoClasificacion(etiqueta: 'Área', valor: p.areaNombre!),
            if (p.categoriaNombre != null)
              _DatoClasificacion(
                etiqueta: 'Categoría',
                valor: p.categoriaNombre!,
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
                // Solo visualización de la imagen del producto.
                ProductoImagen(
                  key: const ValueKey('producto-detalle-imagen'),
                  size: 260,
                  ancho: double.infinity,
                  url: p.imagenUrl,
                ),
                const SizedBox(height: 16),
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
            _modoSucursal
                ? 'Existencia en ${widget.sucursal!.nombre}'
                : 'Existencias por sucursal',
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
            child: _cargando
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : p.existencias.isEmpty && _sinAsignar.isEmpty
                ? Text(
                    'Este producto aún no tiene existencias registradas.',
                    style: BarroTheme.type(14, 21, color: BarroTheme.secondary),
                  )
                : Column(
                    children: [
                      for (final e in p.existencias)
                        _FilaExistencia(
                          existencia: e,
                          ocupado: _busy || _ajustandoId != null,
                          cargando: _ajustandoId == e.inventarioId,
                          onAjustar: (c) => _ajustar(e, c),
                          onCantidad: () => _ajustarCantidad(e),
                        ),
                      for (final s in _sinAsignar)
                        _FilaSinAsignar(
                          sucursal: s,
                          ocupado: _busy || _ajustandoId != null,
                          cargando: _ajustandoId == -s.id,
                          onAsignar: () => _asignar(s),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _modoSucursal
                    ? 'Disponible en la sucursal'
                    : 'Total disponible',
                style: BarroTheme.type(14, 21, color: BarroTheme.secondary),
              ),
              Text(
                formatoPiezas(p.existenciaTotal),
                style: BarroTheme.type(16, 23, weight: FontWeight.w700),
              ),
            ],
          ),
          if (!widget.soloLectura) ...[
            const SizedBox(height: 24),
            ProductoBoton(
              key: const ValueKey('producto-editar'),
              texto: 'Editar producto',
              onPressed: _busy || _cargando ? null : _editar,
            ),
            // Eliminar da de baja el producto en todo el negocio: solo desde el modo negocio.
            if (!_modoSucursal) ...[
              const SizedBox(height: 12),
              ProductoBotonPeligro(
                key: const ValueKey('producto-eliminar'),
                texto: 'Eliminar producto',
                onPressed: _busy || _cargando ? null : _eliminar,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// "Área: Cocina y comedor" — etiqueta en gris y valor en negrita.
class _DatoClasificacion extends StatelessWidget {
  const _DatoClasificacion({required this.etiqueta, required this.valor});
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$etiqueta: ',
            style: BarroTheme.type(14, 21, color: BarroTheme.secondary),
          ),
          TextSpan(
            text: valor,
            style: BarroTheme.type(14, 21, weight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

class _FilaExistencia extends StatelessWidget {
  const _FilaExistencia({
    required this.existencia,
    required this.ocupado,
    required this.cargando,
    required this.onAjustar,
    required this.onCantidad,
  });
  final ExistenciaSucursal existencia;
  final bool ocupado;
  final bool cargando;
  final ValueChanged<int> onAjustar;
  final VoidCallback onCantidad;

  @override
  Widget build(BuildContext context) {
    final e = existencia;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(e.sucursalNombre, style: BarroTheme.type(14, 21)),
              ),
              Text(
                formatoPiezas(e.existencia),
                style: BarroTheme.type(14, 21, weight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton.outlined(
                key: ValueKey('existencia-menos-${e.inventarioId}'),
                tooltip: 'Quitar 1 pieza',
                onPressed: ocupado || e.existencia < 1
                    ? null
                    : () => onAjustar(-1),
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Center(
                  child: cargando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
                          key: ValueKey('existencia-ajustar-${e.inventarioId}'),
                          onPressed: ocupado ? null : onCantidad,
                          child: const Text('Ajustar cantidad'),
                        ),
                ),
              ),
              IconButton.filled(
                key: ValueKey('existencia-mas-${e.inventarioId}'),
                tooltip: 'Agregar 1 pieza',
                onPressed: ocupado ? null : () => onAjustar(1),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pide cuántas piezas agregar o quitar; se cierra con la cantidad con signo.
class _AjusteDialog extends StatefulWidget {
  const _AjusteDialog({required this.existencia});
  final ExistenciaSucursal existencia;
  @override
  State<_AjusteDialog> createState() => _AjusteDialogState();
}

class _AjusteDialogState extends State<_AjusteDialog> {
  final _controller = TextEditingController();
  bool _agregar = true;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirmar() {
    final n = int.tryParse(_controller.text.trim());
    if (n == null || n <= 0) {
      setState(() => _error = 'Escribe un número entero mayor que cero.');
      return;
    }
    if (n > 1000000) {
      setState(() => _error = 'No puede superar 1,000,000.');
      return;
    }
    if (!_agregar && n > widget.existencia.existencia) {
      setState(
        () => _error =
            'Solo hay ${formatoPiezas(widget.existencia.existencia)} en esta sucursal.',
      );
      return;
    }
    Navigator.pop(context, _agregar ? n : -n);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existencia.sucursalNombre),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Existencia actual: ${formatoPiezas(widget.existencia.existencia)}',
          style: BarroTheme.type(14, 21, color: BarroTheme.secondary),
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Agregar')),
            ButtonSegment(value: false, label: Text('Quitar')),
          ],
          selected: {_agregar},
          onSelectionChanged: (v) => setState(() {
            _agregar = v.first;
            _error = null;
          }),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('existencia-cantidad'),
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Cantidad de piezas',
            errorText: _error,
          ),
          onSubmitted: (_) => _confirmar(),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _confirmar, child: const Text('Aplicar')),
    ],
  );
}

/// Sucursal del negocio donde el producto todavía no tiene existencia registrada.
class _FilaSinAsignar extends StatelessWidget {
  const _FilaSinAsignar({
    required this.sucursal,
    required this.ocupado,
    required this.cargando,
    required this.onAsignar,
  });
  final SucursalProducto sucursal;
  final bool ocupado;
  final bool cargando;
  final VoidCallback onAsignar;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(sucursal.nombre, style: BarroTheme.type(14, 21)),
              Text(
                'Sin asignar',
                style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
              ),
            ],
          ),
        ),
        if (cargando)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          OutlinedButton(
            key: ValueKey('existencia-asignar-${sucursal.id}'),
            onPressed: ocupado ? null : onAsignar,
            child: const Text('Asignar'),
          ),
      ],
    ),
  );
}

/// Pide la existencia inicial al asignar el producto a una sucursal.
class _AsignarDialog extends StatefulWidget {
  const _AsignarDialog({required this.sucursal});
  final SucursalProducto sucursal;
  @override
  State<_AsignarDialog> createState() => _AsignarDialogState();
}

class _AsignarDialogState extends State<_AsignarDialog> {
  final _controller = TextEditingController(text: '0');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirmar() {
    final n = int.tryParse(_controller.text.trim());
    if (n == null || n < 0 || n > 1000000) {
      setState(() => _error = 'Escribe un entero de 0 a 1,000,000.');
      return;
    }
    Navigator.pop(context, n);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Asignar a ${widget.sucursal.nombre}'),
    content: TextField(
      key: const ValueKey('asignar-existencia'),
      controller: _controller,
      autofocus: true,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: 'Existencia inicial (piezas)',
        errorText: _error,
      ),
      onSubmitted: (_) => _confirmar(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _confirmar, child: const Text('Asignar')),
    ],
  );
}
