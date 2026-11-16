import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/productos/domain/producto.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_widgets.dart';
import '../../../application/gestion_pedidos.dart';
import '../../../domain/pedido.dart';
import 'pedido_input_formatters.dart';
import 'selector_producto_pedido.dart';
import 'package:punto_de_venta/features/sucursal/infrastructure/adapters/inbound/flutter/sucursal_widgets.dart';

class RegistrarPedidoPage extends StatefulWidget {
  const RegistrarPedidoPage({
    required this.gestion,
    required this.sucursalId,
    required this.negocio,
    required this.esPropietario,
    this.sucursalNombre,
    this.onInicio,
    this.onCaja,
    this.onInventario,
    super.key,
  });
  final GestionPedidos gestion;
  final int sucursalId;
  final String? sucursalNombre;
  final NegocioProducto negocio;
  final bool esPropietario;

  /// Destinos de la barra inferior. Se llaman después de cerrar esta pantalla,
  /// desde el listado de pedidos que la abrió.
  final VoidCallback? onInicio, onCaja, onInventario;
  @override
  State<RegistrarPedidoPage> createState() => _RegistrarPedidoPageState();
}

class _RegistrarPedidoPageState extends State<RegistrarPedidoPage> {
  final _form = GlobalKey<FormState>();
  final _descripcion = TextEditingController();
  final _cantidad = TextEditingController();
  final _envio = TextEditingController();
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  final _ciudad = TextEditingController();
  final _colonia = TextEditingController();
  final _calle = TextEditingController();
  final _monto = TextEditingController(text: '0');
  List<ProductoPedido> _productos = [];
  final List<LineaPedido> _lineas = [];
  Map<String, String> _errores = {};
  int? _producto;
  String _entrega = 'LOCAL', _metodo = 'EFECTIVO';
  String? _error;
  bool _cargando = true, _guardando = false;
  // Sin turno de caja abierto no se cobra: el pedido se registra sin anticipo.
  bool _cajaAbierta = true;
  int _paso = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final (productos, cajaAbierta) = await (
        widget.gestion.productos(widget.sucursalId),
        widget.gestion.cajaAbierta(widget.sucursalId),
      ).wait;
      if (mounted) {
        setState(() {
          _productos = productos;
          _cajaAbierta = cajaAbierta;
          if (!cajaAbierta) _monto.text = '0';
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _descripcion,
      _cantidad,
      _envio,
      _nombre,
      _telefono,
      _ciudad,
      _colonia,
      _calle,
      _monto,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _limpiarTexto(TextEditingController controller) {
    final limpio = PedidoInputFormatters.limpiarEspacios(controller.text);
    if (limpio == controller.text) return;
    controller.value = TextEditingValue(
      text: limpio,
      selection: TextSelection.collapsed(offset: limpio.length),
    );
  }

  void _limpiarTextos() {
    for (final controller in [
      _descripcion,
      _envio,
      _nombre,
      _ciudad,
      _colonia,
      _calle,
    ]) {
      _limpiarTexto(controller);
    }
  }

  String _resumenErrores(Map<String, String> errores) {
    String etiqueta(String campo) {
      final producto = RegExp(
        r'^productos\[(\d+)\](?:\.(\w+))?$',
      ).firstMatch(campo);
      if (producto != null) {
        final numero = int.parse(producto.group(1)!) + 1;
        return producto.group(2) == 'cantidad'
            ? 'Cantidad del producto $numero'
            : 'Producto $numero';
      }
      return switch (campo) {
        'cliente' => 'Datos del cliente',
        'cliente.nombre' => 'Nombre del cliente',
        'cliente.telefono' => 'Teléfono',
        'cliente.ciudad' => 'Ciudad',
        'cliente.colonia' => 'Colonia',
        'cliente.calle' => 'Calle y número',
        'descripcion' => 'Descripción del pedido',
        'descripcionEnvio' => 'Descripción de envío',
        'productos' => 'Productos',
        'tipoEntrega' => 'Tipo de entrega',
        'pagoInicial' => 'Pago inicial',
        'pagoInicial.monto' => 'Anticipo',
        'pagoInicial.metodoPago' => 'Tipo de pago',
        'sucursalId' => 'Sucursal',
        _ => 'Dato del pedido',
      };
    }

    return errores.entries
        .map((error) => '${etiqueta(error.key)}: ${error.value}')
        .join('\n');
  }

  void _limpiarErroresProductos() {
    _errores.removeWhere(
      (campo, _) => campo == 'productos' || campo.startsWith('productos['),
    );
    _error = _errores.isEmpty ? null : _resumenErrores(_errores);
  }

  BigInt get _totalEstimadoCentavos => _lineas.fold<BigInt>(
    BigInt.zero,
    (total, linea) =>
        total +
        _productos
            .firstWhere((producto) => producto.id == linea.productoId)
            .subtotalEstimadoCentavos(
              linea.cantidad,
              conDescuento: linea.aplicarDescuento,
            ),
  );

  BigInt? _leerCentavos(String texto) {
    final importe = texto.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(importe)) return null;
    final partes = importe.split('.');
    final enteros = BigInt.tryParse(partes.first);
    if (enteros == null) return null;
    final decimales = partes.length == 1 ? '00' : partes.last.padRight(2, '0');
    return enteros * BigInt.from(100) + BigInt.parse(decimales);
  }

  String _formatoCentavos(BigInt centavos) {
    final entero = centavos ~/ BigInt.from(100);
    final decimal = (centavos % BigInt.from(100)).toString().padLeft(2, '0');
    return '\$$entero.$decimal';
  }

  Widget _resumenImportes() => ValueListenableBuilder<TextEditingValue>(
    valueListenable: _monto,
    builder: (context, valor, _) {
      final total = _totalEstimadoCentavos;
      final anticipo = _leerCentavos(valor.text);
      final excedido = anticipo != null && anticipo > total;
      final saldo = anticipo == null || excedido ? null : total - anticipo;
      Widget fila(String texto, Widget importe) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                texto,
                style: BarroTheme.type(14, 20, color: BarroTheme.secondary),
              ),
            ),
            importe,
          ],
        ),
      );
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        decoration: BoxDecoration(
          color: productoSuave,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            fila(
              'Total estimado',
              Text(
                _formatoCentavos(total),
                key: const ValueKey('pedido-total-estimado'),
                style: BarroTheme.type(14, 20, weight: FontWeight.w700),
              ),
            ),
            fila(
              'Anticipo',
              Text(
                anticipo == null ? '—' : '− ${_formatoCentavos(anticipo)}',
                style: BarroTheme.type(
                  14,
                  20,
                  weight: FontWeight.w700,
                  color: BarroTheme.success,
                ),
              ),
            ),
            const Divider(height: 16, color: BarroTheme.border),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Saldo pendiente estimado',
                    style: BarroTheme.type(15, 22, weight: FontWeight.w700),
                  ),
                ),
                Text(
                  saldo == null ? '—' : _formatoCentavos(saldo),
                  key: const ValueKey('pedido-saldo-estimado'),
                  style: BarroTheme.type(
                    20,
                    28,
                    weight: FontWeight.w700,
                    color: BarroTheme.primary,
                  ),
                ),
              ],
            ),
            if (excedido) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 16,
                    color: BarroTheme.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'El anticipo supera el total estimado.',
                      style: BarroTheme.type(13, 20, color: BarroTheme.error),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    },
  );

  ProductoPedido _productoPorId(int id) =>
      _productos.firstWhere((producto) => producto.id == id);

  String _ubicacion(ProductoPedido p) => [
    p.area,
    p.categoria,
  ].whereType<String>().where((t) => t.trim().isNotEmpty).join(' · ');

  Future<void> _seleccionarProducto() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final elegido = await seleccionarProductoPedido(
      context,
      productos: _productos,
      agregados: {for (final l in _lineas) l.productoId: l.cantidad},
      seleccionado: _producto,
    );
    if (elegido != null && mounted) {
      setState(() {
        _producto = elegido;
        if (_cantidad.text.trim().isEmpty) _cantidad.text = '1';
        _limpiarErroresProductos();
      });
    }
  }

  void _quitarSeleccion() => setState(() {
    _producto = null;
    _cantidad.clear();
    _limpiarErroresProductos();
  });

  /// Campo para abrir el buscador o, si ya se eligió, tarjeta del producto.
  Widget _selectorProducto() {
    final seleccionados = _productos.where((p) => p.id == _producto);
    final seleccionado = seleccionados.isEmpty ? null : seleccionados.first;
    if (seleccionado == null) {
      return InkWell(
        key: const ValueKey('pedido-selector-producto'),
        onTap: _productos.isEmpty ? null : _seleccionarProducto,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: productoDecoracion(error: _errores['productos']),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: productoSuave,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.search, color: BarroTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selecciona un producto',
                      style: BarroTheme.type(14, 21, weight: FontWeight.w700),
                    ),
                    Text(
                      'Busca por nombre, área o categoría',
                      style: BarroTheme.type(
                        12,
                        18,
                        color: BarroTheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: BarroTheme.secondary),
            ],
          ),
        ),
      );
    }
    final ubicacion = _ubicacion(seleccionado);
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: BarroTheme.primary),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _seleccionarProducto,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
          child: Row(
            children: [
              ProductoImagen(size: 56, url: seleccionado.imagenUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      seleccionado.nombre,
                      key: const ValueKey('pedido-producto-seleccionado'),
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
                    Text(
                      '${formatoPrecio(seleccionado.precio)} c/u',
                      style: BarroTheme.type(
                        13,
                        19,
                        weight: FontWeight.w700,
                        color: BarroTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cambiar producto',
                icon: const Icon(Icons.swap_horiz),
                onPressed: _seleccionarProducto,
              ),
              IconButton(
                tooltip: 'Quitar selección de producto',
                icon: const Icon(Icons.close),
                onPressed: _quitarSeleccion,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _botonCantidad(
    IconData icono,
    String tooltip,
    VoidCallback? onPressed,
  ) => IconButton.outlined(
    tooltip: tooltip,
    icon: Icon(icono, size: 20),
    onPressed: onPressed,
    style: IconButton.styleFrom(
      foregroundColor: BarroTheme.primary,
      backgroundColor: Colors.white,
      side: const BorderSide(color: BarroTheme.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      minimumSize: const Size(50, 50),
    ),
  );

  void _sumarCantidad(int delta) {
    final actual = int.tryParse(_cantidad.text.trim()) ?? 0;
    final nueva = (actual + delta).clamp(1, 2147483647);
    _cantidad.value = TextEditingValue(
      text: '$nueva',
      selection: TextSelection.collapsed(offset: '$nueva'.length),
    );
  }

  String _textoSiguienteEscalon(ProductoPedido producto, int siguiente) =>
      'Desde $siguiente piezas aplica mayoreo de '
      '${(producto.porcentajePara(siguiente) ?? 0).toStringAsFixed(2)} %';

  /// Texto bajo la cantidad: subtotal estimado y aviso del mayoreo.
  Widget _vistaPreviaCantidad(
    ProductoPedido producto,
  ) => ValueListenableBuilder<TextEditingValue>(
    valueListenable: _cantidad,
    builder: (context, valor, _) {
      final cantidad = int.tryParse(valor.text.trim());
      if (cantidad == null || cantidad <= 0) {
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Número de piezas de este producto. El descuento de mayoreo se aplica según la cantidad.',
            style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
          ),
        );
      }
      final porcentaje = producto.porcentajePara(cantidad);
      final siguiente = producto.siguienteEscalon(cantidad);
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Subtotal estimado',
                    style: BarroTheme.type(13, 19, color: BarroTheme.secondary),
                  ),
                ),
                Text(
                  _formatoCentavos(producto.subtotalEstimadoCentavos(cantidad)),
                  style: BarroTheme.type(15, 21, weight: FontWeight.w700),
                ),
              ],
            ),
            if (porcentaje != null)
              _avisoMayoreo(
                'Incluye mayoreo de ${porcentaje.toStringAsFixed(2)} %',
              )
            else if (siguiente != null)
              _avisoMayoreo(
                _textoSiguienteEscalon(producto, siguiente),
                sugerencia: true,
              ),
          ],
        ),
      );
    },
  );

  Widget _avisoMayoreo(String texto, {bool sugerencia = false}) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        Icon(
          sugerencia ? Icons.lightbulb_outline : Icons.sell_outlined,
          size: 14,
          color: sugerencia ? BarroTheme.secondary : BarroTheme.success,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            texto,
            style: BarroTheme.type(
              12,
              18,
              weight: sugerencia ? FontWeight.w400 : FontWeight.w700,
              color: sugerencia ? BarroTheme.secondary : BarroTheme.success,
            ),
          ),
        ),
      ],
    ),
  );

  /// Panel para elegir un producto, indicar las piezas y agregarlo.
  Widget _panelAgregar() {
    final seleccionados = _productos.where((p) => p.id == _producto);
    final seleccionado = seleccionados.isEmpty ? null : seleccionados.first;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: productoSuave.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BarroTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _selectorProducto(),
          if (_productos.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No hay productos disponibles en este negocio.'),
            ),
          if (seleccionado != null) ...[
            const SizedBox(height: 14),
            const ProductoEtiqueta('Cantidad *'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _botonCantidad(
                  Icons.remove,
                  'Restar una pieza',
                  () => _sumarCantidad(-1),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    key: const ValueKey('pedido-cantidad'),
                    controller: _cantidad,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 10,
                    inputFormatters: PedidoInputFormatters.cantidad,
                    style: BarroTheme.type(16, 22, weight: FontWeight.w700),
                    decoration: productoDecoracion(
                      hint: 'Ej. 10',
                    ).copyWith(counterText: ''),
                    validator: (valor) =>
                        _producto == null && (valor ?? '').trim().isEmpty
                        ? null
                        : PedidoInputFormatters.validarCantidad(valor),
                  ),
                ),
                const SizedBox(width: 8),
                _botonCantidad(
                  Icons.add,
                  'Sumar una pieza',
                  () => _sumarCantidad(1),
                ),
              ],
            ),
            _vistaPreviaCantidad(seleccionado),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: BarroTheme.primary,
                  side: const BorderSide(color: BarroTheme.primary),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                  textStyle: BarroTheme.type(14, 20, weight: FontWeight.w700),
                ),
                onPressed: _agregarProducto,
                icon: const Icon(Icons.add_shopping_cart_outlined, size: 20),
                label: const Text('Agregar producto'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _editarCantidad(int indice) async {
    final linea = _lineas[indice];
    final controlador = TextEditingController(text: '${linea.cantidad}');
    final nueva = await showDialog<int>(
      context: context,
      builder: (ctx) {
        void aceptar() {
          final valor = int.tryParse(controlador.text.trim());
          if (valor != null &&
              PedidoInputFormatters.validarCantidad(controlador.text) == null) {
            Navigator.pop(ctx, valor);
          }
        }

        return AlertDialog(
          title: Text(_productoPorId(linea.productoId).nombre),
          content: TextField(
            controller: controlador,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: PedidoInputFormatters.cantidad,
            decoration: productoDecoracion(hint: 'Piezas'),
            onSubmitted: (_) => aceptar(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(onPressed: aceptar, child: const Text('Guardar')),
          ],
        );
      },
    );
    controlador.dispose();
    if (nueva != null && mounted && indice < _lineas.length) {
      setState(() {
        _lineas[indice] = _lineas[indice].conCantidad(nueva);
        _limpiarErroresProductos();
      });
    }
  }

  void _cambiarCantidadLinea(int indice, int delta) => setState(() {
    final linea = _lineas[indice];
    _lineas[indice] = linea.conCantidad(
      (linea.cantidad + delta).clamp(1, 2147483647),
    );
    _limpiarErroresProductos();
  });

  /// Renglón del pedido. Editable en el paso 1 (cantidad, descuento, quitar);
  /// de solo lectura en el resumen del pago.
  Widget _tarjetaLinea(
    int indice,
    LineaPedido linea, {
    required bool editable,
  }) {
    final producto = _productoPorId(linea.productoId);
    final porcentaje = producto.porcentajePara(linea.cantidad);
    final aplicado = porcentaje != null && linea.aplicarDescuento;
    final subtotal = producto.subtotalEstimadoCentavos(
      linea.cantidad,
      conDescuento: linea.aplicarDescuento,
    );
    final siguiente = producto.siguienteEscalon(linea.cantidad);
    final conError =
        _errores.containsKey('productos[$indice]') ||
        _errores.containsKey('productos[$indice].cantidad');
    return Container(
      key: ValueKey('pedido-linea-${linea.productoId}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: conError ? BarroTheme.error : BarroTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProductoImagen(size: 56, url: producto.imagenUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      producto.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: BarroTheme.type(15, 21, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      editable
                          ? '${formatoPrecio(producto.precio)} c/u'
                          : '${linea.cantidad} × ${formatoPrecio(producto.precio)}',
                      style: BarroTheme.type(
                        13,
                        19,
                        color: BarroTheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (editable)
                IconButton(
                  tooltip: 'Quitar ${producto.nombre}',
                  icon: const Icon(Icons.delete_outline),
                  color: BarroTheme.secondary,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() {
                    _lineas.remove(linea);
                    _limpiarErroresProductos();
                  }),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (editable)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: BarroTheme.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Restar una pieza de ${producto.nombre}',
                        icon: const Icon(Icons.remove, size: 18),
                        visualDensity: VisualDensity.compact,
                        onPressed: linea.cantidad <= 1
                            ? null
                            : () => _cambiarCantidadLinea(indice, -1),
                      ),
                      Tooltip(
                        message: 'Editar cantidad',
                        child: InkWell(
                          onTap: () => _editarCantidad(indice),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 28),
                              child: Text(
                                '${linea.cantidad}',
                                key: ValueKey(
                                  'pedido-linea-cantidad-${linea.productoId}',
                                ),
                                textAlign: TextAlign.center,
                                style: BarroTheme.type(
                                  15,
                                  21,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Sumar una pieza de ${producto.nombre}',
                        icon: const Icon(Icons.add, size: 18),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _cambiarCantidadLinea(indice, 1),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  formatoPiezas(linea.cantidad),
                  style: BarroTheme.type(13, 19, color: BarroTheme.secondary),
                ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (aplicado)
                    Text(
                      _formatoCentavos(
                        producto.subtotalEstimadoCentavos(
                          linea.cantidad,
                          conDescuento: false,
                        ),
                      ),
                      style: BarroTheme.type(
                        12,
                        16,
                        color: BarroTheme.placeholder,
                      ).copyWith(decoration: TextDecoration.lineThrough),
                    ),
                  Text(
                    _formatoCentavos(subtotal),
                    style: BarroTheme.type(16, 22, weight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
          if (porcentaje != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: EdgeInsets.fromLTRB(
                12,
                editable ? 2 : 8,
                editable ? 4 : 12,
                editable ? 2 : 8,
              ),
              decoration: BoxDecoration(
                color: aplicado ? const Color(0xFFECF7F0) : productoSuave,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.sell_outlined,
                    size: 16,
                    color: aplicado ? BarroTheme.success : BarroTheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      editable
                          ? aplicado
                                ? 'Aplica descuento de mayoreo: ${porcentaje.toStringAsFixed(2)} %'
                                : 'Descuento de ${porcentaje.toStringAsFixed(2)} % disponible, sin aplicar'
                          : aplicado
                          ? 'Mayoreo ${porcentaje.toStringAsFixed(2)} % aplicado'
                          : 'Descuento de mayoreo no aplicado',
                      style: BarroTheme.type(
                        12,
                        18,
                        weight: FontWeight.w700,
                        color: aplicado
                            ? BarroTheme.success
                            : BarroTheme.secondary,
                      ),
                    ),
                  ),
                  // El vendedor decide si usa el descuento vigente.
                  if (editable)
                    Switch(
                      key: ValueKey('aplicar-descuento-${linea.productoId}'),
                      value: linea.aplicarDescuento,
                      onChanged: (aplicar) => setState(
                        () => _lineas[indice] = linea.conDescuento(aplicar),
                      ),
                    ),
                ],
              ),
            ),
          ] else if (editable && siguiente != null)
            _avisoMayoreo(
              _textoSiguienteEscalon(producto, siguiente),
              sugerencia: true,
            ),
        ],
      ),
    );
  }

  /// Productos ya agregados con su total, o un aviso si aún no hay.
  Widget _listaLineas() {
    if (_lineas.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BarroTheme.border),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.shopping_basket_outlined,
              size: 32,
              color: BarroTheme.placeholder,
            ),
            const SizedBox(height: 6),
            Text(
              'Aún no hay productos en el pedido',
              textAlign: TextAlign.center,
              style: BarroTheme.type(14, 20, weight: FontWeight.w700),
            ),
            Text(
              'Los productos que agregues aparecerán aquí.',
              textAlign: TextAlign.center,
              style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
            ),
          ],
        ),
      );
    }
    final piezas = _lineas.fold<int>(0, (t, l) => t + l.cantidad);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, linea) in _lineas.indexed)
          _tarjetaLinea(i, linea, editable: true),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: productoSuave,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total estimado',
                      style: BarroTheme.type(14, 20, weight: FontWeight.w700),
                    ),
                    Text(
                      '${_lineas.length} ${_lineas.length == 1 ? 'producto' : 'productos'} · ${formatoPiezas(piezas)}',
                      style: BarroTheme.type(
                        12,
                        18,
                        color: BarroTheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatoCentavos(_totalEstimadoCentavos),
                key: const ValueKey('pedido-total-lineas'),
                style: BarroTheme.type(
                  18,
                  24,
                  weight: FontWeight.w700,
                  color: BarroTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _campo(
    String label,
    TextEditingController controller, {
    String? hint,
    String? campo,
    int? maxLength,
    TextInputType? teclado,
    String? Function(String?)? validar,
    List<TextInputFormatter>? formatos,
    bool normalizarEspacios = false,
    String? ayuda,
    bool habilitado = true,
    IconData? icono,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProductoEtiqueta(label),
        Focus(
          onFocusChange: (enfocado) {
            if (!enfocado && normalizarEspacios && mounted) {
              _limpiarTexto(controller);
            }
          },
          child: TextFormField(
            controller: controller,
            enabled: habilitado,
            maxLength: maxLength,
            keyboardType: teclado,
            inputFormatters: formatos,
            decoration: productoDecoracion(hint: hint, error: _errores[campo])
                .copyWith(
                  counterText: '',
                  prefixIcon: icono == null
                      ? null
                      : Icon(icono, size: 20, color: BarroTheme.secondary),
                  helperText: ayuda,
                  helperMaxLines: 3,
                  helperStyle: BarroTheme.type(
                    12,
                    18,
                    color: BarroTheme.secondary,
                  ),
                ),
            validator: validar,
            onChanged: (_) {
              if (campo != null && _errores.containsKey(campo)) {
                setState(() {
                  _errores.remove(campo);
                  _error = _errores.isEmpty ? null : _resumenErrores(_errores);
                });
              }
            },
          ),
        ),
      ],
    ),
  );

  /// Leyenda bajo los campos que no son de texto (selectores).
  Widget _leyenda(String texto) => Padding(
    padding: const EdgeInsets.only(top: 6, left: 12, right: 12),
    child: Text(
      texto,
      style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
    ),
  );

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    final monto = double.tryParse(_monto.text.replaceAll(',', '.'));
    if (monto == null ||
        !monto.isFinite ||
        monto < 0 ||
        !RegExp(r'^\d+(?:[.,]\d{1,2})?$').hasMatch(_monto.text.trim())) {
      setState(
        () => _error = 'Ingresa un importe válido con hasta dos decimales.',
      );
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.gestion.registrar(
        DatosPedido(
          sucursalId: widget.sucursalId,
          descripcion: _descripcion.text,
          cliente: _nombre.text,
          telefono: _telefono.text,
          ciudad: _ciudad.text,
          colonia: _colonia.text,
          calle: _calle.text,
          productos: List.unmodifiable(_lineas),
          tipoEntrega: _entrega,
          descripcionEnvio: _envio.text,
          monto: monto,
          metodo: _metodo,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errores = Map.of(e.fieldErrors);
          _error = _errores.isNotEmpty
              ? _resumenErrores(_errores)
              : e.code == 'CORTE_CAJA_NO_ABIERTO'
              ? '${e.message} También puedes registrar el pedido con anticipo 0.'
              : e.statusCode == 400 &&
                    e.message == 'Revisa los datos del formulario.'
              ? 'El servidor rechazó el pedido sin indicar el motivo. Confirma que el backend esté actualizado y vuelve a intentarlo.'
              : e.message;
          if (e.code == 'PRODUCTO_NO_DISPONIBLE' ||
              _errores.keys.any(
                (campo) =>
                    campo.startsWith('productos') ||
                    campo == 'descripcion' ||
                    campo == 'tipoEntrega' ||
                    campo == 'descripcionEnvio',
              )) {
            _paso = 0;
          } else if (_errores.keys.any(
            (campo) => campo == 'cliente' || campo.startsWith('cliente.'),
          )) {
            _paso = 1;
          } else if (_errores.keys.any(
            (campo) => campo.startsWith('pagoInicial'),
          )) {
            _paso = 2;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _continuar() {
    _limpiarTextos();
    if (!_form.currentState!.validate()) return;
    if (_paso == 0) {
      if (_producto != null && !_agregarProducto()) return;
      if (_lineas.isEmpty) {
        setState(() => _error = 'Agrega al menos un producto.');
        return;
      }
    }
    if (_paso < 2) {
      setState(() {
        _paso++;
        _error = null;
      });
    } else {
      _guardar();
    }
  }

  bool _agregarProducto() {
    final cantidad = int.tryParse(_cantidad.text.trim());
    if (_producto == null) {
      setState(() => _error = 'Selecciona un producto antes de agregarlo.');
      return false;
    }
    if (cantidad == null ||
        PedidoInputFormatters.validarCantidad(_cantidad.text) != null) {
      setState(() => _error = 'Ingresa una cantidad entera mayor que cero.');
      return false;
    }
    if (_lineas.any((linea) => linea.productoId == _producto)) {
      setState(
        () => _error =
            'Ese producto ya está agregado. Elimínalo si deseas cambiar su cantidad.',
      );
      return false;
    }
    if (_lineas.length >= 100) {
      setState(() => _error = 'Puedes agregar hasta 100 productos.');
      return false;
    }
    setState(() {
      _lineas.add(LineaPedido(productoId: _producto!, cantidad: cantidad));
      // Deja listo el formulario para el siguiente producto.
      _producto = null;
      _cantidad.clear();
      _limpiarErroresProductos();
      _error = null;
    });
    return true;
  }

  /// Si ya se capturó algo que se perdería al salir.
  bool get _hayDatos =>
      _lineas.isNotEmpty ||
      _producto != null ||
      [
        _descripcion,
        _cantidad,
        _envio,
        _nombre,
        _telefono,
        _ciudad,
        _colonia,
        _calle,
      ].any((c) => c.text.trim().isNotEmpty);

  /// Sale desde la barra inferior: cierra el registro (pidiendo confirmación si
  /// hay datos capturados) y después abre [destino], si hay uno.
  Future<void> _salir(VoidCallback? destino) async {
    if (_guardando) return;
    if (_hayDatos) {
      final salir = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Salir sin registrar el pedido?'),
          content: const Text('Se perderán los datos que capturaste.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Seguir capturando'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salir'),
            ),
          ],
        ),
      );
      if (salir != true || !mounted) return;
    }
    Navigator.of(context).pop();
    destino?.call();
  }

  List<Widget> _pasoPedido() => [
    Text(
      'El folio se generará automáticamente.',
      style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
    ),
    const SizedBox(height: 12),
    _campo(
      'Descripción del pedido',
      _descripcion,
      hint: 'Ej. Personalizados con logotipo',
      maxLength: 2000,
      campo: 'descripcion',
      ayuda:
          'Opcional. Detalles generales del pedido, como personalización, colores o acabados.',
      formatos: PedidoInputFormatters.texto,
      normalizarEspacios: true,
    ),
    const SizedBox(height: 6),
    Row(
      children: [
        Expanded(
          child: Text(
            'Productos del pedido',
            style: BarroTheme.type(17, 24, weight: FontWeight.w700),
          ),
        ),
        if (_lineas.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: productoSuave,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_lineas.length}',
              style: BarroTheme.type(
                12,
                18,
                weight: FontWeight.w700,
                color: BarroTheme.primary,
              ),
            ),
          ),
      ],
    ),
    Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 10),
      child: Text(
        'Elige un producto, indica las piezas y agrégalo. Repite para agregar más.',
        style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
      ),
    ),
    _panelAgregar(),
    const SizedBox(height: 14),
    _listaLineas(),
    const SizedBox(height: 24),
    const ProductoEtiqueta('Tipo de entrega *'),
    ProductoSelector<String>(
      valor: _entrega,
      opciones: const [('LOCAL', 'En sucursal'), ('DOMICILIO', 'A domicilio')],
      onChanged: (v) => setState(() => _entrega = v!),
    ),
    _leyenda(
      'En sucursal: el cliente lo recoge. A domicilio: se envía a la dirección del cliente.',
    ),
    const SizedBox(height: 14),
    _campo(
      'Descripción de envío',
      _envio,
      hint: 'Ej. Entregar por la tarde, casa con portón azul',
      maxLength: 2000,
      campo: 'descripcionEnvio',
      ayuda:
          'Opcional. Indicaciones para la entrega, como horario o referencias.',
      formatos: PedidoInputFormatters.texto,
      normalizarEspacios: true,
    ),
  ];

  static const _pasos = [
    ('Pedido', Icons.inventory_2_outlined),
    ('Cliente', Icons.person_outline),
    ('Pago', Icons.payments_outlined),
  ];

  /// Regresa a un paso ya completado sin perder lo capturado.
  void _irAPaso(int paso) {
    if (_guardando || paso < 0 || paso >= _paso) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _limpiarTextos();
    setState(() {
      _paso = paso;
      _error = null;
    });
  }

  /// Botón atrás del sistema: retrocede un paso; en el primero, sale (con
  /// confirmación si hay datos capturados).
  void _alRetroceder(bool salio, Object? _) {
    if (salio) return;
    if (_paso > 0) {
      _irAPaso(_paso - 1);
    } else {
      _salir(null);
    }
  }

  Widget _indicadorPasos() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (i, (titulo, icono)) in _pasos.indexed) ...[
        if (i > 0)
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.only(top: 21),
              decoration: BoxDecoration(
                color: i <= _paso ? BarroTheme.primary : BarroTheme.border,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        _pasoIndicador(i, titulo, icono),
      ],
    ],
  );

  Widget _pasoIndicador(int i, String titulo, IconData icono) {
    final completado = i < _paso;
    final actual = i == _paso;
    final circulo = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: completado || actual ? BarroTheme.primary : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: completado || actual ? BarroTheme.primary : BarroTheme.border,
          width: 1.5,
        ),
        boxShadow: actual
            ? [
                BoxShadow(
                  color: BarroTheme.primary.withValues(alpha: 0.25),
                  blurRadius: 0,
                  spreadRadius: 4,
                ),
              ]
            : null,
      ),
      child: Icon(
        completado ? Icons.check_rounded : icono,
        size: 22,
        color: completado || actual ? Colors.white : BarroTheme.placeholder,
      ),
    );
    final contenido = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        circulo,
        const SizedBox(height: 6),
        Text(
          titulo,
          style: BarroTheme.type(
            12,
            16,
            weight: actual ? FontWeight.w700 : FontWeight.w500,
            color: actual || completado
                ? BarroTheme.primary
                : BarroTheme.placeholder,
          ),
        ),
      ],
    );
    return Semantics(
      button: completado,
      selected: actual,
      label: 'Paso ${i + 1} de 3: $titulo',
      child: completado
          ? Tooltip(
              message: 'Volver a $titulo',
              child: InkWell(
                key: ValueKey('pedido-paso-$i'),
                borderRadius: BorderRadius.circular(12),
                onTap: _guardando ? null : () => _irAPaso(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: contenido,
                ),
              ),
            )
          : Padding(
              key: ValueKey('pedido-paso-$i'),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: contenido,
            ),
    );
  }

  /// Tarjeta con encabezado (icono, título y descripción) para agrupar campos.
  Widget _seccion({
    required IconData icono,
    required String titulo,
    String? subtitulo,
    Widget? accion,
    required List<Widget> children,
  }) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: BarroTheme.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: productoSuave,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icono, size: 20, color: BarroTheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: BarroTheme.type(16, 22, weight: FontWeight.w700),
                  ),
                  if (subtitulo != null)
                    Text(
                      subtitulo,
                      style: BarroTheme.type(
                        12,
                        18,
                        color: BarroTheme.secondary,
                      ),
                    ),
                ],
              ),
            ),
            ?accion,
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    ),
  );

  Widget _botonEditar(int paso) => TextButton.icon(
    onPressed: _guardando ? null : () => _irAPaso(paso),
    icon: const Icon(Icons.edit_outlined, size: 16),
    label: const Text('Editar'),
    style: TextButton.styleFrom(
      visualDensity: VisualDensity.compact,
      textStyle: BarroTheme.type(13, 18, weight: FontWeight.w700),
    ),
  );

  /// Renglón compacto del resumen del pago.
  Widget _filaResumen(LineaPedido linea) {
    final producto = _productoPorId(linea.productoId);
    final porcentaje = producto.porcentajePara(linea.cantidad);
    final aplicado = porcentaje != null && linea.aplicarDescuento;
    return Padding(
      key: ValueKey('pedido-resumen-${linea.productoId}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          ProductoImagen(size: 44, url: producto.imagenUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BarroTheme.type(14, 20, weight: FontWeight.w700),
                ),
                Text(
                  '${linea.cantidad} × ${formatoPrecio(producto.precio)}',
                  style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
                ),
                if (porcentaje != null)
                  Text(
                    aplicado
                        ? 'Mayoreo ${porcentaje.toStringAsFixed(2)} % aplicado'
                        : 'Mayoreo no aplicado',
                    style: BarroTheme.type(
                      11,
                      16,
                      weight: FontWeight.w700,
                      color: aplicado
                          ? BarroTheme.success
                          : BarroTheme.placeholder,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (aplicado)
                Text(
                  _formatoCentavos(
                    producto.subtotalEstimadoCentavos(
                      linea.cantidad,
                      conDescuento: false,
                    ),
                  ),
                  style: BarroTheme.type(
                    11,
                    16,
                    color: BarroTheme.placeholder,
                  ).copyWith(decoration: TextDecoration.lineThrough),
                ),
              Text(
                _formatoCentavos(
                  producto.subtotalEstimadoCentavos(
                    linea.cantidad,
                    conDescuento: linea.aplicarDescuento,
                  ),
                ),
                style: BarroTheme.type(14, 20, weight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dato(IconData icono, String texto, {String? etiqueta}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 18, color: BarroTheme.secondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (etiqueta != null)
                Text(
                  etiqueta,
                  style: BarroTheme.type(11, 16, color: BarroTheme.placeholder),
                ),
              Text(texto, style: BarroTheme.type(14, 20)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _opcionMetodo(String valor, String texto, IconData icono) {
    final activo = _metodo == valor;
    return Expanded(
      child: Semantics(
        selected: activo,
        button: true,
        child: Material(
          color: activo ? productoSuave : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: activo ? BarroTheme.primary : BarroTheme.border,
              width: activo ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('pedido-metodo-$valor'),
            onTap: () => setState(() => _metodo = valor),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                children: [
                  Icon(
                    icono,
                    color: activo ? BarroTheme.primary : BarroTheme.secondary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    texto,
                    style: BarroTheme.type(
                      13,
                      18,
                      weight: FontWeight.w700,
                      color: activo ? BarroTheme.primary : BarroTheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _direccion() => [_calle.text, _colonia.text, _ciudad.text]
      .map(PedidoInputFormatters.limpiarEspacios)
      .where((t) => t.isNotEmpty)
      .join(', ');

  List<Widget> _pasoCliente() => [
    _seccion(
      icono: Icons.person_outline,
      titulo: 'Datos de contacto',
      subtitulo: 'A nombre de quién va el pedido y cómo avisarle.',
      children: [
        _campo(
          'Nombre del cliente *',
          _nombre,
          icono: Icons.badge_outlined,
          validar: PedidoInputFormatters.validarNombre,
          formatos: PedidoInputFormatters.nombre,
          normalizarEspacios: true,
          campo: 'cliente.nombre',
          maxLength: 150,
          hint: 'Ej. Juan Pérez',
          ayuda: 'Nombre y apellidos del cliente, solo letras.',
        ),
        _campo(
          'Teléfono *',
          _telefono,
          icono: Icons.phone_outlined,
          validar: PedidoInputFormatters.validarTelefono,
          formatos: PedidoInputFormatters.telefono,
          campo: 'cliente.telefono',
          maxLength: 10,
          hint: 'Ej. 4421234567',
          ayuda:
              '10 dígitos, sin espacios ni guiones. Se usa para avisarle del pedido.',
          teclado: TextInputType.phone,
        ),
      ],
    ),
    _seccion(
      icono: _entrega == 'DOMICILIO'
          ? Icons.local_shipping_outlined
          : Icons.location_on_outlined,
      titulo: 'Dirección',
      subtitulo: _entrega == 'DOMICILIO'
          ? 'Entrega a domicilio: captura la dirección completa.'
          : 'Opcional. El cliente recoge el pedido en la sucursal.',
      children: [
        _campo(
          'Ciudad',
          _ciudad,
          icono: Icons.location_city_outlined,
          campo: 'cliente.ciudad',
          maxLength: 120,
          hint: 'Ej. Querétaro',
          ayuda: 'Opcional. Ciudad del cliente o de entrega.',
          formatos: PedidoInputFormatters.texto,
          normalizarEspacios: true,
        ),
        _campo(
          'Colonia',
          _colonia,
          icono: Icons.map_outlined,
          campo: 'cliente.colonia',
          maxLength: 120,
          hint: 'Ej. Centro',
          ayuda: 'Opcional. Colonia o fraccionamiento.',
          formatos: PedidoInputFormatters.texto,
          normalizarEspacios: true,
        ),
        _campo(
          'Calle y número',
          _calle,
          icono: Icons.home_outlined,
          campo: 'cliente.calle',
          maxLength: 200,
          hint: 'Ej. Hidalgo 123',
          ayuda: _entrega == 'DOMICILIO'
              ? 'Calle y número donde se entrega el pedido.'
              : 'Opcional. Calle y número del cliente.',
          formatos: PedidoInputFormatters.texto,
          normalizarEspacios: true,
        ),
      ],
    ),
  ];

  List<Widget> _pasoPago() {
    final piezas = _lineas.fold<int>(0, (t, l) => t + l.cantidad);
    final direccion = _direccion();
    final envio = PedidoInputFormatters.limpiarEspacios(_envio.text);
    return [
      _seccion(
        icono: Icons.receipt_long_outlined,
        titulo: 'Resumen del pedido',
        subtitulo:
            '${_lineas.length} ${_lineas.length == 1 ? 'producto' : 'productos'} · ${formatoPiezas(piezas)}',
        accion: _botonEditar(0),
        children: [for (final linea in _lineas) _filaResumen(linea)],
      ),
      _seccion(
        icono: Icons.person_outline,
        titulo: 'Cliente y entrega',
        accion: _botonEditar(1),
        children: [
          _dato(
            Icons.badge_outlined,
            PedidoInputFormatters.limpiarEspacios(_nombre.text),
          ),
          _dato(Icons.phone_outlined, _telefono.text.trim()),
          _dato(
            _entrega == 'DOMICILIO'
                ? Icons.local_shipping_outlined
                : Icons.storefront_outlined,
            _entrega == 'DOMICILIO'
                ? 'Envío a domicilio'
                : 'Recoge en sucursal',
          ),
          if (direccion.isNotEmpty)
            _dato(Icons.location_on_outlined, direccion, etiqueta: 'Dirección'),
          if (envio.isNotEmpty)
            _dato(Icons.notes_outlined, envio, etiqueta: 'Indicaciones'),
        ],
      ),
      _seccion(
        icono: Icons.payments_outlined,
        titulo: 'Anticipo',
        subtitulo: 'Lo que el cliente paga hoy al encargar.',
        children: [
          if (_cajaAbierta) ...[
            const ProductoEtiqueta('Tipo de pago *'),
            Row(
              children: [
                _opcionMetodo('EFECTIVO', 'Efectivo', Icons.payments_outlined),
                const SizedBox(width: 10),
                _opcionMetodo('TARJETA', 'Tarjeta', Icons.credit_card),
              ],
            ),
            const SizedBox(height: 16),
          ] else ...[
            const ProductoAviso(
              'Caja cerrada: abre un turno de caja para cobrar anticipo. '
              'Puedes registrar el pedido sin anticipo y cobrarlo después.',
              error: true,
            ),
            const SizedBox(height: 16),
          ],
          _campo(
            'Anticipo *',
            _monto,
            icono: Icons.attach_money,
            teclado: const TextInputType.numberWithOptions(decimal: true),
            campo: 'pagoInicial.monto',
            formatos: PedidoInputFormatters.dinero,
            validar: PedidoInputFormatters.validarDinero,
            habilitado: _cajaAbierta,
            ayuda: _cajaAbierta
                ? 'Escribe 0 si no deja anticipo; no puede superar el total.'
                : 'Sin turno de caja abierto el anticipo queda en \$0.',
          ),
        ],
      ),
      _resumenImportes(),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: BarroTheme.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'El total definitivo se confirma al guardar con los precios vigentes del catálogo.',
              style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
            ),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: _alRetroceder,
    child: ProductoScaffold(
      barraInferior: widget.esPropietario
          ? SucursalNavegacion(
              seleccionada: 'Pedidos',
              onInicio: () => _salir(widget.onInicio),
              onPedidos: () => _salir(null),
              onCaja: () => _salir(widget.onCaja),
              onInventario: () => _salir(widget.onInventario),
            )
          : null,
      rol: widget.esPropietario ? 'Propietario' : 'Empleado',
      children: [
        TextButton.icon(
          onPressed: _paso > 0 ? () => _irAPaso(_paso - 1) : () => _salir(null),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: Text(
            _paso > 0
                ? 'Volver a ${_pasos[_paso - 1].$1.toLowerCase()}'
                : 'Pedidos',
          ),
        ),
        ProductoNegocioPanel(
          negocio: widget.negocio,
          sucursal: widget.sucursalNombre,
        ),
        const SizedBox(height: 12),
        Text(
          'Registrar pedido',
          style: BarroTheme.type(26, 34, weight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        _indicadorPasos(),
        const SizedBox(height: 20),
        if (_error != null) ...[
          ProductoAviso(_error!, error: true),
          const SizedBox(height: 12),
        ],
        if (_cargando)
          const Center(child: CircularProgressIndicator())
        else
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_paso == 0)
                  ..._pasoPedido()
                else if (_paso == 1)
                  ..._pasoCliente()
                else
                  ..._pasoPago(),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (_paso > 0) ...[
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          onPressed: _guardando
                              ? null
                              : () => _irAPaso(_paso - 1),
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: const Text('Anterior'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: BarroTheme.primary,
                            side: const BorderSide(color: BarroTheme.primary),
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                            textStyle: BarroTheme.type(
                              14,
                              20,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      flex: 3,
                      child: ProductoBoton(
                        texto: _paso == 2 ? 'Registrar pedido' : 'Continuar',
                        busy: _guardando,
                        onPressed: _continuar,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
