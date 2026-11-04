import 'package:flutter/material.dart';
import '../../../../application/ports/inbound/gestion_catalogo_use_case.dart';
import '../../../../domain/catalogo.dart';
import 'area_detalle_page.dart';
import 'area_editor_page.dart';
import 'categoria_editor_page.dart';
import 'eliminar_clasificacion_dialog.dart';
import 'widgets/clasificacion_vista.dart';

class AreaDetalleControllerPage extends StatefulWidget {
  const AreaDetalleControllerPage({
    required this.negocio,
    required this.area,
    required this.gestion,
    required this.onSesionExpirada,
    this.mensaje,
    super.key,
  });
  final NegocioCatalogo negocio;
  final AreaCatalogo area;
  final GestionCatalogoUseCase gestion;
  final VoidCallback onSesionExpirada;
  final String? mensaje;
  @override
  State<AreaDetalleControllerPage> createState() =>
      _AreaDetalleControllerPageState();
}

class _AreaDetalleControllerPageState extends State<AreaDetalleControllerPage> {
  late AreaCatalogo _area;
  List<CategoriaCatalogo> _categorias = [];
  bool _cargando = true;
  bool _abriendo = false;
  String? _error;
  String? _mensaje;
  int _carga = 0;

  @override
  void initState() {
    super.initState();
    _area = widget.area;
    _cargar(mensaje: widget.mensaje);
  }

  Future<void> _cargar({String? mensaje}) async {
    final carga = ++_carga;
    setState(() {
      _cargando = true;
      _error = null;
      _mensaje = mensaje;
    });
    try {
      final area = await widget.gestion.consultarArea(
        widget.negocio.id,
        _area.id,
      );
      if (!mounted || carga != _carga) return;
      final categorias = await widget.gestion.listarCategorias(
        widget.negocio.id,
        area.id,
      );
      if (!mounted || carga != _carga) return;
      setState(() {
        _area = area;
        _categorias = categorias;
      });
    } on CatalogoFailure catch (e) {
      if (!mounted || carga != _carga) return;
      if (e.sesionExpirada) {
        widget.onSesionExpirada();
      } else {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted && carga == _carga) setState(() => _cargando = false);
    }
  }

  Future<void> _editarArea() async {
    if (_cargando || _abriendo || _error != null) return;
    setState(() => _abriendo = true);
    try {
      final resultado = await Navigator.push<ResultadoArea>(
        context,
        MaterialPageRoute(
          builder: (_) => AreaEditorPage(
            negocio: widget.negocio,
            area: _area,
            gestion: widget.gestion,
            onSesionExpirada: widget.onSesionExpirada,
          ),
        ),
      );
      if (!mounted || resultado == null) return;
      _area = resultado.area;
      await _cargar(mensaje: 'Área editada correctamente.');
    } finally {
      if (mounted) setState(() => _abriendo = false);
    }
  }

  Future<void> _categoria([CategoriaCatalogo? original]) async {
    if (_cargando || _abriendo || _error != null) return;
    setState(() => _abriendo = true);
    try {
      final categoria = await Navigator.push<CategoriaCatalogo>(
        context,
        MaterialPageRoute(
          builder: (_) => CategoriaEditorPage(
            negocio: widget.negocio,
            area: _area,
            gestion: widget.gestion,
            categoria: original,
            onSesionExpirada: widget.onSesionExpirada,
          ),
        ),
      );
      if (!mounted || categoria == null) return;
      await _cargar(
        mensaje: original == null
            ? 'Categoría registrada correctamente.'
            : 'Categoría editada correctamente.',
      );
    } finally {
      if (mounted) setState(() => _abriendo = false);
    }
  }

  Future<void> _eliminarArea() async {
    if (_cargando || _abriendo || _error != null) return;
    setState(() => _abriendo = true);
    try {
      final eliminada = await solicitarEliminacionClasificacion(
        context: context,
        tipo: TipoClasificacion.area,
        nombre: _area.nombre,
        negocio: widget.negocio.nombre,
        eliminar: () =>
            widget.gestion.eliminarArea(widget.negocio.id, _area.id),
        onSesionExpirada: widget.onSesionExpirada,
      );
      if (mounted && eliminada) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _abriendo = false);
    }
  }

  Future<void> _eliminarCategoria(int id) async {
    if (_cargando || _abriendo || _error != null) return;
    final categoria = _categorias.firstWhere((c) => c.id == id);
    setState(() => _abriendo = true);
    try {
      final eliminada = await solicitarEliminacionClasificacion(
        context: context,
        tipo: TipoClasificacion.categoria,
        nombre: categoria.nombre,
        negocio: widget.negocio.nombre,
        eliminar: () => widget.gestion.eliminarCategoria(
          widget.negocio.id,
          _area.id,
          categoria.id,
        ),
        onSesionExpirada: widget.onSesionExpirada,
      );
      if (!mounted || !eliminada) return;
      await _cargar(mensaje: 'Categoría eliminada correctamente.');
    } finally {
      if (mounted) setState(() => _abriendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disponible = !_cargando && !_abriendo && _error == null;
    return AreaDetallePage(
      negocio: widget.negocio.nombre,
      area: AreaVista(
        id: _area.id,
        nombre: _area.nombre,
        descripcion: _area.descripcion,
      ),
      categorias: [
        for (final c in _categorias)
          CategoriaVista(
            id: c.id,
            nombre: c.nombre,
            descripcion: c.descripcion,
          ),
      ],
      cargando: _cargando,
      error: _error,
      mensaje: _mensaje,
      onVolver: () => Navigator.pop(context),
      onReintentar: () => _cargar(),
      onActualizar: () =>
          _cargando || _abriendo ? Future<void>.value() : _cargar(),
      onEditarArea: disponible ? _editarArea : null,
      onEliminarArea: disponible ? _eliminarArea : null,
      onEliminarCategoria: disponible ? _eliminarCategoria : null,
      onRegistrarCategoria: disponible ? () => _categoria() : null,
      onEditarCategoria: disponible
          ? (id) => _categoria(_categorias.firstWhere((c) => c.id == id))
          : null,
    );
  }
}
