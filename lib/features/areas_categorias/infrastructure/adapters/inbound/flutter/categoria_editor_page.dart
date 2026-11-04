import 'package:flutter/material.dart';
import '../../../../application/ports/inbound/gestion_catalogo_use_case.dart';
import '../../../../domain/catalogo.dart';
import 'categoria_form_page.dart';

class CategoriaEditorPage extends StatefulWidget {
  const CategoriaEditorPage({
    required this.negocio,
    required this.area,
    required this.gestion,
    required this.onSesionExpirada,
    this.categoria,
    super.key,
  });
  final NegocioCatalogo negocio;
  final AreaCatalogo area;
  final GestionCatalogoUseCase gestion;
  final VoidCallback onSesionExpirada;
  final CategoriaCatalogo? categoria;
  @override
  State<CategoriaEditorPage> createState() => _CategoriaEditorPageState();
}

class _CategoriaEditorPageState extends State<CategoriaEditorPage> {
  late final TextEditingController _nombre;
  late final TextEditingController _descripcion;
  bool _ocupado = false;
  String? _error;
  Map<String, String> _errores = {};

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(text: widget.categoria?.nombre ?? '');
    _descripcion = TextEditingController(
      text: widget.categoria?.descripcion ?? '',
    );
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

  Future<void> _guardar() async {
    if (_ocupado) return;
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
      final categoria = widget.categoria == null
          ? await widget.gestion.crearCategoria(
              widget.negocio.id,
              widget.area.id,
              datos,
            )
          : await widget.gestion.editarCategoria(
              widget.negocio.id,
              widget.area.id,
              widget.categoria!.id,
              datos,
            );
      if (!mounted) return;
      setState(() => _ocupado = false);
      Navigator.pop<CategoriaCatalogo>(context, categoria);
    } on CatalogoFailure catch (e) {
      if (!mounted) return;
      if (e.sesionExpirada) {
        widget.onSesionExpirada();
      } else {
        setState(() {
          _error = e.message;
          _errores = Map.of(e.fieldErrors);
        });
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_ocupado,
    child: CategoriaFormPage(
      negocio: widget.negocio.nombre,
      areaNombre: widget.area.nombre,
      editando: widget.categoria != null,
      nombreController: _nombre,
      descripcionController: _descripcion,
      error: _error,
      errorNombre: _errores['nombre'],
      errorDescripcion: _errores['descripcion'],
      ocupado: _ocupado,
      onNombreChanged: (_) => _limpiarError('nombre'),
      onDescripcionChanged: (_) => _limpiarError('descripcion'),
      onGuardar: _guardar,
      onCancelar: () => Navigator.pop(context),
    ),
  );
}
