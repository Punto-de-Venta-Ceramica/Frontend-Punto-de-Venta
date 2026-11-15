import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/core/infrastructure/widgets/barro_header.dart';
import 'package:punto_de_venta/features/sucursal/application/ports/inbound/gestion_sucursales_use_case.dart';
import 'package:punto_de_venta/features/sucursal/domain/sucursal.dart';

import '../../../../application/ports/inbound/gestion_reportes_use_case.dart';
import '../../../../domain/reporte_contable.dart';
import 'reporte_widgets.dart';

class DatosContablesPage extends StatefulWidget {
  const DatosContablesPage({
    required this.negocio,
    required this.sucursales,
    required this.reportes,
    required this.onSesionExpirada,
    this.sucursalInicialId,
    super.key,
  });

  final NegocioSucursal negocio;
  final GestionSucursalesUseCase sucursales;
  final GestionReportesUseCase reportes;
  final VoidCallback onSesionExpirada;
  final int? sucursalInicialId;

  @override
  State<DatosContablesPage> createState() => _DatosContablesPageState();
}

class _DatosContablesPageState extends State<DatosContablesPage> {
  List<Sucursal> _sucursales = const [];
  int? _sucursalId;
  PeriodoReporte _periodo = PeriodoReporte.semanal;
  DateTime _fecha = fechaCalendario(DateTime.now());
  ReporteContable? _reporte;
  String? _errorSucursales;
  String? _errorReporte;
  bool _cargandoSucursales = true;
  bool _cargandoReporte = false;
  bool _exportando = false;
  int _revisionConsulta = 0;

  ConsultaReporte? get _consulta {
    final sucursalId = _sucursalId;
    if (sucursalId == null) return null;
    return ConsultaReporte(
      sucursalId: sucursalId,
      periodo: _periodo,
      fecha: _fecha,
    );
  }

  @override
  void initState() {
    super.initState();
    _cargarSucursales();
  }

