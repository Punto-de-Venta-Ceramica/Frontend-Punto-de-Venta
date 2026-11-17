import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_widgets.dart'
    show ProductoFiltroDesplegable;

import '../../../../domain/venta.dart';
import 'ventas_widgets.dart';

class FiltrosProductosVenta extends StatefulWidget {
  const FiltrosProductosVenta({
    required this.aplicados,
    required this.cargarCategorias,
    required this.onAplicar,
    required this.onSesionExpirada,
    super.key,
  });

  final FiltroProductosVenta aplicados;
  final Future<List<CategoriaFiltroVenta>> Function() cargarCategorias;
  final ValueChanged<FiltroProductosVenta> onAplicar;
  final VoidCallback onSesionExpirada;

  @override
  State<FiltrosProductosVenta> createState() => _FiltrosProductosVentaState();
}

class _FiltrosProductosVentaState extends State<FiltrosProductosVenta>
    with AutomaticKeepAliveClientMixin {
  static final _formatoPrecio = RegExp(r'^\d{0,12}([.,]\d{0,2})?$');
  final _panel = ExpansibleController();
  final _minimo = TextEditingController();
  final _maximo = TextEditingController();
  List<CategoriaFiltroVenta>? _categorias;
  int? _areaId;
  int? _categoriaId;
  String? _errorOpciones;
  String? _errorPrecio;
  bool _cargando = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _panel.dispose();
    _minimo.dispose();
    _maximo.dispose();
    super.dispose();
  }

  Future<void> _cargarCategorias() async {
    if (_cargando) return;
    setState(() {
      _cargando = true;
      _errorOpciones = null;
    });
    try {
      final categorias = await widget.cargarCategorias();
      if (!mounted) return;
      setState(() {
        _categorias = categorias;
        _cargando = false;
      });
    } on VentaFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _errorOpciones = error.mensaje;
        _cargando = false;
      });
      if (error.sesionExpirada) widget.onSesionExpirada();
    }
  }

  void _aplicar() {
    final minimo = num.tryParse(_minimo.text.replaceAll(',', '.'));
    final maximo = num.tryParse(_maximo.text.replaceAll(',', '.'));
    if ((_minimo.text.isNotEmpty && minimo == null) ||
        (_maximo.text.isNotEmpty && maximo == null)) {
      setState(() => _errorPrecio = 'Ingresa un precio válido.');
      return;
    }
    if (minimo != null && maximo != null && minimo > maximo) {
      setState(
        () => _errorPrecio = 'El precio mínimo no puede superar al máximo.',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    _panel.collapse();
    widget.onAplicar(
      FiltroProductosVenta(
        areaId: _areaId,
        categoriaId: _categoriaId,
        precioMinimo: minimo,
        precioMaximo: maximo,
      ),
    );
  }

  void _limpiar() {
    FocusScope.of(context).unfocus();
    _panel.collapse();
    _minimo.clear();
    _maximo.clear();
    setState(() {
      _areaId = null;
      _categoriaId = null;
      _errorPrecio = null;
    });
    widget.onAplicar(const FiltroProductosVenta());
  }

  Widget _precio(String etiqueta, TextEditingController controlador) =>
      TextField(
        controller: controlador,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          TextInputFormatter.withFunction(
            (anterior, nuevo) =>
                _formatoPrecio.hasMatch(nuevo.text) ? nuevo : anterior,
          ),
        ],
        decoration: decoracionCampoVenta(
          indicacion: etiqueta,
        ).copyWith(labelText: etiqueta),
        onChanged: (_) {
          if (_errorPrecio != null) setState(() => _errorPrecio = null);
        },
      );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final categorias = _categorias ?? const <CategoriaFiltroVenta>[];
    final areas = {
      for (final categoria in categorias) categoria.areaId: categoria.area,
    };
    final categoriasVisibles = [
      for (final categoria in categorias)
        if (_areaId == null || categoria.areaId == _areaId)
          (categoria.id, categoria.nombre),
    ];
    return ExpansionTile(
      controller: _panel,
      minTileHeight: 42,
      leading: const Icon(Icons.tune_rounded),
      title: Text(widget.aplicados.activo ? 'Filtros aplicados' : 'Filtros'),
      childrenPadding: const EdgeInsets.only(bottom: 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      onExpansionChanged: (abierto) {
        if (abierto && _categorias == null && _errorOpciones == null) {
          _cargarCategorias();
        }
      },
      children: [
        if (_cargando)
          const LinearProgressIndicator(
            semanticsLabel: 'Cargando áreas y categorías',
          )
        else if (_errorOpciones case final error?)
          AvisoVenta(error, onReintentar: _cargarCategorias),
        if (categorias.isNotEmpty) ...[
          ProductoFiltroDesplegable(
            texto: 'Todas las áreas',
            textoBuscador: 'Buscar área...',
            valor: _areaId,
            opciones: areas.entries
                .map((area) => (area.key, area.value))
                .toList(),
            icono: Icons.grid_view_outlined,
            onChanged: (id) => setState(() {
              _areaId = id;
              _categoriaId = null;
            }),
          ),
          const SizedBox(height: 10),
          ProductoFiltroDesplegable(
            texto: 'Todas las categorías',
            textoBuscador: 'Buscar categoría...',
            valor: _categoriaId,
            opciones: categoriasVisibles,
            icono: Icons.label_outline,
            conBuscador: true,
            onChanged: (id) => setState(() => _categoriaId = id),
          ),
        ],
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final minimo = _precio('Precio mín.', _minimo);
            final maximo = _precio('Precio máx.', _maximo);
            if (constraints.maxWidth <
                MediaQuery.textScalerOf(context).scale(238)) {
              return Column(
                children: [minimo, const SizedBox(height: 10), maximo],
              );
            }
            return Row(
              children: [
                Expanded(child: minimo),
                const SizedBox(width: 10),
                Expanded(child: maximo),
              ],
            );
          },
        ),
        if (_errorPrecio case final error?)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              error,
              style: BarroTheme.type(13, 19, color: BarroTheme.error),
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: _aplicar,
              child: const Text('Aplicar filtros'),
            ),
            TextButton(
              onPressed: _limpiar,
              child: const Text('Limpiar filtros'),
            ),
          ],
        ),
      ],
    );
  }
}
