import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:punto_de_venta/core/infrastructure/services/notificacion_servicio.dart';
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

  /// Con sucursal solo se gestiona su existencia; sin ella (modo negocio) se
  /// ven todas las sucursales y se puede asignar el producto a las que faltan.
  final SucursalProducto? sucursal;
  @override
  State<ProductoDetallePage> createState() => _ProductoDetallePageState();
}

class _ProductoDetallePageState extends State<ProductoDetallePage> {
  late Producto _producto = widget.producto;
  bool _cargando = true;
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
    final eleccion = await showDialog<({int? cantidad})>(
      context: context,
      builder: (_) => _AsignarDialog(sucursal: sucursal),
    );
    if (eleccion == null || !mounted) return;
    setState(() => _ajustandoId = -sucursal.id);
    try {
      final nueva = await widget.gestion.asignarASucursal(
        _producto.id,
        sucursal,
        eleccion.cantidad,
      );
      if (!mounted) return;
      setState(() {
        _producto = _producto.conExistencias(
          [..._producto.existencias, nueva]
            ..sort((a, b) => a.sucursalNombre.compareTo(b.sucursalNombre)),
        );
        _ajustandoId = null;
      });
      NotificacionServicio.exito(
        context,
        'Producto asignado a ${sucursal.nombre} con ${formatoPiezas(nueva.existencia)}.',
        titulo: 'Producto asignado',
      );
    } on ProductoFailure catch (f) {
      if (!mounted) return;
      setState(() => _ajustandoId = null);
      _fallo(f);
    }
  }

  /// Quita el producto de una sucursal; el backend deja su existencia en 0
  /// y exige que quede en al menos otra.
  Future<void> _quitar(ExistenciaSucursal e) async {
    if (_busy || _ajustandoId != null) return;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => _QuitarSucursalDialog(existencia: e),
    );
    if (confirmado != true || !mounted) return;
    setState(() => _ajustandoId = e.inventarioId);
    try {
      await widget.gestion.quitarDeSucursal(e.inventarioId);
      if (!mounted) return;
      setState(() {
        _producto = _producto.conExistencias([
          for (final x in _producto.existencias)
            if (x.inventarioId != e.inventarioId) x,
        ]);
        _ajustandoId = null;
      });
      NotificacionServicio.exito(
        context,
        'Producto quitado de ${e.sucursalNombre}.',
        titulo: 'Sucursal actualizada',
      );
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
    NotificacionServicio.error(context, e.message);
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

  /// Suma (positiva) o resta (negativa) piezas en una sucursal. Con [entrada]
  /// solo se suma, que es lo único que puede hacer el empleado.
  Future<void> _ajustar(
    ExistenciaSucursal e,
    int cantidad, {
    bool entrada = false,
  }) async {
    if (_busy || _ajustandoId != null) return;
    setState(() => _ajustandoId = e.inventarioId);
    try {
      final nueva = entrada
          ? await widget.gestion.agregarExistencia(e.inventarioId, cantidad)
          : await widget.gestion.ajustarExistencia(e.inventarioId, cantidad);
      if (!mounted) return;
      setState(() {
        _producto = _producto.conExistencias([
          for (final x in _producto.existencias)
            x.inventarioId == e.inventarioId ? x.conExistencia(nueva) : x,
        ]);
        _ajustandoId = null;
      });
      NotificacionServicio.exito(
        context,
        '${e.sucursalNombre}: ${cantidad > 0 ? '+' : '−'}${cantidad.abs()}, ahora ${formatoPiezas(nueva)}.',
        titulo: 'Existencia actualizada',
      );
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

  /// Empleado: elige cuántas piezas agregar y confirma antes de guardarlas.
  Future<void> _agregarExistencias(ExistenciaSucursal e) async {
    if (_busy || _ajustandoId != null) return;
    final cantidad = await showDialog<int>(
      context: context,
      builder: (_) => _AjusteDialog(existencia: e, soloAgregar: true),
    );
    if (cantidad == null || !mounted) return;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmarEntradaDialog(
        producto: _producto.nombre,
        existencia: e,
        cantidad: cantidad,
      ),
    );
    if (confirmado == true && mounted) _ajustar(e, cantidad, entrada: true);
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
    });
    NotificacionServicio.actualizacion(
      context,
      'Cambios guardados correctamente.',
    );
  }

  Future<void> _eliminar() async {
    if (_busy) return;
    final confirmar = await confirmarEliminarProducto(
      context,
      producto: _producto,
      negocio: widget.negocio,
    );
    if (!confirmar || !mounted) return;
    setState(() => _busy = true);
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
          const SizedBox(height: 20),
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
                Builder(
                  builder: (context) {
                    final imagen = ProductoImagen(
                      key: const ValueKey('producto-detalle-imagen'),
                      size: 260,
                      proporcion: 1,
                      url: p.imagenUrl,
                    );
                    final url = p.imagenUrl?.trim() ?? '';
                    if (url.isEmpty) return imagen;
                    return Semantics(
                      button: true,
                      label: 'Ver imagen completa',
                      child: GestureDetector(
                        onTap: () => mostrarImagenProducto(context, url),
                        child: Stack(
                          children: [
                            imagen,
                            Positioned(
                              right: 10,
                              bottom: 10,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.zoom_out_map_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
                if (p.descuentos.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.local_offer_outlined,
                        size: 18,
                        color: BarroTheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Descuentos del producto',
                        style: BarroTheme.type(14, 20, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Se aplican según la cantidad de piezas que se vendan.',
                    style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
                  ),
                  const SizedBox(height: 10),
                  // Un chip por escalón: solo aplica aquel en que cae la cantidad.
                  Wrap(
                    key: const ValueKey('producto-detalle-descuentos'),
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final d in p.descuentos)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: productoSuave,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.sell_outlined,
                                size: 14,
                                color: BarroTheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  d.resumen,
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
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (p.areaNombre != null || p.categoriaNombre != null) ...[
            const SizedBox(height: 16),
            _PanelClasificacion(
              area: p.areaNombre,
              categoria: p.categoriaNombre,
            ),
          ],
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
                          // Ajustar inventario es solo del propietario (HU-05);
                          // el empleado solo puede agregar piezas.
                          editable: !widget.soloLectura,
                          onAgregar: widget.soloLectura
                              ? () => _agregarExistencias(e)
                              : null,
                          // Solo el propietario, desde el negocio, y si queda
                          // al menos otra sucursal con el producto.
                          onQuitar:
                              _modoSucursal ||
                                  widget.soloLectura ||
                                  p.existencias.length < 2
                              ? null
                              : () => _quitar(e),
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
              Expanded(
                child: Text(
                  _modoSucursal
                      ? 'Disponible en la sucursal'
                      : 'Total disponible',
                  style: BarroTheme.type(14, 21, color: BarroTheme.secondary),
                ),
              ),
              const SizedBox(width: 8),
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

/// Panel con el área y la categoría del producto, cada una con su icono.
class _PanelClasificacion extends StatelessWidget {
  const _PanelClasificacion({this.area, this.categoria});
  final String? area;
  final String? categoria;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: BarroTheme.border),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        if (area != null)
          _DatoClasificacion(
            icono: Icons.space_dashboard_outlined,
            etiqueta: 'Área',
            valor: area!,
          ),
        if (area != null && categoria != null)
          const Divider(height: 1, color: Color(0xFFEFE3DD)),
        if (categoria != null)
          _DatoClasificacion(
            icono: Icons.sell_outlined,
            etiqueta: 'Categoría',
            valor: categoria!,
          ),
      ],
    ),
  );
}

class _DatoClasificacion extends StatelessWidget {
  const _DatoClasificacion({
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });
  final IconData icono;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF8E7DF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icono, size: 21, color: BarroTheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                etiqueta,
                style: BarroTheme.type(12, 17, color: BarroTheme.secondary),
              ),
              Text(
                valor,
                style: BarroTheme.type(15, 21, weight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
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
    this.onQuitar,
    this.onAgregar,
    this.editable = true,
  });
  final ExistenciaSucursal existencia;
  final bool ocupado;
  final bool cargando;
  final ValueChanged<int> onAjustar;
  final VoidCallback onCantidad;

  /// Sin permiso de ajuste (empleado) solo se muestra la existencia.
  final bool editable;

  /// Empleado: botón para agregar piezas (nunca quitar).
  final VoidCallback? onAgregar;

  /// Null cuando no se puede quitar (modo sucursal, empleado o última sucursal).
  final VoidCallback? onQuitar;

  @override
  Widget build(BuildContext context) {
    final e = existencia;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExistenciaIcono(e.existencia),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.sucursalNombre,
                      style: BarroTheme.type(14, 21, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    ExistenciaEtiqueta(e.existencia),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatoPiezas(e.existencia),
                style: BarroTheme.type(
                  15,
                  21,
                  weight: FontWeight.w700,
                  color: NivelExistencia.de(e.existencia).color,
                ),
              ),
              if (onQuitar != null)
                PopupMenuButton<void>(
                  key: ValueKey('existencia-opciones-${e.inventarioId}'),
                  tooltip: 'Más opciones',
                  enabled: !ocupado,
                  icon: const Icon(Icons.more_vert),
                  color: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  elevation: 6,
                  shadowColor: Colors.black26,
                  position: PopupMenuPosition.under,
                  offset: const Offset(0, 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: BarroTheme.border),
                  ),
                  itemBuilder: (_) => [
                    PopupMenuItem<void>(
                      key: ValueKey('existencia-quitar-${e.inventarioId}'),
                      onTap: onQuitar,
                      height: 48,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.remove_circle_outline,
                            size: 20,
                            color: BarroTheme.error,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Quitar de esta sucursal',
                            style: BarroTheme.type(
                              14,
                              20,
                              weight: FontWeight.w600,
                              color: BarroTheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          ExistenciaBarra(e.existencia),
          if (!editable && onAgregar != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 46,
              child: cargando
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : FilledButton.tonalIcon(
                      key: ValueKey('existencia-agregar-${e.inventarioId}'),
                      onPressed: ocupado ? null : onAgregar,
                      style: FilledButton.styleFrom(
                        backgroundColor: productoSuave,
                        foregroundColor: BarroTheme.primary,
                        textStyle: BarroTheme.type(
                          14,
                          20,
                          weight: FontWeight.w700,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.add_box_outlined, size: 20),
                      label: const Text('Agregar existencias'),
                    ),
            ),
          ],
          if (editable) ...[
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
                            key: ValueKey(
                              'existencia-ajustar-${e.inventarioId}',
                            ),
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
        ],
      ),
    );
  }
}

/// Pide cuántas piezas agregar o quitar; se cierra con la cantidad con signo.
/// Con [soloAgregar] (empleado) no se ofrece quitar.
class _AjusteDialog extends StatefulWidget {
  const _AjusteDialog({required this.existencia, this.soloAgregar = false});
  final ExistenciaSucursal existencia;
  final bool soloAgregar;
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

  /// Existencia que quedaría tras aplicar el ajuste escrito, o `null` si el
  /// campo aún no tiene un número válido.
  int? get _resultado {
    final n = int.tryParse(_controller.text.trim());
    if (n == null || n <= 0) return null;
    return widget.existencia.existencia + (_agregar ? n : -n);
  }

  Widget _opcion({
    required bool valor,
    required IconData icono,
    required String texto,
  }) {
    final seleccionada = _agregar == valor;
    final color = valor ? BarroTheme.success : BarroTheme.error;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() {
            _agregar = valor;
            _error = null;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: seleccionada ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: seleccionada
                  ? const [
                      BoxShadow(
                        color: Color(0x1A1E1B19),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icono,
                  size: 20,
                  color: seleccionada ? color : BarroTheme.placeholder,
                ),
                const SizedBox(width: 6),
                Text(
                  texto,
                  style: BarroTheme.type(
                    14,
                    20,
                    weight: FontWeight.w700,
                    color: seleccionada ? color : BarroTheme.placeholder,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actual = widget.existencia.existencia;
    final resultado = _resultado;
    final acento = _agregar ? BarroTheme.success : BarroTheme.error;
    return Dialog(
      backgroundColor: BarroTheme.background,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Encabezado: icono de sucursal + nombre.
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: productoSuave,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.storefront_outlined,
                    color: BarroTheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.soloAgregar
                            ? 'Agregar existencias'
                            : 'Ajustar existencia',
                        style: BarroTheme.type(
                          12,
                          17,
                          weight: FontWeight.w700,
                          color: BarroTheme.placeholder,
                        ),
                      ),
                      Text(
                        widget.existencia.sucursalNombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: BarroTheme.type(20, 26, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Existencia actual.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: BarroTheme.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  ExistenciaIcono(actual, tamano: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Existencia actual',
                          style: BarroTheme.type(
                            14,
                            20,
                            color: BarroTheme.secondary,
                          ),
                        ),
                        Text(
                          NivelExistencia.de(actual).etiqueta,
                          style: BarroTheme.type(
                            12,
                            16,
                            weight: FontWeight.w600,
                            color: NivelExistencia.de(actual).color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatoPiezas(actual),
                    style: BarroTheme.type(15, 21, weight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Selector Agregar / Quitar (el empleado solo agrega).
            if (!widget.soloAgregar) ...[
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: productoSuave,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _opcion(
                      valor: true,
                      icono: Icons.add_circle_outline,
                      texto: 'Agregar',
                    ),
                    const SizedBox(width: 4),
                    _opcion(
                      valor: false,
                      icono: Icons.remove_circle_outline,
                      texto: 'Quitar',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              key: const ValueKey('existencia-cantidad'),
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: BarroTheme.type(18, 24, weight: FontWeight.w700),
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(
                labelText: widget.soloAgregar
                    ? 'Piezas a agregar'
                    : 'Cantidad de piezas',
                hintText: '0',
                errorText: _error,
                errorMaxLines: 2,
                filled: true,
                fillColor: Colors.white,
                prefixIcon: Icon(
                  _agregar ? Icons.add : Icons.remove,
                  color: acento,
                ),
                suffixText: 'pzas',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: BarroTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: BarroTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: BarroTheme.primary,
                    width: 2,
                  ),
                ),
              ),
              onSubmitted: (_) => _confirmar(),
            ),
            // Vista previa del resultado.
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              child: resultado == null || _error != null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Icon(
                            resultado < 0
                                ? Icons.warning_amber_rounded
                                : Icons.arrow_forward_rounded,
                            size: 18,
                            color: resultado < 0 ? BarroTheme.error : acento,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              resultado < 0
                                  ? 'No hay suficientes piezas para quitar.'
                                  : 'Nueva existencia: ${formatoPiezas(resultado)}',
                              style: BarroTheme.type(
                                13,
                                19,
                                weight: FontWeight.w700,
                                color: resultado < 0
                                    ? BarroTheme.error
                                    : BarroTheme.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: BarroTheme.secondary,
                      side: const BorderSide(color: BarroTheme.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: BarroTheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _confirmar,
                    icon: Icon(
                      widget.soloAgregar
                          ? Icons.arrow_forward_rounded
                          : Icons.check_rounded,
                      size: 20,
                    ),
                    label: Text(widget.soloAgregar ? 'Continuar' : 'Aplicar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Confirmación que ve el empleado antes de sumar piezas a la existencia.
class _ConfirmarEntradaDialog extends StatelessWidget {
  const _ConfirmarEntradaDialog({
    required this.producto,
    required this.existencia,
    required this.cantidad,
  });
  final String producto;
  final ExistenciaSucursal existencia;
  final int cantidad;

  @override
  Widget build(BuildContext context) {
    final actual = existencia.existencia;
    final negrita = BarroTheme.type(14, 21, weight: FontWeight.w700);
    return Dialog(
      backgroundColor: BarroTheme.background,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: BarroTheme.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_box_outlined,
                  size: 28,
                  color: BarroTheme.success,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '¿Agregar ${formatoPiezas(cantidad)}?',
              textAlign: TextAlign.center,
              style: BarroTheme.type(20, 26, weight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Se sumarán a '),
                  TextSpan(text: producto, style: negrita),
                  const TextSpan(text: ' en '),
                  TextSpan(text: existencia.sucursalNombre, style: negrita),
                  const TextSpan(text: '.'),
                ],
              ),
              textAlign: TextAlign.center,
              style: BarroTheme.type(14, 21, color: BarroTheme.secondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: BarroTheme.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    formatoPiezas(actual),
                    style: BarroTheme.type(
                      15,
                      21,
                      weight: FontWeight.w600,
                      color: BarroTheme.secondary,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: BarroTheme.success,
                    ),
                  ),
                  Text(
                    formatoPiezas(actual + cantidad),
                    style: BarroTheme.type(
                      16,
                      22,
                      weight: FontWeight.w700,
                      color: BarroTheme.success,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Solo el propietario puede corregir o quitar piezas después.',
              textAlign: TextAlign.center,
              style: BarroTheme.type(12, 17, color: BarroTheme.placeholder),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: BarroTheme.secondary,
                      side: const BorderSide(color: BarroTheme.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('existencia-confirmar-agregar'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: BarroTheme.success,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: const Text('Sí, agregar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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

/// Pide la existencia inicial al asignar el producto a una sucursal. Se cierra
/// con `(cantidad: null)` si se deja vacío: el producto empieza con 0 piezas.
class _AsignarDialog extends StatefulWidget {
  const _AsignarDialog({required this.sucursal});
  final SucursalProducto sucursal;
  @override
  State<_AsignarDialog> createState() => _AsignarDialogState();
}

class _AsignarDialogState extends State<_AsignarDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirmar() {
    final texto = _controller.text.trim();
    if (texto.isEmpty) {
      Navigator.pop(context, (cantidad: null));
      return;
    }
    final n = int.tryParse(texto);
    if (n == null || n < 0 || n > 1000000) {
      setState(() => _error = 'Escribe un entero de 0 a 1,000,000.');
      return;
    }
    Navigator.pop(context, (cantidad: n));
  }

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder borde(Color color, [double ancho = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: ancho),
        );
    return Dialog(
      backgroundColor: BarroTheme.background,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: productoSuave,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_business_outlined,
                    size: 30,
                    color: BarroTheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Asignar a sucursal',
                textAlign: TextAlign.center,
                style: BarroTheme.type(21, 28, weight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'El producto estará disponible para vender en esta sucursal.',
                textAlign: TextAlign.center,
                style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: BarroTheme.border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: productoSuave,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.storefront_outlined,
                        size: 21,
                        color: BarroTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.sucursal.nombre,
                        style: BarroTheme.type(15, 21, weight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Existencia inicial',
                style: BarroTheme.type(13, 19, weight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('asignar-existencia'),
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: BarroTheme.type(18, 24, weight: FontWeight.w700),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: BarroTheme.type(
                    18,
                    24,
                    weight: FontWeight.w700,
                    color: BarroTheme.placeholder,
                  ),
                  prefixIcon: const Icon(
                    Icons.inventory_2_outlined,
                    color: BarroTheme.primary,
                  ),
                  suffixText: 'piezas',
                  suffixStyle: BarroTheme.type(
                    13,
                    19,
                    color: BarroTheme.secondary,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  enabledBorder: borde(BarroTheme.border),
                  focusedBorder: borde(BarroTheme.primary, 1.6),
                  errorBorder: borde(BarroTheme.error),
                  focusedErrorBorder: borde(BarroTheme.error, 1.6),
                  errorText: _error,
                  errorMaxLines: 2,
                ),
                onSubmitted: (_) => _confirmar(),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: productoSuave,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: BarroTheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Si lo dejas vacío, el producto empieza con 0 piezas.',
                        style: BarroTheme.type(
                          12,
                          18,
                          color: BarroTheme.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _confirmar,
                style: FilledButton.styleFrom(
                  backgroundColor: BarroTheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: BarroTheme.type(15, 21, weight: FontWeight.w700),
                ),
                icon: const Icon(Icons.check_rounded, size: 20),
                label: const Text('Asignar'),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: BarroTheme.secondary,
                  minimumSize: const Size.fromHeight(44),
                  textStyle: BarroTheme.type(14, 20, weight: FontWeight.w600),
                ),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirmación para quitar el producto de una sucursal: muestra la sucursal,
/// que sus piezas quedarán en 0 y acciones claras.
class _QuitarSucursalDialog extends StatelessWidget {
  const _QuitarSucursalDialog({required this.existencia});
  final ExistenciaSucursal existencia;

  @override
  Widget build(BuildContext context) {
    final e = existencia;
    return Dialog(
      backgroundColor: BarroTheme.background,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFDE8E4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.remove_shopping_cart_outlined,
                    size: 30,
                    color: BarroTheme.error,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '¿Quitar de esta sucursal?',
                textAlign: TextAlign.center,
                style: BarroTheme.type(21, 28, weight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'El producto dejará de aparecer en la sucursal.',
                textAlign: TextAlign.center,
                style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: BarroTheme.border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: productoSuave,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.storefront_outlined,
                        size: 21,
                        color: BarroTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.sucursalNombre,
                            style: BarroTheme.type(
                              15,
                              21,
                              weight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${formatoPiezas(e.existencia)} registradas',
                            style: BarroTheme.type(
                              12,
                              18,
                              color: BarroTheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0EE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: BarroTheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.existencia > 0
                            ? 'Sus ${formatoPiezas(e.existencia)} quedarán en 0. '
                                  'Si lo vuelves a asignar, indica de nuevo '
                                  'su existencia.'
                            : 'Puedes volver a asignarlo cuando quieras.',
                        style: BarroTheme.type(12, 18, color: BarroTheme.error),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                key: const ValueKey('confirmar-quitar-sucursal'),
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: BarroTheme.error,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: BarroTheme.type(15, 21, weight: FontWeight.w700),
                ),
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                label: const Text('Quitar'),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                  foregroundColor: BarroTheme.secondary,
                  minimumSize: const Size.fromHeight(44),
                  textStyle: BarroTheme.type(14, 20, weight: FontWeight.w600),
                ),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
