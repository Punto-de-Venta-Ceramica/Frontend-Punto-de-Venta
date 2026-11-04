import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/productos/domain/producto.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_widgets.dart';
import '../../../application/gestion_pedidos.dart';
import '../../../domain/pedido.dart';

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
  List<CortePedido> _cortes = [];
  final List<LineaPedido> _lineas = [];
  Map<String, String> _errores = {};
  int? _producto, _corte;
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
      final cortes = await widget.gestion.cortes(widget.sucursalId);
      if (mounted) {
        setState(() {
          _productos = productos;
          _cortes = cortes;
          if (cortes.length == 1) _corte = cortes.first.id;
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

  String? _obligatorio(String? v) =>
      v == null || v.trim().isEmpty ? 'Este campo es obligatorio.' : null;
  Widget _campo(
    String label,
    TextEditingController controller, {
    String? hint,
    String? campo,
    int? maxLength,
    TextInputType? teclado,
    String? Function(String?)? validar,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProductoEtiqueta(label),
        TextFormField(
          controller: controller,
          maxLength: maxLength,
          keyboardType: teclado,
          decoration: productoDecoracion(
            hint: hint,
            error: _errores[campo],
          ).copyWith(counterText: ''),
          validator: validar,
          onChanged: (_) {
            if (campo != null && _errores.containsKey(campo)) {
              setState(() => _errores.remove(campo));
            }
          },
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
    if (monto > 0 && _corte == null) {
      setState(
        () => _error =
            'Selecciona un corte de caja abierto para registrar el pago.',
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
          corteId: monto > 0 ? _corte : null,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _errores = Map.of(e.fieldErrors);
          if (_errores.keys.any((campo) => campo.startsWith('cliente.'))) {
            _paso = 1;
          } else if (_errores.keys.any(
            (campo) =>
                campo.startsWith('productos') ||
                campo == 'descripcion' ||
                campo == 'tipoEntrega' ||
                campo == 'descripcionEnvio',
          )) {
            _paso = 0;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _continuar() {
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
    if (_producto == null || cantidad == null || cantidad <= 0) {
      setState(
        () => _error = 'Selecciona un producto e ingresa una cantidad válida.',
      );
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
      _error = null;
    });
    return true;
  }

  @override
  Widget build(BuildContext context) => ProductoScaffold(
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
                ),
                const ProductoEtiqueta('Producto *'),
                ProductoSelector<int>(
                  valor: _producto,
                  opciones: [
                    for (final p in _productos)
                      (p.id, '${p.nombre} · ${formatoPrecio(p.precio)}'),
                  ],
                  hint: 'Selecciona un producto',
                  error: _errores['productos'],
                  onChanged: (v) => setState(() => _producto = v),
                ),
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
                  validar: (v) =>
                      int.tryParse(v ?? '') == null || int.parse(v!) <= 0
                      ? 'Ingresa una cantidad válida.'
                      : null,
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
                          onPressed: () =>
                              setState(() => _lineas.remove(linea)),
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
                _campo('Descripción de envío', _envio, maxLength: 2000),
              ] else if (_paso == 1) ...[
                _campo(
                  'Nombre del cliente *',
                  _nombre,
                  validar: _obligatorio,
                  campo: 'cliente.nombre',
                  maxLength: 150,
                ),
                _campo(
                  'Teléfono *',
                  _telefono,
                  validar: _obligatorio,
                  campo: 'cliente.telefono',
                  maxLength: 30,
                  teclado: TextInputType.phone,
                ),
                _campo(
                  'Ciudad *',
                  _ciudad,
                  validar: _obligatorio,
                  campo: 'cliente.ciudad',
                  maxLength: 120,
                ),
                _campo(
                  'Colonia *',
                  _colonia,
                  validar: _obligatorio,
                  campo: 'cliente.colonia',
                  maxLength: 120,
                ),
                _campo(
                  'Calle y número *',
                  _calle,
                  validar: _obligatorio,
                  campo: 'cliente.calle',
                  maxLength: 200,
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
                  'Cantidad pagada *',
                  _monto,
                  teclado: const TextInputType.numberWithOptions(decimal: true),
                  campo: 'pagoInicial.monto',
                  validar: _obligatorio,
                ),
                const ProductoEtiqueta('Corte de caja abierto'),
                ProductoSelector<int>(
                  valor: _corte,
                  opciones: [for (final c in _cortes) (c.id, 'Corte #${c.id}')],
                  onChanged: (v) => setState(() => _corte = v),
                ),
                if (_cortes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'No hay corte abierto. Puedes registrar el pedido sin anticipo.',
                    ),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'El total y el descuento se calculan al guardar con los precios del catálogo.',
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
