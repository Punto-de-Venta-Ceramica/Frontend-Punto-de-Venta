import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import '../../../../application/ports/inbound/gestion_productos_use_case.dart';
import '../../../../domain/producto.dart';
import 'producto_widgets.dart';

/// Registro (2 pasos: datos y sucursales) o edición de un producto.
/// Se cierra con el [Producto] guardado.
class ProductoFormPage extends StatefulWidget {
  const ProductoFormPage({
    required this.negocio,
    required this.gestion,
    required this.onSesionExpirada,
    this.producto,
    this.sucursal,
    super.key,
  });
  final NegocioProducto negocio;
  final GestionProductosUseCase gestion;
  final VoidCallback onSesionExpirada;
  final Producto? producto;

  /// Al registrar desde una sucursal, el producto se crea solo en ella.
  final SucursalProducto? sucursal;
  @override
  State<ProductoFormPage> createState() => _ProductoFormPageState();
}

class _ProductoFormPageState extends State<ProductoFormPage> {
  final _nombre = TextEditingController();
  final _precio = TextEditingController();
  final _minimo = TextEditingController();
  final _porcentaje = TextEditingController();
  final _existencias = <int, TextEditingController>{};
  final _seleccion = <int>{};
  final _errores = <String, String>{};
  List<AreaProducto> _areas = [];
  List<CategoriaProducto> _categorias = [];
  List<SucursalProducto> _sucursales = [];
  int? _areaId;
  int? _categoriaId;
  int _paso = 0;
  bool _cargando = true;
  bool _busy = false;
  String? _error;
  bool get _edicion => widget.producto != null;

