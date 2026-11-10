import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/descuentos/application/ports/inbound/gestion_descuentos_use_case.dart';
import 'package:punto_de_venta/features/descuentos/domain/descuento.dart';
import 'package:punto_de_venta/features/descuentos/infrastructure/adapters/inbound/flutter/descuento_widgets.dart';
import '../../../../application/ports/inbound/gestion_productos_use_case.dart';
import '../../../../application/services/imagenes_producto.dart';
import '../../../../domain/imagen_producto.dart';
import '../../../../domain/producto.dart';
import 'producto_widgets.dart';

/// Un descuento del producto en pantalla: su línea de datos y los campos de texto.
class _FilaDescuento {
  _FilaDescuento(this.linea)
    : minimo = TextEditingController(text: linea.cantidadMinima),
      porcentaje = TextEditingController(text: linea.porcentaje);
  final LineaDescuento linea;
  final TextEditingController minimo;
  final TextEditingController porcentaje;

  /// Pasa lo escrito a la línea que se enviará al servidor.
  void sincronizar() {
    linea
      ..cantidadMinima = minimo.text
      ..porcentaje = porcentaje.text;
  }

  void dispose() {
    minimo.dispose();
    porcentaje.dispose();
  }
}

/// Registro (2 pasos: datos y sucursales) o edición de un producto.
/// Se cierra con el [Producto] guardado.
class ProductoFormPage extends StatefulWidget {
  const ProductoFormPage({
    required this.negocio,
    required this.gestion,
    required this.onSesionExpirada,
    this.imagenes,
    this.descuentos,
    this.producto,
    this.sucursal,
    this.onRegistrados,
    super.key,
  });

  /// Al terminar de registrar, informa cuántos productos se registraron en esta
  /// pantalla (más de uno cuando se usa "Crear más productos").
  final void Function(int cantidad)? onRegistrados;
  final NegocioProducto negocio;
  final GestionProductosUseCase gestion;
  final ImagenesProducto? imagenes;
  final VoidCallback onSesionExpirada;

  /// Descuentos opcionales del producto (varios). Sin esto no se muestra la sección.
  final GestionDescuentosUseCase? descuentos;
  final Producto? producto;

  /// Al registrar desde una sucursal, el producto se crea solo en ella.
  final SucursalProducto? sucursal;
  @override
  State<ProductoFormPage> createState() => _ProductoFormPageState();
}

class _ProductoFormPageState extends State<ProductoFormPage> {
  final _nombre = TextEditingController();
  final _precio = TextEditingController();
  final _existencias = <int, TextEditingController>{};
  final _seleccion = <int>{};
  final _errores = <String, String>{};
  final _filas = <_FilaDescuento>[];

  /// Descuentos existentes que el usuario quitó; se eliminan al guardar.
  final _eliminados = <int>{};
  final _erroresFilas = <int, Map<String, String>>{};
  int _compartidos = 0;

  /// El producto ya se creó pero algo posterior falló: reintentar lo edita.
  Producto? _productoGuardado;
  ArchivoImagenProducto? _imagenPendiente;
  String? _imagenUrl;
  String? _imagenPublicId;
  double? _progresoImagen;