  Future<void> _cargarSucursales() async {
    setState(() {
      _cargandoSucursales = true;
      _errorSucursales = null;
    });
    try {
      final sucursales = await widget.sucursales.listar(widget.negocio.id);
      if (!mounted) return;
      final inicial = widget.sucursalInicialId;
      final seleccionarInicial = sucursales.any(
        (sucursal) => sucursal.id == inicial,
      );
      setState(() {
        _sucursales = sucursales;
        _cargandoSucursales = false;
      });
      if (seleccionarInicial) _elegirSucursal(inicial);
    } on SucursalFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _errorSucursales = error.message;
        _cargandoSucursales = false;
      });
      if (error.sesionExpirada) widget.onSesionExpirada();
    }
  }

  Future<void> _cargarReporte() async {
    final consulta = _consulta;
    if (consulta == null) return;
    final revision = ++_revisionConsulta;
    setState(() {
      _reporte = null;
      _errorReporte = null;
      _cargandoReporte = true;
    });
    try {
      final reporte = await widget.reportes.consultar(consulta);
      if (!mounted || revision != _revisionConsulta) return;
      setState(() {
        _reporte = reporte;
        _cargandoReporte = false;
      });
    } on ReporteFailure catch (error) {
      if (!mounted || revision != _revisionConsulta) return;
      setState(() {
        _errorReporte = error.mensaje;
        _cargandoReporte = false;
      });
      if (error.sesionExpirada) widget.onSesionExpirada();
    }
  }

  void _elegirSucursal(int? id) {
    if (id == null || id == _sucursalId) return;
    setState(() => _sucursalId = id);
    _cargarReporte();
  }

  void _elegirPeriodo(PeriodoReporte periodo) {
    if (periodo == _periodo) return;
    setState(() => _periodo = periodo);
    _cargarReporte();
  }

  void _moverFecha(int pasos) {
    final nuevaFecha = _periodo.mover(_fecha, pasos);
    final hoy = fechaCalendario(DateTime.now());
    setState(() => _fecha = nuevaFecha.isAfter(hoy) ? hoy : nuevaFecha);
    _cargarReporte();
  }

  Future<void> _exportar() async {
    final consulta = _consulta;
    if (consulta == null || _reporte == null || _exportando) return;
    setState(() => _exportando = true);
    try {
      final guardado = await widget.reportes.exportar(consulta);
      if (mounted && guardado) _avisar('Reporte exportado a Excel.');
    } on ReporteFailure catch (error) {
      if (!mounted) return;
      if (error.sesionExpirada) {
        widget.onSesionExpirada();
      } else {
        _avisar(error.mensaje);
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  void _avisar(String mensaje) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final reporte = _reporte;
    final rango = _periodo.rango(_fecha);
    final hoy = fechaCalendario(DateTime.now());
    final filtrosActivos = _sucursalId != null && !_exportando;
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              children: [
                const BarroHeader(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Volver'),
                  ),
                ),
                Text(
                  'Datos contables',
                  style: BarroTheme.type(30, 38, weight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Consulta los ingresos de tu sucursal.',
                  style: BarroTheme.type(14, 22, color: BarroTheme.secondary),
                ),
                const SizedBox(height: 20),
                PanelReporte(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.storefront_outlined,
                            color: BarroTheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.negocio.nombre,
                              style: BarroTheme.type(
                                15,
                                21,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _selectorSucursal(),
                      if (_sucursalId != null) ...[
                        const SizedBox(height: 14),
                        FiltroPeriodo(
                          seleccionado: _periodo,
                          desde: reporte?.desde ?? rango.desde,
                          hasta: reporte?.hasta ?? rango.hasta,
                          onPeriodo: filtrosActivos ? _elegirPeriodo : null,
                          onAnterior: filtrosActivos
                              ? () => _moverFecha(-1)
                              : null,
                          onSiguiente:
                              filtrosActivos &&
                                  _periodo
                                      .inicio(_fecha)
                                      .isBefore(_periodo.inicio(hoy))
                              ? () => _moverFecha(1)
                              : null,
                        ),
                      ],
                    ],
                  ),
                ),
                if (_sucursalId == null &&
                    !_cargandoSucursales &&
                    _sucursales.isNotEmpty) ...[
                  const SizedBox(height: 40),
                  const SeleccionSucursalPendiente(),
                ] else if (_cargandoReporte) ...[
                  const SizedBox(height: 24),
                  const Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Cargando reporte',
                    ),
                  ),
                ] else if (_errorReporte case final String error) ...[
                  const SizedBox(height: 16),
                  ErrorReporte(error: error, onReintentar: _cargarReporte),
                ] else if (reporte != null) ...[
                  const SizedBox(height: 16),
                  ResumenReporte(reporte: reporte),
                  if (_periodo.permiteExportar) ...[
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: _exportando ? null : _exportar,
                      icon: _exportando
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.file_download_outlined),
                      label: Text(
                        _exportando ? 'Preparando Excel…' : 'Exportar a Excel',
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectorSucursal() {
    if (_cargandoSucursales) {
      return const LinearProgressIndicator(
        semanticsLabel: 'Cargando sucursales',
      );
    }
    if (_errorSucursales case final String error) {
      return ErrorReporte(error: error, onReintentar: _cargarSucursales);
    }
    if (_sucursales.isEmpty) {
      return const Text(
        'Este negocio todavía no tiene sucursales registradas.',
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BarroTheme.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: _sucursalId,
            isExpanded: true,
            hint: const Text(
              'Selecciona una sucursal',
              overflow: TextOverflow.ellipsis,
            ),
            items: [
              for (final sucursal in _sucursales)
                DropdownMenuItem(
                  value: sucursal.id,
                  child: Text(sucursal.nombre, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _exportando ? null : _elegirSucursal,
          ),
        ),
      ),
    );
  }
}
