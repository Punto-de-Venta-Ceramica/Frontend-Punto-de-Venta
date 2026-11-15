import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_widgets.dart';
import '../../../application/gestion_pedidos.dart';
import '../../../domain/pedido.dart';
import 'package:punto_de_venta/features/notificaciones/application/contador_notificaciones.dart';

class NotificacionesPage extends StatefulWidget {
  const NotificacionesPage({
    required this.gestion,
    required this.contador,
    super.key,
  });
  final GestionPedidos gestion;
  final ContadorNotificaciones contador;
  @override
  State<NotificacionesPage> createState() => _NotificacionesPageState();
}

class _NotificacionesPageState extends State<NotificacionesPage> {
  late Future<List<AvisoPedido>> _avisos;
  @override
  void initState() {
    super.initState();
    _avisos = widget.gestion.notificaciones();
    widget.contador.addListener(_actualizarLista);
  }

  @override
  void didUpdateWidget(covariant NotificacionesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contador != widget.contador) {
      oldWidget.contador.removeListener(_actualizarLista);
      widget.contador.addListener(_actualizarLista);
    }
  }

  @override
  void dispose() {
    widget.contador.removeListener(_actualizarLista);
    super.dispose();
  }

  void _actualizarLista() {
    if (mounted) {
      setState(() {
        _avisos = widget.gestion.notificaciones();
      });
    }
  }

  Future<void> _marcar(AvisoPedido aviso) async {
    if (aviso.leida) return;
    try {
      await widget.gestion.marcarLeida(aviso.id);
      if (mounted) {
        _actualizarLista();
        await widget.contador.actualizar();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _refrescar() {
    _actualizarLista();
    widget.contador.actualizar();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BarroTheme.background,
    appBar: AppBar(
      backgroundColor: BarroTheme.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: Text(
        'Notificaciones',
        style: BarroTheme.type(20, 28, weight: FontWeight.w700),
      ),
      actions: [
        IconButton(
          tooltip: 'Actualizar notificaciones',
          onPressed: _refrescar,
          icon: const Icon(Icons.refresh_rounded, color: BarroTheme.primary),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: FutureBuilder<List<AvisoPedido>>(
            future: _avisos,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _Vacio(
                  icono: Icons.cloud_off_rounded,
                  titulo: 'No se pudieron cargar las notificaciones.',
                  accion: TextButton(
                    onPressed: _refrescar,
                    child: const Text('Reintentar'),
                  ),
                );
              }
              final avisos = snapshot.data ?? [];
              if (avisos.isEmpty) {
                return const _Vacio(
                  icono: Icons.notifications_off_outlined,
                  titulo: 'No tienes notificaciones.',
                  detalle: 'Aquí verás los pedidos nuevos y entregados.',
                );
              }
              final nuevas = avisos.where((a) => !a.leida).length;
              return RefreshIndicator(
                onRefresh: () async => _refrescar(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        nuevas == 0
                            ? 'Estás al día'
                            : nuevas == 1
                            ? '1 notificación nueva · toca para marcarla como leída'
                            : '$nuevas notificaciones nuevas · toca para marcarlas como leídas',
                        style: BarroTheme.type(
                          13,
                          20,
                          color: BarroTheme.secondary,
                        ),
                      ),
                    ),
                    for (final aviso in avisos)
                      _TarjetaAviso(aviso: aviso, onTap: () => _marcar(aviso)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

/// Aviso en tarjeta blanca; los no leídos se resaltan con el color de la marca.
class _TarjetaAviso extends StatelessWidget {
  const _TarjetaAviso({required this.aviso, required this.onTap});
  final AvisoPedido aviso;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nueva = !aviso.leida;
    final entregado = aviso.titulo.toLowerCase().contains('entregado');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: nueva ? Colors.white : Colors.white.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: nueva
                ? BarroTheme.primary.withValues(alpha: 0.35)
                : BarroTheme.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: nueva ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: nueva ? productoSuave : const Color(0xFFF3EEEB),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    entregado
                        ? Icons.local_shipping_outlined
                        : Icons.receipt_long_outlined,
                    size: 21,
                    color: nueva ? BarroTheme.primary : BarroTheme.placeholder,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              aviso.titulo,
                              style: BarroTheme.type(
                                15,
                                22,
                                weight: nueva
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: nueva
                                    ? BarroTheme.text
                                    : BarroTheme.secondary,
                              ),
                            ),
                          ),
                          if (nueva)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: BarroTheme.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Nueva',
                                style: BarroTheme.type(
                                  11,
                                  16,
                                  weight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        aviso.mensaje,
                        style: BarroTheme.type(
                          13,
                          20,
                          color: BarroTheme.secondary,
                        ),
                      ),
                      if (!nueva) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.done_all_rounded,
                              size: 14,
                              color: BarroTheme.placeholder,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Leída',
                              style: BarroTheme.type(
                                11,
                                16,
                                color: BarroTheme.placeholder,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Estado vacío o de error, centrado y con ícono.
class _Vacio extends StatelessWidget {
  const _Vacio({
    required this.icono,
    required this.titulo,
    this.detalle,
    this.accion,
  });
  final IconData icono;
  final String titulo;
  final String? detalle;
  final Widget? accion;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: productoSuave,
              shape: BoxShape.circle,
            ),
            child: Icon(icono, size: 34, color: BarroTheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: BarroTheme.type(16, 23, weight: FontWeight.w700),
          ),
          if (detalle != null) ...[
            const SizedBox(height: 6),
            Text(
              detalle!,
              textAlign: TextAlign.center,
              style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
            ),
          ],
          if (accion != null) ...[const SizedBox(height: 8), accion!],
        ],
      ),
    ),
  );
}
