import 'package:flutter/material.dart';
import '../../../../application/ports/inbound/gestion_negocios_use_case.dart';
import '../../../../application/ports/outbound/selector_logo.dart';
import '../../../../domain/negocio.dart';
import 'negocio_form_page.dart';
import 'widgets/confirmar_eliminar_negocio_dialog.dart';

typedef ResultadoNegocio = ({Negocio? negocio, bool eliminado});

class NegocioEditorPage extends StatefulWidget {
  const NegocioEditorPage({
    required this.gestion,
    required this.selectorLogo,
    required this.onSesionExpirada,
    this.negocio,
    super.key,
  });
  final GestionNegociosUseCase gestion;
  final SelectorLogo selectorLogo;
  final VoidCallback onSesionExpirada;
  final Negocio? negocio;

  @override
  State<NegocioEditorPage> createState() => _NegocioEditorPageState();
}

class _NegocioEditorPageState extends State<NegocioEditorPage> {
  late String _nombre;
  LogoNegocio? _logo;
  bool _eliminarLogo = false;
  bool _ocupado = false;
  String? _error;
  Map<String, String> _errores = {};
  bool get _edicion => widget.negocio != null;

  @override
  void initState() {
    super.initState();
    _nombre = widget.negocio?.nombre ?? '';
  }

  void _fallo(NegocioFailure e) {
    if (e.sesionExpirada) {
      widget.onSesionExpirada();
      return;
    }
    setState(() {
      _error = e.message;
      _errores = Map.of(e.fieldErrors);
    });
  }

  Future<void> _seleccionarLogo() async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    try {
      final logo = await widget.selectorLogo.seleccionar();
      if (!mounted || logo == null) return;
      setState(() {
        _logo = logo;
        _eliminarLogo = false;
        _errores.remove('logo');
        _error = null;
      });
    } on NegocioFailure catch (e) {
      if (mounted) _fallo(e);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _guardar() async {
    if (_ocupado) return;
    FocusScope.of(context).unfocus();
    final datos = DatosNegocio(
      nombre: _nombre,
      logo: _logo,
      eliminarLogo: _eliminarLogo,
    );
    final errores = datos.validar();
    setState(() {
      _errores = errores;
      _error = null;
    });
    if (errores.isNotEmpty) return;
    setState(() => _ocupado = true);
    try {
      final negocio = _edicion
          ? await widget.gestion.editar(widget.negocio!.id, datos)
          : await widget.gestion.crear(datos);
      if (!mounted) return;
      _terminar((negocio: negocio, eliminado: false));
    } on NegocioFailure catch (e) {
      if (mounted) _fallo(e);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _eliminar() async {
    if (_ocupado || !_edicion) return;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmarEliminarNegocioDialog(
        nombreNegocio: widget.negocio!.nombre,
        onConfirmar: () => Navigator.pop(context, true),
        onCancelar: () => Navigator.pop(context, false),
      ),
    );
    if (!mounted || confirmado != true) return;
    setState(() {
      _ocupado = true;
      _error = null;
      _errores = {};
    });
    try {
      await widget.gestion.eliminar(widget.negocio!.id);
      if (mounted) _terminar((negocio: null, eliminado: true));
    } on NegocioFailure catch (e) {
      if (mounted) _fallo(e);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  void _terminar(ResultadoNegocio resultado) {
    setState(() => _ocupado = false);
    Navigator.pop<ResultadoNegocio>(context, resultado);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_ocupado,
    child: NegocioFormPage(
      editando: _edicion,
      nombreInicial: widget.negocio?.nombre ?? '',
      mostrarEliminar: _edicion,
      logo: _eliminarLogo ? null : widget.negocio?.logo,
      contenidoLogo: _logo?.contenido,
      ocupado: _ocupado,
      error: _error,
      errorNombre: _errores['nombre'],
      errorLogo: _errores['logo'],
      onNombreChanged: (nombre) => setState(() {
        _nombre = nombre;
        _errores.remove('nombre');
        _error = null;
      }),
      onGuardar: _guardar,
      onCancelar: () => Navigator.pop(context),
      onEliminar: _eliminar,
      onSeleccionarLogo: _seleccionarLogo,
      onQuitarLogo: () => setState(() {
        _logo = null;
        _eliminarLogo = true;
        _errores.remove('logo');
        _error = null;
      }),
    ),
  );
}
