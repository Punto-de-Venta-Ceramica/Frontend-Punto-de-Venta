import 'package:flutter/material.dart';
import '../../../../application/ports/inbound/gestion_catalogo_use_case.dart';
import '../../../../domain/catalogo.dart';
import 'area_form_page.dart';
import 'categoria_editor_page.dart';
import 'eliminar_clasificacion_dialog.dart';
import 'widgets/clasificacion_vista.dart';

typedef ResultadoArea = ({AreaCatalogo area, bool creada, bool abrirDetalle});

class AreaEditorPage extends StatefulWidget {
  const AreaEditorPage({
    required this.negocio,
    required this.gestion,
    required this.onSesionExpirada,
    this.area,
    super.key,
  });
  final NegocioCatalogo negocio;
  final GestionCatalogoUseCase gestion;
  final VoidCallback onSesionExpirada;
  final AreaCatalogo? area;
  @override
  State<AreaEditorPage> createState() => _AreaEditorPageState();
}

class _AreaEditorPageState extends State<AreaEditorPage> {
  late final TextEditingController _nombre;
  late final TextEditingController _descripcion;
  AreaCatalogo? _registrada;
  List<CategoriaCatalogo> _categorias = [];
  bool _ocupado = false;
  String? _error;
  Map<String, String> _errores = {};
  bool get _editando => widget.area != null;

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(text: widget.area?.nombre ?? '');
    _descripcion = TextEditingController(text: widget.area?.descripcion ?? '');
  }

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  void _limpiarError(String campo) => setState(() {
    _errores.remove(campo);
    _error = null;
  });

  void _fallo(CatalogoFailure e) {
    if (e.sesionExpirada) {
      widget.onSesionExpirada();
      return;
    }
    setState(() {
      _error = e.message;
      _errores = Map.of(e.fieldErrors);
    });
  }

  Future<void> _continuar() async {
    if (_ocupado) return;
    if (_registrada != null) {
      Navigator.pop<ResultadoArea>(context, (
        area: _registrada!,
        creada: true,
        abrirDetalle: true,
      ));
      return;
    }
    FocusScope.of(context).unfocus();
    final datos = DatosClasificacion(
      nombre: _nombre.text,
      descripcion: _descripcion.text,
    );
    final errores = datos.validar();
    setState(() {
      _errores = errores;
      _error = null;
    });
    if (errores.isNotEmpty) return;
    setState(() => _ocupado = true);
    try {
      final area = _editando
          ? await widget.gestion.editarArea(
              widget.negocio.id,
              widget.area!.id,
              datos,
            )
          : await widget.gestion.crearArea(widget.negocio.id, datos);
      if (!mounted) return;
      setState(() => _ocupado = false);
      if (_editando) {
        Navigator.pop<ResultadoArea>(context, (
          area: area,
          creada: false,
          abrirDetalle: false,
        ));
      } else {
        setState(() => _registrada = area);
      }
    } on CatalogoFailure catch (e) {
      if (mounted) _fallo(e);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _categoria([CategoriaCatalogo? original]) async {
    if (_ocupado || _registrada == null) return;
    setState(() => _ocupado = true);
    try {
      final categoria = await Navigator.push<CategoriaCatalogo>(
        context,
        MaterialPageRoute(
          builder: (_) => CategoriaEditorPage(
            negocio: widget.negocio,
            area: _registrada!,
            gestion: widget.gestion,
            categoria: original,
            onSesionExpirada: widget.onSesionExpirada,
          ),
        ),
      );
      if (!mounted || categoria == null) return;
      setState(() {
        _categorias =
            [..._categorias.where((c) => c.id != categoria.id), categoria]
              ..sort(
                (a, b) =>
                    a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
              );
      });
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  void _cancelar() {
    if (_ocupado) return;
    final area = _registrada;
    Navigator.pop<ResultadoArea>(
      context,
      area == null ? null : (area: area, creada: true, abrirDetalle: false),
    );
  }

  Future<void> _eliminarCategoria(int id) async {
    if (_ocupado || _registrada == null) return;
    final categoria = _categorias.firstWhere((c) => c.id == id);
    setState(() => _ocupado = true);
    try {
      final eliminada = await solicitarEliminacionClasificacion(
        context: context,
        tipo: TipoClasificacion.categoria,
        nombre: categoria.nombre,
        negocio: widget.negocio.nombre,
        eliminar: () => widget.gestion.eliminarCategoria(
          widget.negocio.id,
          _registrada!.id,
          categoria.id,
        ),
        onSesionExpirada: widget.onSesionExpirada,
      );
      if (!mounted || !eliminada) return;
      setState(() => _categorias.removeWhere((c) => c.id == categoria.id));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_ocupado,
    child: AreaFormPage(
      negocio: widget.negocio.nombre,
      editando: _editando,
      paso: _registrada == null ? PasoArea.datos : PasoArea.categorias,
      pasosDisponibles: _editando
          ? const [PasoArea.datos]
          : const [PasoArea.datos, PasoArea.categorias],
      nombreController: _nombre,
      descripcionController: _descripcion,
      onNombreChanged: (_) => _limpiarError('nombre'),
      onDescripcionChanged: (_) => _limpiarError('descripcion'),
      errorNombre: _errores['nombre'],
      errorDescripcion: _errores['descripcion'],
      error: _error,
      ocupado: _ocupado,
      mensaje: _registrada == null
          ? null
          : 'El área ya está registrada. Puedes agregar categorías ahora o más adelante.',
      categorias: [
        for (final c in _categorias)
          CategoriaVista(
            id: c.id,
            nombre: c.nombre,
            descripcion: c.descripcion,
          ),
      ],
      onRegistrarCategoria: () => _categoria(),
      onEditarCategoria: (id) =>
          _categoria(_categorias.firstWhere((c) => c.id == id)),
      onEliminarCategoria: _eliminarCategoria,
      accion: _editando
          ? 'Guardar cambios'
          : _registrada == null
          ? 'Continuar'
          : 'Finalizar',
      textoCancelar: _registrada == null ? 'Cancelar' : 'Volver a áreas',
      onContinuar: _continuar,
      onCancelar: _cancelar,
    ),
  );
}
