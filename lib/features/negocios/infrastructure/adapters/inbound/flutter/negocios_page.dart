import 'package:flutter/material.dart';
import '../../../../application/ports/inbound/gestion_negocios_use_case.dart';
import '../../../../application/ports/outbound/selector_logo.dart';
import '../../../../domain/negocio.dart';
import 'mis_negocios_page.dart';
import 'negocio_editor_page.dart';

class NegociosPage extends StatefulWidget {
  const NegociosPage({
    required this.gestion,
    required this.selectorLogo,
    required this.onSesionExpirada,
    required this.onAdministrar,
    required this.onNegocioCreado,
    super.key,
  });
  final GestionNegociosUseCase gestion;
  final SelectorLogo selectorLogo;
  final VoidCallback onSesionExpirada;
  final Future<void> Function(Negocio) onAdministrar;
  final Future<void> Function(Negocio) onNegocioCreado;
  @override
  State<NegociosPage> createState() => _NegociosPageState();
}

class _NegociosPageState extends State<NegociosPage> {
  List<Negocio> _negocios = [];
  bool _ocupado = true;
  String? _error;
  String? _mensaje;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _fallo(NegocioFailure e) {
    if (e.sesionExpirada) {
      widget.onSesionExpirada();
      return;
    }
    setState(() => _error = e.message);
  }

  Future<void> _cargar() async {
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final negocios = await widget.gestion.listar();
      if (mounted) setState(() => _negocios = negocios);
    } on NegocioFailure catch (e) {
      if (mounted) _fallo(e);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _formulario([Negocio? original]) async {
    if (_ocupado) return;
    setState(() {
      _ocupado = true;
      _error = null;
      _mensaje = null;
    });
    try {
      final detalle = original == null
          ? null
          : await widget.gestion.consultar(original.id);
      if (!mounted) return;
      final resultado = await Navigator.push<ResultadoNegocio>(
        context,
        MaterialPageRoute(
          builder: (_) => NegocioEditorPage(
            gestion: widget.gestion,
            selectorLogo: widget.selectorLogo,
            negocio: detalle,
            onSesionExpirada: widget.onSesionExpirada,
          ),
        ),
      );
      if (!mounted || resultado == null) return;
      setState(() {
        if (resultado.eliminado) {
          _negocios = _negocios.where((n) => n.id != original!.id).toList();
          _mensaje = 'Negocio eliminado correctamente.';
        } else {
          final guardado = resultado.negocio!;
          _negocios = [..._negocios.where((n) => n.id != guardado.id), guardado]
            ..sort((a, b) {
              final nombre = a.nombre.toLowerCase().compareTo(
                b.nombre.toLowerCase(),
              );
              return nombre == 0 ? a.id.compareTo(b.id) : nombre;
            });
          _mensaje = original == null
              ? 'Negocio registrado correctamente.'
              : 'Cambios guardados correctamente.';
        }
      });
      if (original == null && !resultado.eliminado) {
        await widget.onNegocioCreado(resultado.negocio!);
      }
    } on NegocioFailure catch (e) {
      if (mounted) _fallo(e);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _administrar(Negocio negocio) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    try {
      await widget.onAdministrar(negocio);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => MisNegociosPage(
    negocios: _negocios,
    cargando: _ocupado,
    error: _error,
    mensajeExito: _mensaje,
    onRegistrar: _ocupado ? null : () => _formulario(),
    onEditar: _ocupado ? null : _formulario,
    onAdministrar: _ocupado ? null : _administrar,
    onReintentar: _ocupado ? null : _cargar,
    onVolver: () => Navigator.pop(context),
  );
}
