import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/productos/domain/producto.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_widgets.dart';
import '../../../application/gestion_pedidos.dart';
import '../../../domain/pedido.dart';
import 'pedido_input_formatters.dart';
import 'package:punto_de_venta/features/sucursal/infrastructure/adapters/inbound/flutter/sucursal_widgets.dart';

class RegistrarPedidoPage extends StatefulWidget {
  const RegistrarPedidoPage({
    required this.gestion,
    required this.sucursalId,
    required this.negocio,
    required this.esPropietario,
    super.key,
  });
  final GestionPedidos gestion;
  final int sucursalId;
  final NegocioProducto negocio;
  final bool esPropietario;
  @override
  State<RegistrarPedidoPage> createState() => _RegistrarPedidoPageState();
}

class _RegistrarPedidoPageState extends State<RegistrarPedidoPage> {
  final _form = GlobalKey<FormState>();
  final _descripcion = TextEditingController();
  final _cantidad = TextEditingController(text: '1');
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
  int _paso = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final productos = await widget.gestion.productos(widget.sucursalId);
      if (mounted) {
        setState(() => _productos = productos);
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
    if (errores.containsKey('pagoInicial.corteCajaId')) {
      return 'El backend activo aún solicita un corte de caja. Reinicia el backend actualizado y vuelve a intentarlo.';
    }
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
            .subtotalEstimadoCentavos(linea.cantidad),
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 24),
          Row(
            children: [
              const Expanded(child: Text('Total estimado')),
              Text(
                _formatoCentavos(total),
                key: const ValueKey('pedido-total-estimado'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(child: Text('Saldo pendiente estimado')),
              Text(
                saldo == null ? '—' : _formatoCentavos(saldo),
                key: const ValueKey('pedido-saldo-estimado'),
                style: BarroTheme.type(15, 22, weight: FontWeight.w700),
              ),
            ],
          ),
          if (excedido) ...[
            const SizedBox(height: 8),
            Text(
              'El anticipo supera el total estimado.',
              style: BarroTheme.type(13, 20, color: BarroTheme.error),
            ),
          ],
          const Divider(height: 24),
        ],
      );
    },
  );

  String _claveProducto(String texto) => texto
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[áàäâ]'), 'a')
      .replaceAll(RegExp('[éèëê]'), 'e')
      .replaceAll(RegExp('[íìïî]'), 'i')
      .replaceAll(RegExp('[óòöô]'), 'o')
      .replaceAll(RegExp('[úùüû]'), 'u')
      .replaceAll('ñ', 'n{');

  Future<void> _seleccionarProducto() async {
    final ordenados = List<ProductoPedido>.of(_productos)
      ..sort((a, b) {
        final orden = _claveProducto(
          a.nombre,
        ).compareTo(_claveProducto(b.nombre));
        return orden != 0 ? orden : a.id.compareTo(b.id);
      });
    var busqueda = '';
    final elegido = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, actualizar) {
          final coincidencias = ordenados
              .where(
                (producto) => _claveProducto(
                  producto.nombre,
                ).contains(_claveProducto(busqueda)),
              )
              .toList();
          return AlertDialog(
            title: const Text('Selecciona un producto'),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            scrollable: true,
            content: SizedBox(
              width: 480,
              height:
                  (MediaQuery.sizeOf(context).height -
                          MediaQuery.viewInsetsOf(context).bottom -
                          200)
                      .clamp(80.0, 380.0),
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    decoration: productoDecoracion(
                      hint: 'Buscar producto',
                    ).copyWith(prefixIcon: const Icon(Icons.search)),
                    onChanged: (valor) => actualizar(() => busqueda = valor),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: coincidencias.isEmpty
                        ? const Center(
                            child: Text('No se encontraron productos.'),
                          )
                        : ListView.builder(
                            itemCount: coincidencias.length,
                            itemBuilder: (context, index) {
                              final producto = coincidencias[index];
                              return ListTile(
                                title: Text(producto.nombre),
                                subtitle: Text(formatoPrecio(producto.precio)),
                                selected: producto.id == _producto,
                                trailing: producto.id == _producto
                                    ? const Icon(Icons.check)
                                    : null,
                                onTap: () =>
                                    Navigator.pop(context, producto.id),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          );
        },
      ),
    );
    if (elegido != null && mounted) {
      setState(() {
        _producto = elegido;
        _limpiarErroresProductos();
      });
    }
  }

  Widget _selectorProducto() {
    final seleccionados = _productos.where((p) => p.id == _producto);
    final seleccionado = seleccionados.isEmpty ? null : seleccionados.first;
    return InkWell(
      onTap: _productos.isEmpty ? null : _seleccionarProducto,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: productoDecoracion(
          error: _errores['productos'],
        ).copyWith(
          suffixIcon: seleccionado == null
              ? const Icon(Icons.search)
              : IconButton(
                  tooltip: 'Quitar selección de producto',
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() {
                    _producto = null;
                    _limpiarErroresProductos();
                  }),
                ),
        ),
        child: Text(
          seleccionado == null
              ? 'Selecciona un producto'
              : '${seleccionado.nombre} · ${formatoPrecio(seleccionado.precio)}',
          style: BarroTheme.type(14, 21),
          overflow: TextOverflow.ellipsis,
        ),
      ),
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
            maxLength: maxLength,
            keyboardType: teclado,
            inputFormatters: formatos,
            decoration: productoDecoracion(
              hint: hint,
              error: _errores[campo],
            ).copyWith(counterText: ''),
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
      _producto = null;
      _cantidad.text = '1';
      _limpiarErroresProductos();
    });
    return true;
  }

  @override
  Widget build(BuildContext context) => ProductoScaffold(
    barraInferior: SucursalNavegacion(
      seleccionada: 'Pedidos',
      onPedidos: () => Navigator.of(context).maybePop(),
    ),
    rol: widget.esPropietario ? 'Propietario' : 'Empleado',
    children: [
      TextButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back, size: 18),
        label: const Text('Pedidos'),
      ),
      ProductoNegocioPanel(negocio: widget.negocio),
      const SizedBox(height: 12),
      Text(
        'Registrar pedido',
        style: BarroTheme.type(26, 34, weight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          for (final (i, title) in [
            '1. Pedido',
            '2. Cliente',
            '3. Pagar',
          ].indexed)
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: i == _paso ? productoSuave : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: BarroTheme.type(
                    11,
                    16,
                    weight: FontWeight.w700,
                    color: i == _paso
                        ? BarroTheme.primary
                        : BarroTheme.secondary,
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 18),
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
              if (_paso == 0) ...[
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
                  formatos: PedidoInputFormatters.texto,
                  normalizarEspacios: true,
                ),
                const ProductoEtiqueta('Producto *'),
                _selectorProducto(),
                if (_productos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No hay productos disponibles en este negocio.',
                    ),
                  ),
                const SizedBox(height: 14),
                _campo(
                  'Cantidad *',
                  _cantidad,
                  teclado: TextInputType.number,
                  maxLength: 10,
                  formatos: PedidoInputFormatters.cantidad,
                  validar: PedidoInputFormatters.validarCantidad,
                ),
                ProductoBoton(
                  texto: 'Agregar producto',
                  onPressed: _agregarProducto,
                ),
                for (final linea in _lineas)
                  Builder(
                    builder: (context) {
                      final producto = _productos.firstWhere(
                        (p) => p.id == linea.productoId,
                      );
                      final descuento = producto.aplicaDescuento(
                        linea.cantidad,
                      );
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${linea.cantidad} × ${producto.nombre}'),
                        subtitle: Text(
                          descuento
                              ? 'Aplica descuento de mayoreo: ${producto.porcentajeDescuento!.toStringAsFixed(2)} %'
                              : 'Sin descuento de mayoreo',
                        ),
                        trailing: IconButton(
                          tooltip: 'Quitar ${producto.nombre}',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => setState(() {
                            _lineas.remove(linea);
                            _limpiarErroresProductos();
                          }),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 12),
                const ProductoEtiqueta('Tipo de entrega *'),
                ProductoSelector<String>(
                  valor: _entrega,
                  opciones: const [
                    ('LOCAL', 'En sucursal'),
                    ('DOMICILIO', 'A domicilio'),
                  ],
                  onChanged: (v) => setState(() => _entrega = v!),
                ),
                const SizedBox(height: 14),
                _campo(
                  'Descripción de envío',
                  _envio,
                  maxLength: 2000,
                  campo: 'descripcionEnvio',
                  formatos: PedidoInputFormatters.texto,
                  normalizarEspacios: true,
                ),
              ] else if (_paso == 1) ...[
                _campo(
                  'Nombre del cliente *',
                  _nombre,
                  validar: PedidoInputFormatters.validarNombre,
                  formatos: PedidoInputFormatters.nombre,
                  normalizarEspacios: true,
                  campo: 'cliente.nombre',
                  maxLength: 150,
                ),
                _campo(
                  'Teléfono *',
                  _telefono,
                  validar: PedidoInputFormatters.validarTelefono,
                  formatos: PedidoInputFormatters.telefono,
                  campo: 'cliente.telefono',
                  maxLength: 10,
                  teclado: TextInputType.phone,
                ),
                _campo(
                  'Ciudad (opcional)',
                  _ciudad,
                  campo: 'cliente.ciudad',
                  maxLength: 120,
                  formatos: PedidoInputFormatters.texto,
                  normalizarEspacios: true,
                ),
                _campo(
                  'Colonia (opcional)',
                  _colonia,
                  campo: 'cliente.colonia',
                  maxLength: 120,
                  formatos: PedidoInputFormatters.texto,
                  normalizarEspacios: true,
                ),
                _campo(
                  'Calle y número (opcional)',
                  _calle,
                  campo: 'cliente.calle',
                  maxLength: 200,
                  formatos: PedidoInputFormatters.texto,
                  normalizarEspacios: true,
                ),
              ] else ...[
                const ProductoEtiqueta('Productos del pedido'),
                for (final linea in _lineas)
                  Builder(
                    builder: (context) {
                      final producto = _productos.firstWhere(
                        (p) => p.id == linea.productoId,
                      );
                      final descuento = producto.aplicaDescuento(
                        linea.cantidad,
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '${linea.cantidad} × ${producto.nombre} · ${descuento ? 'descuento de mayoreo ${producto.porcentajeDescuento!.toStringAsFixed(2)} %' : 'sin descuento de mayoreo'}',
                        ),
                      );
                    },
                  ),
                _resumenImportes(),
                const ProductoEtiqueta('Tipo de pago *'),
                ProductoSelector<String>(
                  valor: _metodo,
                  opciones: const [
                    ('EFECTIVO', 'Efectivo'),
                    ('TARJETA', 'Tarjeta'),
                  ],
                  onChanged: (v) => setState(() => _metodo = v!),
                ),
                const SizedBox(height: 14),
                _campo(
                  'Anticipo *',
                  _monto,
                  teclado: const TextInputType.numberWithOptions(decimal: true),
                  campo: 'pagoInicial.monto',
                  formatos: PedidoInputFormatters.dinero,
                  validar: PedidoInputFormatters.validarDinero,
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _monto,
                  builder: (context, valor, _) {
                    final anticipo = _leerCentavos(valor.text);
                    if (anticipo == null || anticipo <= BigInt.zero) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Por el momento, los anticipos requieren un corte de caja abierto. La función de corte de caja aún está en desarrollo; puedes registrar el pedido con anticipo 0.',
                        style: BarroTheme.type(13, 20, color: BarroTheme.error),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'El total definitivo se confirma al guardar con los precios vigentes del catálogo.',
                ),
              ],
              const SizedBox(height: 20),
              ProductoBoton(
                texto: _paso == 2 ? 'Registrar pedido' : 'Continuar',
                busy: _guardando,
                onPressed: _continuar,
              ),
              if (_paso > 0)
                Center(
                  child: TextButton(
                    onPressed: _guardando
                        ? null
                        : () => setState(() {
                            _paso--;
                            _error = null;
                          }),
                    child: const Text('Anterior'),
                  ),
                ),
            ],
          ),
        ),
    ],
  );
}
