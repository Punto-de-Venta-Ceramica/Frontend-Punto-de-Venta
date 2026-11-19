import 'package:flutter/material.dart';
import '../../../../domain/catalogo.dart';
import 'widgets/clasificacion_vista.dart';
import 'widgets/confirmar_eliminar_clasificacion_dialog.dart';

Future<bool> solicitarEliminacionClasificacion({
  required BuildContext context,
  required TipoClasificacion tipo,
  required String nombre,
  required String negocio,
  required Future<void> Function() eliminar,
  required VoidCallback onSesionExpirada,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EliminarClasificacionDialog(
        tipo: tipo,
        nombre: nombre,
        negocio: negocio,
        eliminar: eliminar,
        onSesionExpirada: onSesionExpirada,
      ),
    ) ??
    false;

class _EliminarClasificacionDialog extends StatefulWidget {
  const _EliminarClasificacionDialog({
    required this.tipo,
    required this.nombre,
    required this.negocio,
    required this.eliminar,
    required this.onSesionExpirada,
  });
  final TipoClasificacion tipo;
  final String nombre;
  final String negocio;
  final Future<void> Function() eliminar;
  final VoidCallback onSesionExpirada;

  @override
  State<_EliminarClasificacionDialog> createState() =>
      _EliminarClasificacionDialogState();
}

class _EliminarClasificacionDialogState
    extends State<_EliminarClasificacionDialog> {
  bool _ocupado = false;
  String? _error;

  Future<void> _eliminar() async {
    if (_ocupado) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await widget.eliminar();
      if (!mounted) return;
      setState(() => _ocupado = false);
      Navigator.pop(context, true);
    } on CatalogoFailure catch (e) {
      if (!mounted) return;
      if (e.sesionExpirada) {
        setState(() => _ocupado = false);
        Navigator.pop(context, false);
        widget.onSesionExpirada();
      } else {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_ocupado,
    child: ConfirmarEliminarClasificacionDialog(
      tipo: widget.tipo,
      nombre: widget.nombre,
      negocio: widget.negocio,
      ocupado: _ocupado,
      error: _error,
      onConfirmar: _eliminar,
      onCancelar: () => Navigator.pop(context, false),
    ),
  );
}
