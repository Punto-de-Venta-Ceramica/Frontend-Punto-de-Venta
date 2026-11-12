import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import '../../../../application/ports/inbound/gestion_corte_caja_use_case.dart';
import '../../../../domain/corte_caja.dart';
import 'corte_caja_widgets.dart';
import 'corte_realizado_page.dart';

/// Historial de cortes de caja realizados en una sucursal.
class HistorialCortesPage extends StatefulWidget {
  const HistorialCortesPage({
    required this.gestion,
    required this.sucursalId,
    required this.sucursalNombre,
    required this.esPropietario,
    this.negocioNombre = '',
    this.onSesionExpirada,
    super.key,
  });

  final GestionCorteCajaUseCase gestion;
  final int sucursalId;
  final String sucursalNombre;
  final bool esPropietario;
  final String negocioNombre;
  final VoidCallback? onSesionExpirada;

  @override
  State<HistorialCortesPage> createState() => _HistorialCortesPageState();
}

class _HistorialCortesPageState extends State<HistorialCortesPage> {
  bool _cargando = true;
  String? _error;
  List<ResumenCorteCaja> _cortes = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final items = await widget.gestion.listarHistorial(widget.sucursalId);
      if (!mounted) return;
      setState(() {
        _cortes = items;
        _cargando = false;
      });
    } on CorteCajaFailure catch (e) {
      if (!mounted) return;
      if (e.sesionExpirada) {
        widget.onSesionExpirada?.call();
        return;
      }
      setState(() {
        _error = e.message;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el historial de cortes.';
        _cargando = false;
      });
    }
  }

  Future<void> _abrirCorte(int corteId) async {
    try {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: BarroTheme.primary),
        ),
      );

      final corteCompleto = await widget.gestion.consultarCorte(corteId);
      if (!mounted) return;
      Navigator.of(context).pop(); // Cierra el loading dialog

      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CorteRealizadoPage(
            corte: corteCompleto,
            esPropietario: widget.esPropietario,
            negocioNombre: widget.negocioNombre,
          ),
        ),
      );
    } on CorteCajaFailure catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      if (e.sesionExpirada) {
        widget.onSesionExpirada?.call();
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el detalle del corte.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BarroTheme.background,
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CorteCabecera(esPropietario: widget.esPropietario),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Historial de cortes',
                            style: BarroTheme.type(
                              28,
                              36,
                              weight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Sucursal ${widget.sucursalNombre}',
                            style: BarroTheme.type(
                              14,
                              20,
                              color: BarroTheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.refresh,
                        color: BarroTheme.primary,
                      ),
                      onPressed: _cargar,
                      tooltip: 'Actualizar',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _cargando
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: BarroTheme.primary,
                          ),
                        )
                      : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: BarroTheme.type(
                                  14,
                                  20,
                                  color: BarroTheme.error,
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: _cargar,
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        )
                      : _cortes.isEmpty
                      ? Center(
                          child: Text(
                            'No hay registros de cortes de caja en esta sucursal.',
                            textAlign: TextAlign.center,
                            style: BarroTheme.type(
                              14,
                              20,
                              color: BarroTheme.placeholder,
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          color: BarroTheme.primary,
                          onRefresh: _cargar,
                          child: ListView.separated(
                            itemCount: _cortes.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = _cortes[index];
                              final folio =
                                  'C-${item.id.toString().padLeft(6, '0')}';
                              final fecha =
                                  item.fechaHoraCierre ??
                                  item.fechaHoraApertura;

                              return Material(
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: const BorderSide(
                                    color: BarroTheme.border,
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _abrirCorte(item.id),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              folio,
                                              style: BarroTheme.type(
                                                16,
                                                22,
                                                weight: FontWeight.w700,
                                                color: BarroTheme.primary,
                                              ),
                                            ),
                                            Text(
                                              formatFechaHora(fecha),
                                              style: BarroTheme.type(
                                                12,
                                                16,
                                                color: BarroTheme.placeholder,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Responsable: ${item.usuarioNombre}',
                                          style: BarroTheme.type(
                                            13,
                                            18,
                                            color: BarroTheme.secondary,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Total estimado: ${formatDinero(item.totalEstimado)}',
                                              style: BarroTheme.type(
                                                13,
                                                18,
                                                weight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              'Real: ${formatDinero(item.totalReal ?? 0.0)}',
                                              style: BarroTheme.type(
                                                13,
                                                18,
                                                weight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (item.diferencia != null) ...[
                                          const SizedBox(height: 8),
                                          BadgeDiferencia(
                                            diferencia: item.diferencia!,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Volver'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