  /// "Crear más productos": al registrar, el formulario se reinicia para el siguiente.
  bool _crearMas = false;
  int _registrados = 0;
  Producto? _ultimo;
  String? _aviso;
  final _arriba = GlobalKey();
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
  bool get _permiteTomarFoto =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

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
      _imagenUrl = p.imagenUrl;
      _imagenPublicId = p.imagenPublicId;
    }
    _cargar();
  }

  @override
  void dispose() {
    for (final c in [_nombre, _precio, ..._existencias.values]) {
      c.dispose();
    }
    for (final f in _filas) {
      f.dispose();
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
      final descuentos = _edicion && widget.descuentos != null
          ? await widget.descuentos!.delProducto(id, widget.producto!.id)
          : const DescuentosDeProducto();
      if (!mounted) return;
      setState(() {
        for (final d in descuentos.propios) {
          _filas.add(_FilaDescuento(LineaDescuento.desde(d)));
        }
        _compartidos = descuentos.compartidos;
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
    } on DescuentoFailure catch (e) {
      if (!mounted) return;
      if (e.sesionExpirada) {
        widget.onSesionExpirada();
        return;
      }
      setState(() {
        _error = e.message;
        _cargando = false;
      });
    }
  }

  TextEditingController _controladorExistencia(int sucursalId) =>
      _existencias.putIfAbsent(sucursalId, () => TextEditingController());

  DatosProducto _datos({bool conExistencias = false}) => DatosProducto(
    nombre: _nombre.text,
    precio: _precio.text,
    categoriaId: _categoriaId,
    imagenUrl: _imagenUrl,
    imagenPublicId: _imagenPublicId,
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

  /// Pasa lo escrito a las líneas y valida cada descuento. Muestra los errores
  /// bajo sus campos y devuelve si todos son correctos (sin descuentos es válido).
  bool _descuentosValidos() {
    if (widget.descuentos == null) return true;
    for (final f in _filas) {
      f.sincronizar();
    }
    final errores = validarLineasDescuento([for (final f in _filas) f.linea]);
    setState(() {
      _erroresFilas
        ..clear()
        ..addAll(errores);
    });
    return errores.isEmpty;
  }

  /// Registro en una sola pantalla (sucursal): valida los datos y guarda.
  void _registrarEnSucursal() {
    FocusScope.of(context).unfocus();
    final errores = _datos().validar();
    final descuentosOk = _descuentosValidos();
    if (errores.isNotEmpty) {
      setState(() {
        _errores
          ..clear()
          ..addAll(errores);
        _error = null;
      });
      return;
    }
    if (!descuentosOk) return;
    _guardar();
  }

  void _continuar() {
    FocusScope.of(context).unfocus();
    final errores = _datos().validar();
    final descuentosOk = _descuentosValidos();
    setState(() {
      _errores
        ..clear()
        ..addAll(errores);
      _error = null;
      if (errores.isEmpty && descuentosOk) _paso = 1;
    });
  }

  Map<int, String> _erroresExistencias() => {
    for (final id in _seleccion)
      if (!RegExp(
        r'^\d{0,7}$',
      ).hasMatch(_controladorExistencia(id).text.trim()))
        id: 'Ingresa una cantidad entera de 0 o más.',
  };

  Future<void> _seleccionarImagen({required bool camara}) async {
    final servicio = widget.imagenes;
    if (_busy || servicio == null) return;
    try {
      final archivo = camara
          ? await servicio.tomarFoto()
          : await servicio.elegirImagen();
      if (!mounted || archivo == null) return;
      setState(() {
        _imagenPendiente = archivo;
        _error = null;
        _aviso = null;
      });
    } on ImagenProductoException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.mensaje);
    }
  }

  void _quitarImagen() {
    if (_busy) return;
    setState(() {
      _imagenPendiente = null;
      _imagenUrl = null;
      _imagenPublicId = null;
      _progresoImagen = null;
      _error = null;
    });
  }

  Widget _seccionImagen() {
    if (widget.imagenes == null) return const SizedBox.shrink();
    final hayImagen = _imagenPendiente != null || _imagenUrl != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const ProductoEtiqueta('Imagen del producto'),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProductoImagen(
              url: _imagenUrl,
              bytes: _imagenPendiente?.bytes,
              size: 104,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _seleccionarImagen(camara: false),
                        icon: const Icon(Icons.upload_file_outlined),
                        label: const Text('Subir imagen'),
                      ),
                      if (_permiteTomarFoto)
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _seleccionarImagen(camara: true),
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('Tomar foto'),
                        ),
                      if (hayImagen)
                        TextButton.icon(
                          onPressed: _busy ? null : _quitarImagen,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Quitar imagen'),
                        ),
                    ],
                  ),
                  Text(
                    'PNG o JPEG. Se optimiza al guardar.',
                    style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_progresoImagen != null) ...[
          const SizedBox(height: 10),
          Text(
            'Subiendo imagen: ${(_progresoImagen! * 100).round()}%',
            style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: _progresoImagen),
        ],
      ],
    );
  }

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
    if (!_descuentosValidos()) return;
    setState(() {
      _busy = true;
      _error = null;
      _aviso = null;
    });
    try {
      final imagenPendiente = _imagenPendiente;
      if (imagenPendiente != null) {
        final servicio = widget.imagenes;
        if (servicio == null) {
          throw const ImagenProductoException(
            'No está disponible el servicio de imágenes.',
          );
        }
        setState(() => _progresoImagen = 0);
        final subida = await servicio.subir(
          imagenPendiente,
          alProgresar: (fraccion) {
            if (mounted) setState(() => _progresoImagen = fraccion);
          },
        );
        if (!mounted) return;
        setState(() {
          _imagenUrl = subida.url;
          _imagenPublicId = subida.publicId;
          _imagenPendiente = null;
          _progresoImagen = null;
        });
      }
      final existente = _edicion ? widget.producto! : _productoGuardado;
      var guardado = existente != null
          ? await widget.gestion.editar(
              existente.id,
              widget.negocio.id,
              _datos(),
            )
          : await widget.gestion.crear(
              widget.negocio.id,
              _datos(conExistencias: true),
            );
      _productoGuardado = guardado;
      final descuentos = widget.descuentos;
      if (descuentos != null) {
        try {
          await descuentos.guardarDeProducto(
            widget.negocio.id,
            guardado.id,
            guardado.nombre,
            [for (final f in _filas) f.linea],
            _eliminados,
          );
          // El producto devuelto antes de guardar los descuentos ya no es vigente.
          guardado = await widget.gestion.consultar(
            guardado.id,
            widget.negocio.id,
          );
        } on DescuentoFailure catch (e) {
          if (e.sesionExpirada) {
            widget.onSesionExpirada();
            return;
          }
          if (!mounted) return;
          setState(() {
            _busy = false;
            _error =
                'El producto se guardó, pero no se pudieron guardar los descuentos. ${e.message} Vuelve a intentarlo.';
          });
          return;
        }
      }
      if (!mounted) return;
      if (!_edicion && _crearMas) {
        _prepararSiguiente(guardado);
        return;
      }
      setState(() => _busy = false);
      if (!_edicion) {
        _registrados++;
        widget.onRegistrados?.call(_registrados);
      }
      Navigator.of(context).pop<Producto>(guardado);
    } on ProductoFailure catch (e) {
      if (mounted) _fallo(e);
    } on ImagenProductoException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.mensaje;
        _progresoImagen = null;
      });
    }
  }

  /// Con "Crear más productos": el producto ya quedó guardado; deja el formulario
  /// completamente en blanco para el siguiente y vuelve al inicio de la pantalla.
  void _prepararSiguiente(Producto guardado) {
    _registrados++;
    _ultimo = guardado;
    final anteriores = [..._filas];
    setState(() {
      _busy = false;
      _error = null;
      _aviso =
          'Producto «${guardado.nombre}» registrado correctamente. Llevas $_registrados ${_registrados == 1 ? 'registrado' : 'registrados'}; completa el siguiente.';
      _nombre.clear();
      _precio.clear();
      _areaId = null;
      _categoriaId = null;
      _filas.clear();
      _eliminados.clear();
      _erroresFilas.clear();
      _errores.clear();
      _productoGuardado = null;
      _imagenPendiente = null;
      _imagenUrl = null;
      _imagenPublicId = null;
      _progresoImagen = null;
      _paso = 0;
      _seleccion
        ..clear()
        ..addAll(_sucursales.length == 1 ? [_sucursales.first.id] : const []);
      for (final c in _existencias.values) {
        c.clear();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final f in anteriores) {
        f.dispose();
      }
      final contexto = _arriba.currentContext;
      if (contexto != null) {
        Scrollable.ensureVisible(
          contexto,
          duration: const Duration(milliseconds: 250),
        );
      }
    });
  }

  /// Termina el registro por lotes: cierra devolviendo el último producto
  /// registrado. Sin productos registrados equivale a cancelar.
  void _terminar() {
    final ultimo = _ultimo;
    if (ultimo == null) {
      Navigator.pop(context);
      return;
    }
    widget.onRegistrados?.call(_registrados);
    Navigator.of(context).pop<Producto>(ultimo);
  }

  Widget _interruptorCrearMas() => Container(
    padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
    decoration: BoxDecoration(
      color: productoSuave,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Switch(
          key: const ValueKey('producto-crear-mas'),
          value: _crearMas,
          activeTrackColor: BarroTheme.primary,
          onChanged: _busy ? null : (v) => setState(() => _crearMas = v),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Crear más productos',
                style: BarroTheme.type(14, 21, weight: FontWeight.w700),
              ),
              Text(
                'Cada producto se guarda al registrarlo y el formulario queda en blanco para agregar otro sin salir.',
                style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  void _agregarDescuento() {
    if (_busy) return;
    setState(() => _filas.add(_FilaDescuento(LineaDescuento())));
  }

  /// En el registro solo descarta la fila; al editar, el descuento existente se
  /// elimina cuando se guardan los cambios.
  void _quitarDescuento(int indice) {
    if (_busy) return;
    setState(() {
      final fila = _filas.removeAt(indice);
      final id = fila.linea.id;
      if (id != null) _eliminados.add(id);
      _erroresFilas.clear();
      // Los campos aún están en pantalla durante este cuadro: se liberan después.
      WidgetsBinding.instance.addPostFrameCallback((_) => fila.dispose());
    });
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
    return [
      _texto(
        'nombre',
        'Nombre del producto *',
        _nombre,
        hint: 'Ej. Taza cerámica esmaltada',
      ),
      _seccionImagen(),
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
      if (widget.descuentos != null) ..._seccionDescuentos(),
      if (_edicion) ...[
        const SizedBox(height: 16),
        Text(
          'Las existencias se ajustan en Inventario.',
          style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
        ),
      ],
    ];
  }

  Widget _campoDescuento(
    String clave,
    int indice,
    String etiqueta,
    TextEditingController controller, {
    TextInputType? teclado,
    List<TextInputFormatter>? formatos,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(etiqueta, style: BarroTheme.type(13, 19, weight: FontWeight.w700)),
      const SizedBox(height: 6),
      TextField(
        key: ValueKey('producto-descuento-$clave-$indice'),
        controller: controller,
        enabled: !_busy,
        keyboardType: teclado,
        inputFormatters: formatos,
        style: BarroTheme.type(14, 21),
        decoration: productoDecoracion(
          error:
              _erroresFilas[indice]?[clave == 'minimo'
                  ? 'cantidadMinima'
                  : 'porcentaje'],
        ),
        onChanged: (_) {
          if (_erroresFilas.containsKey(indice) || _error != null) {
            setState(() => _erroresFilas.remove(indice));
          }
        },
      ),
    ],
  );

  Widget _filaDescuento(int indice) {
    final fila = _filas[indice];
    return Padding(
      key: ObjectKey(fila),
      padding: EdgeInsets.only(bottom: indice == _filas.length - 1 ? 0 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _campoDescuento(
                  'minimo',
                  indice,
                  'A partir de (piezas)',
                  fila.minimo,
                  teclado: TextInputType.number,
                  formatos: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _campoDescuento(
                  'porcentaje',
                  indice,
                  'Descuento (%)',
                  fila.porcentaje,
                  teclado: const TextInputType.numberWithOptions(decimal: true),
                  formatos: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 25),
                child: IconButton.filledTonal(
                  key: ValueKey('producto-descuento-quitar-$indice'),
                  tooltip: 'Quitar descuento',
                  style: IconButton.styleFrom(
                    backgroundColor: productoSuave,
                    foregroundColor: BarroTheme.primary,
                    minimumSize: const Size(48, 48),
                  ),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _busy ? null : () => _quitarDescuento(indice),
                ),
              ),
            ],
          ),
          if (_edicion)
            Row(
              children: [
                Switch(
                  key: ValueKey('producto-descuento-activo-$indice'),
                  value: fila.linea.activo,
                  activeTrackColor: BarroTheme.primary,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => fila.linea.activo = v),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    fila.linea.activo
                        ? 'Descuento activo'
                        : 'Descuento desactivado: no se aplica en los pedidos',
                    style: BarroTheme.type(
                      12,
                      18,
                      color: fila.linea.activo
                          ? BarroTheme.text
                          : BarroTheme.secondary,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _nota(String texto) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.info_outline,
            size: 18,
            color: BarroTheme.secondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: BarroTheme.type(13, 19, color: BarroTheme.secondary),
          ),
        ),
      ],
    ),
  );

  /// Descuentos por cantidad del producto: opcionales y pueden ser varios.
  List<Widget> _seccionDescuentos() => [
    const SizedBox(height: 24),
    Text(
      'Descuento por cantidad',
      style: BarroTheme.type(18, 26, weight: FontWeight.w700),
    ),
    const SizedBox(height: 4),
    Text(
      _edicion
          ? 'Puedes agregar uno o más descuentos opcionales.'
          : 'Agrega uno o más descuentos opcionales.',
      style: BarroTheme.type(14, 21, color: BarroTheme.secondary),
    ),
    const SizedBox(height: 12),
    if (_filas.isNotEmpty) ...[
      Container(
        key: const ValueKey('producto-descuentos'),
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: BarroTheme.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [for (var i = 0; i < _filas.length; i++) _filaDescuento(i)],
        ),
      ),
      const SizedBox(height: 12),
    ],
    DescuentoBotonContorno(
      key: const ValueKey('producto-descuento-agregar'),
      texto: '+ Agregar descuento',
      onPressed: _busy ? null : _agregarDescuento,
    ),
    _nota(
      _filas.isEmpty
          ? 'Es opcional: puedes omitirlo y asignarlo después desde Descuentos.'
          : _edicion
          ? 'Un descuento desactivado se conserva, pero no se aplica.'
          : 'Puedes agregar más descuentos si lo deseas.',
    ),
    if (_eliminados.isNotEmpty)
      _nota(
        'Los descuentos que quitaste se eliminarán al guardar los cambios.',
      ),
    if (_compartidos > 0)
      _nota(
        _compartidos == 1
            ? 'Este producto también recibe 1 descuento compartido. Se administra en Descuentos.'
            : 'Este producto también recibe $_compartidos descuentos compartidos. Se administran en Descuentos.',
      ),
  ];

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
    final puedeCrearMas = !_edicion && (enSucursales || _unaPantalla);
    return PopScope(
      // Con productos ya registrados, salir informa cuántos fueron.
      canPop: !_busy && _registrados == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy && _registrados > 0) _terminar();
      },
      child: ProductoScaffold(
        children: [
          SizedBox(key: _arriba, height: 14),
          ProductoEnlaceVolver(onPressed: _busy ? null : _terminar),
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
          if (_aviso != null) ...[
            ProductoAviso(_aviso!),
            const SizedBox(height: 16),
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
            if (puedeCrearMas) ...[
              _interruptorCrearMas(),
              const SizedBox(height: 16),
            ],
            ProductoBoton(
              key: const ValueKey('producto-guardar'),
              texto: _edicion
                  ? 'Guardar cambios'
                  : enSucursales || _unaPantalla
                  ? (_crearMas
                        ? 'Registrar y crear otro'
                        : 'Registrar producto')
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
                    : _terminar,
                child: Text(
                  enSucursales
                      ? 'Volver a los datos'
                      : _registrados > 0
                      ? 'Terminar ($_registrados ${_registrados == 1 ? 'registrado' : 'registrados'})'
                      : 'Cancelar',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