  /// Al registrar desde una sucursal todo va en una sola pantalla: datos y existencia.
  bool get _unaPantalla => !_edicion && widget.sucursal != null;

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    if (p != null) {
      _nombre.text = p.nombre;
      _precio.text = p.precio.toStringAsFixed(2);
      _categoriaId = p.categoriaId;
      if (p.descuento != null) {
        _minimo.text = '${p.descuento!.cantidadMinima}';
        _porcentaje.text = p.descuento!.porcentajeTexto;
      }
    }
    _cargar();
  }

  @override
  void dispose() {
    for (final c in [
      _nombre,
      _precio,
      _minimo,
      _porcentaje,
      ..._existencias.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fallo(ProductoFailure e) {
    if (e.sesionExpirada) {
      widget.onSesionExpirada();
      return;
    }
    setState(() {
      _error = e.message;
      _cargando = false;
      _busy = false;
      if (e.fieldErrors.isNotEmpty) {
        for (final entry in e.fieldErrors.entries) {
          _errores[entry.key.split('.').last] = entry.value;
        }
        _paso = 0;
      }
    });
  }

  Future<void> _cargar() async {
    try {
      final id = widget.negocio.id;
      final areas = await widget.gestion.areas(id);
      final categorias = await widget.gestion.categorias(id);
      final sucursales = _edicion
          ? <SucursalProducto>[]
          : widget.sucursal != null
          ? [widget.sucursal!]
          : await widget.gestion.sucursales(id);
      if (!mounted) return;
      setState(() {
        _areas = areas;
        _categorias = categorias;
        _sucursales = sucursales;
        _areaId = categorias
            .where((c) => c.id == _categoriaId)
            .firstOrNull
            ?.areaId;
        if (sucursales.length == 1) _seleccion.add(sucursales.first.id);
        _cargando = false;
      });
    } on ProductoFailure catch (e) {
      if (mounted) _fallo(e);
    }
  }

  TextEditingController _controladorExistencia(int sucursalId) =>
      _existencias.putIfAbsent(sucursalId, () => TextEditingController());

  DatosProducto _datos({bool conExistencias = false}) => DatosProducto(
    nombre: _nombre.text,
    precio: _precio.text,
    categoriaId: _categoriaId,
    cantidadMinima: _minimo.text,
    porcentaje: _porcentaje.text,
    existencias: conExistencias
        ? [
            for (final id in _seleccion)
              ExistenciaInicial(
                sucursalId: id,
                existencia:
                    int.tryParse(_controladorExistencia(id).text.trim()) ?? 0,
              ),
          ]
        : const [],
  );

  /// Registro en una sola pantalla (sucursal): valida los datos y guarda.
  void _registrarEnSucursal() {
    FocusScope.of(context).unfocus();
    final errores = _datos().validar();
    if (errores.isNotEmpty) {
      setState(() {
        _errores
          ..clear()
          ..addAll(errores);
        _error = null;
      });
      return;
    }
    _guardar();
  }

  void _continuar() {
    FocusScope.of(context).unfocus();
    final errores = _datos().validar();
    setState(() {
      _errores
        ..clear()
        ..addAll(errores);
      _error = null;
      if (errores.isEmpty) _paso = 1;
    });
  }

  Map<int, String> _erroresExistencias() => {
    for (final id in _seleccion)
      if (!RegExp(
        r'^\d{0,7}$',
      ).hasMatch(_controladorExistencia(id).text.trim()))
        id: 'Ingresa una cantidad entera de 0 o más.',
  };

  Future<void> _guardar() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    if (!_edicion) {
      final errores = _erroresExistencias();
      if (errores.isNotEmpty) {
        setState(() {
          _errores
            ..removeWhere((k, _) => k.startsWith('existencia-'))
            ..addAll({
              for (final e in errores.entries) 'existencia-${e.key}': e.value,
            });
        });
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final guardado = _edicion
          ? await widget.gestion.editar(
              widget.producto!.id,
              widget.negocio.id,
              _datos(),
            )
          : await widget.gestion.crear(
              widget.negocio.id,
              _datos(conExistencias: true),
            );
      if (!mounted) return;
      setState(() => _busy = false);
      Navigator.of(context).pop<Producto>(guardado);
    } on ProductoFailure catch (e) {
      if (mounted) _fallo(e);
    }
  }

  void _limpiar(String clave) {
    if (_errores.containsKey(clave) || _error != null) {
      setState(() => _errores.remove(clave));
    }
  }

  Widget _texto(
    String clave,
    String etiqueta,
    TextEditingController controller, {
    String? hint,
    TextInputType? teclado,
    List<TextInputFormatter>? formatos,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ProductoEtiqueta(etiqueta),
      TextField(
        key: ValueKey('producto-$clave'),
        controller: controller,
        enabled: !_busy,
        keyboardType: teclado,
        inputFormatters: formatos,
        style: BarroTheme.type(14, 21),
        decoration: productoDecoracion(hint: hint, error: _errores[clave]),
        onChanged: (_) => _limpiar(clave),
      ),
    ],
  );

  List<Widget> _pasoDatos() {
    final categoriasDelArea = _categorias
        .where((c) => c.areaId == _areaId)
        .toList();
    final minimo = int.tryParse(_minimo.text.trim());
    final porcentaje = double.tryParse(
      _porcentaje.text.trim().replaceAll(',', '.'),
    );
    return [
      _texto(
        'nombre',
        'Nombre del producto *',
        _nombre,
        hint: 'Ej. Taza cerámica esmaltada',
      ),
      const SizedBox(height: 20),
      _texto(
        'precio',
        'Precio unitario (MXN) *',
        _precio,
        hint: '\$ 0.00',
        teclado: const TextInputType.numberWithOptions(decimal: true),
        formatos: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      ),
      const SizedBox(height: 20),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ProductoEtiqueta('Área *'),
                ProductoSelector<int>(
                  key: const ValueKey('producto-area'),
                  valor: _areaId,
                  hint: 'Área',
                  opciones: [for (final a in _areas) (a.id, a.nombre)],
                  onChanged: _busy
                      ? null
                      : (id) => setState(() {
                          _areaId = id;
                          _categoriaId = null;
                          _errores.remove('categoriaId');
                        }),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ProductoEtiqueta('Categoría *'),
                ProductoSelector<int>(
                  key: const ValueKey('producto-categoria'),
                  valor: _categoriaId,
                  hint: 'Categoría',
                  opciones: [
                    for (final c in categoriasDelArea) (c.id, c.nombre),
                  ],
                  onChanged: _busy || _areaId == null
                      ? null
                      : (id) => setState(() {
                          _categoriaId = id;
                          _errores.remove('categoriaId');
                        }),
                ),
              ],
            ),
          ),
        ],
      ),
      if (_errores['categoriaId'] != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            _errores['categoriaId']!,
            style: BarroTheme.type(12, 18, color: BarroTheme.error),
          ),
        ),
      const SizedBox(height: 24),
      Text(
        'Descuento por cantidad',
        style: BarroTheme.type(18, 26, weight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _texto(
              'cantidadMinima',
              'A partir de (piezas)',
              _minimo,
              teclado: TextInputType.number,
              formatos: [FilteringTextInputFormatter.digitsOnly],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _texto(
              'porcentaje',
              'Descuento (%)',
              _porcentaje,
              teclado: const TextInputType.numberWithOptions(decimal: true),
              formatos: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (minimo != null &&
          minimo > 0 &&
          porcentaje != null &&
          porcentaje > 0 &&
          porcentaje <= 100)
        Text(
          'Desde $minimo piezas, se aplica un ${_porcentaje.text.trim()} % de descuento.',
          style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
        ),
      const SizedBox(height: 8),
      Text(
        _edicion
            ? 'Las existencias se ajustan en Inventario.'
            : 'Usa 0 % si no deseas aplicar descuento.',
        style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
      ),
    ];
  }

  Widget _campoExistencia(SucursalProducto s, {required bool activa}) {
    final error = _errores['existencia-${s.id}'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Existencia inicial (piezas)',
          style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
        ),
        const SizedBox(height: 8),
        TextField(
          key: ValueKey('producto-existencia-${s.id}'),
          controller: _controladorExistencia(s.id),
          enabled: activa && !_busy,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: BarroTheme.type(14, 21),
          decoration: productoDecoracion(hint: '0', error: error),
          onChanged: (_) => _limpiar('existencia-${s.id}'),
        ),
      ],
    );
  }

  Widget _tarjetaSucursal(SucursalProducto s, {required bool unica}) {
    final activa = unica || _seleccion.contains(s.id);
    void alternar() {
      if (unica || _busy) return;
      setState(() {
        _seleccion.contains(s.id)
            ? _seleccion.remove(s.id)
            : _seleccion.add(s.id);
        _errores.remove('existencia-${s.id}');
      });
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: activa ? const Color(0xFFFFFBF9) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(21),
          side: BorderSide(
            color: activa ? BarroTheme.primary : BarroTheme.border,
            width: activa ? 1.6 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(21),
          onTap: unica ? null : alternar,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: productoSuave,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.storefront_outlined,
                          color: BarroTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          s.nombre,
                          style: BarroTheme.type(
                            16,
                            23,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!unica)
                        Checkbox(
                          key: ValueKey('producto-sucursal-${s.id}'),
                          value: activa,
                          activeColor: BarroTheme.primary,
                          onChanged: _busy ? null : (_) => alternar(),
                        ),
                    ],
                  ),
                  if (activa) ...[
                    const SizedBox(height: 14),
                    _campoExistencia(s, activa: true),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _pasoSucursales() {
    final unica = _sucursales.length == 1;
    final categoria = _categorias
        .where((c) => c.id == _categoriaId)
        .firstOrNull;
    final area = _areas.where((a) => a.id == categoria?.areaId).firstOrNull;
    return [
      if (unica) ...[
        Text(
          _nombre.text.trim(),
          style: BarroTheme.type(20, 28, weight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          '${formatoPrecio(_datos().precioNumero ?? 0)} · ${area?.nombre ?? ''} / ${categoria?.nombre ?? ''}',
          style: BarroTheme.type(14, 21, color: BarroTheme.secondary),
        ),
        const SizedBox(height: 24),
      ] else ...[
        Text(
          'Sucursales y existencias iniciales',
          style: BarroTheme.type(18, 26, weight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Selecciona la sucursal que quieres agregar a este producto.',
          style: BarroTheme.type(14, 21, color: BarroTheme.secondary),
        ),
        const SizedBox(height: 18),
      ],
      if (_sucursales.isEmpty)
        const ProductoAviso(
          'Este negocio aún no tiene sucursales. El producto se registrará sin existencias.',
        ),
      for (final s in _sucursales) _tarjetaSucursal(s, unica: unica),
      if (unica)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: productoSuave,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Este negocio tiene una sola sucursal.\nEl producto se asignará a ella automáticamente.',
            style: BarroTheme.type(14, 23, color: BarroTheme.secondary),
          ),
        ),
    ];
  }

  List<Widget> _seccionExistencia() {
    final s = widget.sucursal!;
    return [
      const SizedBox(height: 24),
      Text(
        'Existencia',
        style: BarroTheme.type(18, 26, weight: FontWeight.w700),
      ),
      const SizedBox(height: 4),
      Text(
        'Piezas disponibles en ${s.nombre}.',
        style: BarroTheme.type(14, 21, color: BarroTheme.secondary),
      ),
      const SizedBox(height: 12),
      _campoExistencia(s, activa: true),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final enSucursales = !_edicion && !_unaPantalla && _paso == 1;
    final unica = _sucursales.length == 1;
    final titulo = _edicion
        ? 'Editar producto'
        : enSucursales
        ? 'Disponibilidad'
        : 'Registrar producto';
    final subtitulo = _edicion
        ? 'Actualiza los datos del producto.'
        : enSucursales
        ? (unica
              ? 'Define la existencia inicial del producto.'
              : 'Selecciona dónde estará disponible.')
        : _unaPantalla
        ? 'Agrega un producto a ${widget.sucursal!.nombre}.'
        : 'Agrega un producto a tu negocio.';
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
          Text(titulo, style: BarroTheme.type(28, 36, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            subtitulo,
            style: BarroTheme.type(14, 21, color: BarroTheme.secondary),
          ),
          const SizedBox(height: 16),
          if (!_edicion && !_unaPantalla) ...[
            ProductoPasos(paso: _paso),
            const SizedBox(height: 20),
          ],
          if (_error != null) ...[
            ProductoAviso(_error!, error: true),
            const SizedBox(height: 16),
          ],
          if (_cargando)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            ...(enSucursales ? _pasoSucursales() : _pasoDatos()),
            if (_unaPantalla) ..._seccionExistencia(),
            const SizedBox(height: 32),
            ProductoBoton(
              key: const ValueKey('producto-guardar'),
              texto: _edicion
                  ? 'Guardar cambios'
                  : enSucursales || _unaPantalla
                  ? 'Registrar producto'
                  : 'Continuar',
              busy: _busy,
              onPressed: _edicion || enSucursales
                  ? _guardar
                  : _unaPantalla
                  ? _registrarEnSucursal
                  : _continuar,
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: _busy
                    ? null
                    : enSucursales
                    ? () => setState(() => _paso = 0)
                    : () => Navigator.pop(context),
                child: Text(enSucursales ? 'Volver a los datos' : 'Cancelar'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
