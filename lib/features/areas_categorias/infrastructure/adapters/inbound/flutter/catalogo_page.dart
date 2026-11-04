import 'package:flutter/material.dart';
import '../../../../application/ports/inbound/gestion_catalogo_use_case.dart';
import '../../../../domain/catalogo.dart';
import 'area_detalle_controller_page.dart';
import 'area_editor_page.dart';
import 'areas_page.dart';
import 'widgets/clasificacion_vista.dart';

class CatalogoPage extends StatefulWidget {
  const CatalogoPage({
    required this.negocio,
    required this.gestion,
    required this.onSesionExpirada,
    super.key,
  });
  final NegocioCatalogo negocio;
  final GestionCatalogoUseCase gestion;
  final VoidCallback onSesionExpirada;
  @override
  State<CatalogoPage> createState() => _CatalogoPageState();
}

class _CatalogoPageState extends State<CatalogoPage> {
  final _busqueda = TextEditingController();
  List<ResumenAreaCatalogo> _areas = [];
  bool _cargando = true;
  bool _navegando = false;
  bool _sesionFinalizada = false;
  String _filtro = '';
  String? _error;
  String? _mensaje;
  int _carga = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  void _expirarSesion() {
    if (_sesionFinalizada) return;
    _sesionFinalizada = true;
    widget.onSesionExpirada();
  }

  Future<void> _cargar({String? mensaje}) async {
    if (_sesionFinalizada) return;
    final carga = ++_carga;
    setState(() {
      _cargando = true;
      _error = null;
      _mensaje = mensaje;
    });
    try {
      final areas = await widget.gestion.listarAreas(widget.negocio.id);
      if (!mounted || carga != _carga) return;
      setState(() => _areas = areas);
    } on CatalogoFailure catch (e) {
      if (!mounted || carga != _carga) return;
      if (e.sesionExpirada) {
        _expirarSesion();
      } else {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted && carga == _carga) setState(() => _cargando = false);
    }
  }

  Future<bool?> _detalle(AreaCatalogo area, {String? mensaje}) =>
      Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => AreaDetalleControllerPage(
            negocio: widget.negocio,
            area: area,
            gestion: widget.gestion,
            onSesionExpirada: _expirarSesion,
            mensaje: mensaje,
          ),
        ),
      );

  Future<void> _registrar() async {
    if (_cargando || _navegando || _error != null) return;
    setState(() => _navegando = true);
    try {
      final resultado = await Navigator.push<ResultadoArea>(
        context,
        MaterialPageRoute(
          builder: (_) => AreaEditorPage(
            negocio: widget.negocio,
            gestion: widget.gestion,
            onSesionExpirada: _expirarSesion,
          ),
        ),
      );
      if (!mounted) return;
      var mensaje = resultado == null ? null : 'Área registrada correctamente.';
      if (resultado != null && resultado.abrirDetalle) {
        final eliminada = await _detalle(resultado.area, mensaje: mensaje);
        if (eliminada == true) mensaje = 'Área eliminada correctamente.';
      }
      if (mounted) await _cargar(mensaje: mensaje);
    } finally {
      if (mounted) setState(() => _navegando = false);
    }
  }

  Future<void> _abrirArea(int id) async {
    if (_cargando || _navegando || _error != null) return;
    setState(() => _navegando = true);
    try {
      final area = _areas.firstWhere((r) => r.area.id == id).area;
      final eliminada = await _detalle(area);
      if (mounted) {
        await _cargar(
          mensaje: eliminada == true ? 'Área eliminada correctamente.' : null,
        );
      }
    } finally {
      if (mounted) setState(() => _navegando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtro = _filtro.trim().toLowerCase();
    final filtradas = _areas.where(
      (r) =>
          r.area.nombre.toLowerCase().contains(filtro) ||
          r.area.descripcion.toLowerCase().contains(filtro),
    );
    final disponible = !_cargando && !_navegando && _error == null;
    return AreasPage(
      negocio: widget.negocio.nombre,
      areas: [
        for (final r in filtradas)
          AreaVista(
            id: r.area.id,
            nombre: r.area.nombre,
            descripcion: r.area.descripcion,
            categorias: r.numeroCategorias,
          ),
      ],
      mensaje: _mensaje,
      cargando: _cargando,
      error: _error,
      filtrando: filtro.isNotEmpty,
      busquedaController: _busqueda,
      onBuscar: (texto) => setState(() => _filtro = texto),
      onRegistrar: disponible ? _registrar : null,
      onVerArea: disponible ? _abrirArea : null,
      onVolver: () => Navigator.pop(context),
      onReintentar: () => _cargar(),
      onActualizar: () =>
          _cargando || _navegando ? Future<void>.value() : _cargar(),
    );
  }
}
