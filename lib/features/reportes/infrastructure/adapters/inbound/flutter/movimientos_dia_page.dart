import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';

import '../../../../application/ports/inbound/gestion_reportes_use_case.dart';
import '../../../../domain/reporte_contable.dart';
import 'movimientos_dia_widgets.dart';
import 'reporte_widgets.dart';

class MovimientosDiaPage extends StatefulWidget {
  const MovimientosDiaPage({
    required this.sucursal,
    required this.consulta,
    required this.reporteInicial,
    required this.reportes,
    required this.onSesionExpirada,
    super.key,
  });

  final String sucursal;
  final ConsultaReporte consulta;
  final ReporteContable reporteInicial;
  final GestionReportesUseCase reportes;
  final VoidCallback onSesionExpirada;

  @override
  State<MovimientosDiaPage> createState() => _MovimientosDiaPageState();
}

class _MovimientosDiaPageState extends State<MovimientosDiaPage> {
  late ReporteContable _reporte = widget.reporteInicial;
  bool _actualizando = false;
  String? _error;

  Future<void> _actualizar() async {
    if (_actualizando) return;
    setState(() {
      _actualizando = true;
      _error = null;
    });
    try {
      final reporte = await widget.reportes.consultar(widget.consulta);
      if (!mounted) return;
      setState(() => _reporte = reporte);
    } on ReporteFailure catch (error) {
      if (!mounted) return;
      setState(() => _error = error.mensaje);
      if (error.sesionExpirada) widget.onSesionExpirada();
    } finally {
      if (mounted) setState(() => _actualizando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final movimientos = _reporte.movimientos;
    final fecha = fechaLargaReporte(widget.consulta.fecha);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: MediaQuery.textScalerOf(context).scale(kToolbarHeight),
        backgroundColor: BarroTheme.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Movimientos del día',
          maxLines: 2,
          style: BarroTheme.type(20, 27, weight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar movimientos',
            onPressed: _actualizando ? null : _actualizar,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: RefreshIndicator(
              onRefresh: _actualizar,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                itemCount: movimientos.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          widget.sucursal,
                          style: BarroTheme.type(
                            20,
                            27,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fecha,
                          style: BarroTheme.type(
                            14,
                            21,
                            color: BarroTheme.secondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${movimientos.length} ${movimientos.length == 1 ? 'movimiento' : 'movimientos'}',
                          style: BarroTheme.type(
                            13,
                            19,
                            color: BarroTheme.secondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_actualizando)
                          const LinearProgressIndicator(
                            semanticsLabel: 'Actualizando movimientos',
                          ),
                        if (_error case final String error)
                          ErrorReporte(error: error, onReintentar: _actualizar),
                        if (movimientos.isEmpty) const MovimientosDiaVacios(),
                      ],
                    );
                  }
                  final movimiento = movimientos[index - 1];
                  return MovimientoReporteCard(
                    key: ValueKey('${movimiento.tipo.name}-${movimiento.id}'),
                    movimiento: movimiento,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
