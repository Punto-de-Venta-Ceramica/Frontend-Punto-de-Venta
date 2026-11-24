import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/core/infrastructure/services/notificacion_servicio.dart';
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

  /// Corte cuyo detalle se está consultando; null si ninguno.
  int? _abriendoId;

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

  /// Abre el detalle sin cubrir la pantalla: la tarjeta tocada muestra su propio
  /// indicador y mientras tanto no se aceptan otros toques.
  Future<void> _abrirCorte(int corteId) async {
    if (_abriendoId != null) return;
    setState(() => _abriendoId = corteId);
    try {
      final corteCompleto = await widget.gestion.consultarCorte(corteId);
      if (!mounted) return;
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
      if (e.sesionExpirada) {
        widget.onSesionExpirada?.call();
        return;
      }
      NotificacionServicio.error(context, e.message);
    } catch (_) {
      if (!mounted) return;
      NotificacionServicio.error(
        context,
        'No se pudo abrir el detalle del corte.',
      );
    } finally {
      if (mounted) setState(() => _abriendoId = null);
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
                            textoSucursal(widget.sucursalNombre),
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
                              return _TarjetaCorte(
                                corte: item,
                                abriendo: _abriendoId == item.id,
                                onTap: () => _abrirCorte(item.id),
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

/// Tarjeta de un corte cerrado. El color del ícono sigue el resultado del
/// corte (sin diferencia, sobrante o faltante); mientras se abre muestra un
/// indicador pequeño en lugar de la flecha, sin cubrir la pantalla.
class _TarjetaCorte extends StatelessWidget {
  const _TarjetaCorte({
    required this.corte,
    required this.abriendo,
    required this.onTap,
  });
  final ResumenCorteCaja corte;
  final bool abriendo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final folio = 'C-${corte.id.toString().padLeft(6, '0')}';
    final fecha = corte.fechaHoraCierre ?? corte.fechaHoraApertura;
    final diferencia = corte.diferencia;
    final (color, fondo) = switch (diferencia) {
      null => (BarroTheme.primary, Color(0xFFF7E7DF)),
      final d when d.abs() < 0.009 => (corteVerde, const Color(0xFFEAF5EE)),
      final d when d > 0 => (const Color(0xFF1B65A4), const Color(0xFFEAF2FB)),
      _ => (BarroTheme.error, const Color(0xFFFDECE8)),
    };
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: BarroTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: fondo,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      Icons.point_of_sale_rounded,
                      size: 24,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          folio,
                          style: BarroTheme.type(
                            17,
                            23,
                            weight: FontWeight.w700,
                            color: BarroTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        _DatoConIcono(
                          icono: Icons.calendar_today_outlined,
                          texto: formatFechaHora(fecha),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: abriendo
                        ? const Padding(
                            padding: EdgeInsets.all(3),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: BarroTheme.primary,
                            ),
                          )
                        : const Icon(
                            Icons.chevron_right_rounded,
                            color: BarroTheme.placeholder,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _DatoConIcono(
                icono: Icons.person_outline_rounded,
                texto: 'Responsable: ${corte.usuarioNombre}',
                tamano: 13,
                color: BarroTheme.secondary,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF4F1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _Monto(
                        icono: Icons.calculate_outlined,
                        etiqueta: 'Total estimado',
                        monto: formatDinero(corte.totalEstimado),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 34,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      color: BarroTheme.border,
                    ),
                    Expanded(
                      child: _Monto(
                        icono: Icons.payments_outlined,
                        etiqueta: 'Real',
                        monto: formatDinero(corte.totalReal ?? 0.0),
                        destacado: true,
                      ),
                    ),
                  ],
                ),
              ),
              if (diferencia != null) ...[
                const SizedBox(height: 12),
                BadgeDiferencia(diferencia: diferencia),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DatoConIcono extends StatelessWidget {
  const _DatoConIcono({
    required this.icono,
    required this.texto,
    this.tamano = 12,
    this.color = BarroTheme.placeholder,
  });
  final IconData icono;
  final String texto;
  final double tamano;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icono, size: tamano + 3, color: color),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          texto,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: BarroTheme.type(tamano, tamano + 5, color: color),
        ),
      ),
    ],
  );
}

class _Monto extends StatelessWidget {
  const _Monto({
    required this.icono,
    required this.etiqueta,
    required this.monto,
    this.destacado = false,
  });
  final IconData icono;
  final String etiqueta;
  final String monto;
  final bool destacado;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icono, size: 15, color: BarroTheme.placeholder),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BarroTheme.type(12, 16, color: BarroTheme.secondary),
            ),
          ),
        ],
      ),
      const SizedBox(height: 2),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          monto,
          style: BarroTheme.type(
            16,
            22,
            weight: destacado ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}
