import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_widgets.dart';
import '../../../application/gestion_pedidos.dart';
import '../../../domain/pedido.dart';
import 'package:punto_de_venta/features/notificaciones/application/contador_notificaciones.dart';
import 'package:punto_de_venta/core/infrastructure/services/notificacion_servicio.dart';
import 'package:punto_de_venta/features/productos/domain/producto.dart';
import 'pedido_detalle_page.dart';

class NotificacionesPage extends StatefulWidget {
  const NotificacionesPage({
    required this.gestion,
    required this.contador,
    required this.esPropietario,
    super.key,
  });
  final GestionPedidos gestion;
  final ContadorNotificaciones contador;

  /// Rol de quien ve los avisos: define qué puede hacer en el detalle del pedido.
  final bool esPropietario;
  @override
  State<NotificacionesPage> createState() => _NotificacionesPageState();
}

enum _Filtro {
  noLeidas('No leídas'),
  leidas('Leídas'),
  todas('Todas');

  const _Filtro(this.texto);
  final String texto;

  bool acepta(AvisoPedido aviso) => switch (this) {
    noLeidas => !aviso.leida,
    leidas => aviso.leida,
    todas => true,
  };
}

class _NotificacionesPageState extends State<NotificacionesPage> {
  /// Avisos cargados, del más reciente al más antiguo. El servidor los entrega
  /// de 20 en 20; el filtro leídas / no leídas se aplica aquí, sobre ellos.
  List<AvisoPedido> _avisos = [];
  int _pagina = 0;
  bool _ultima = true;
  bool _cargando = true;
  bool _cargandoMas = false;
  bool _error = false;
  _Filtro _filtro = _Filtro.noLeidas;

  /// Descarta respuestas de una carga anterior.
  int _carga = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
    widget.contador.addListener(_cargar);
  }

  @override
  void didUpdateWidget(covariant NotificacionesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contador != widget.contador) {
      oldWidget.contador.removeListener(_cargar);
      widget.contador.addListener(_cargar);
    }
  }

  @override
  void dispose() {
    widget.contador.removeListener(_cargar);
    super.dispose();
  }

  /// Trae la primera página y la pone al inicio; lo ya cargado más abajo se
  /// conserva, así un aviso nuevo no devuelve la lista a los primeros 20.
  Future<void> _cargar() async {
    final carga = ++_carga;
    if (mounted) {
      setState(() {
        _cargando = true;
        _error = false;
      });
    }
    try {
      final pagina = await widget.gestion.notificaciones();
      if (!mounted || carga != _carga) return;
      setState(() {
        final nuevos = {for (final a in pagina.avisos) a.id};
        final primeraCarga = _avisos.isEmpty;
        _avisos = [
          ...pagina.avisos,
          ..._avisos.where((a) => !nuevos.contains(a.id)),
        ];
        if (primeraCarga) {
          _pagina = pagina.pagina;
          _ultima = pagina.ultima;
        }
      });
    } catch (_) {
      if (mounted && carga == _carga) setState(() => _error = true);
    } finally {
      if (mounted && carga == _carga) setState(() => _cargando = false);
    }
  }

  /// Agrega la siguiente página de 20 al final.
  Future<void> _cargarMas() async {
    if (_cargando || _cargandoMas || _ultima) return;
    final carga = _carga;
    setState(() => _cargandoMas = true);
    try {
      final pagina = await widget.gestion.notificaciones(pagina: _pagina + 1);
      if (!mounted || carga != _carga) return;
      setState(() {
        // Si llegaron avisos nuevos las páginas se corren y pueden repetirse.
        final vistos = {for (final a in _avisos) a.id};
        _avisos = [
          ..._avisos,
          ...pagina.avisos.where((a) => !vistos.contains(a.id)),
        ];
        _pagina = pagina.pagina;
        _ultima = pagina.ultima;
      });
    } catch (_) {
      if (mounted) {
        NotificacionServicio.error(
          context,
          'No se pudieron cargar más notificaciones.',
        );
      }
    } finally {
      if (mounted) setState(() => _cargandoMas = false);
    }
  }

  Future<void> _marcar(AvisoPedido aviso) async {
    if (aviso.leida) return;
    try {
      await widget.gestion.marcarLeida(aviso.id);
      if (mounted) {
        setState(() {
          _avisos = [
            for (final a in _avisos)
              a.id == aviso.id
                  ? AvisoPedido(
                      id: a.id,
                      titulo: a.titulo,
                      mensaje: a.mensaje,
                      leida: true,
                      pedidoId: a.pedidoId,
                      fecha: a.fecha,
                    )
                  : a,
          ];
        });
        await widget.contador.actualizar();
      }
    } on ApiException catch (e) {
      if (mounted) {
        NotificacionServicio.error(context, e.message);
      }
    }
  }

  /// Marca el aviso como leído y abre el detalle de su pedido.
  Future<void> _abrir(AvisoPedido aviso) async {
    await _marcar(aviso);
    final pedidoId = aviso.pedidoId;
    if (pedidoId == null || !mounted) return;
    try {
      final pedido = await widget.gestion.obtener(pedidoId);
      final sucursalId = pedido.sucursalId;
      final negocioId = pedido.negocioId;
      if (sucursalId == null || negocioId == null) {
        throw const ApiException('No se pudo abrir el pedido.');
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PedidoDetallePage(
            gestion: widget.gestion,
            pedidoId: pedidoId,
            sucursalId: sucursalId,
            esPropietario: widget.esPropietario,
            negocio: NegocioProducto(
              id: negocioId,
              nombre: pedido.negocio ?? '',
            ),
            sucursalNombre: pedido.sucursal,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) NotificacionServicio.error(context, e.message);
    }
  }

  void _refrescar() {
    _cargar();
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
          child: _cuerpo(),
        ),
      ),
    ),
  );

  Widget _cuerpo() {
    if (_avisos.isEmpty) {
      if (_cargando) return const Center(child: CircularProgressIndicator());
      if (_error) {
        return _Vacio(
          icono: Icons.cloud_off_rounded,
          titulo: 'No se pudieron cargar las notificaciones.',
          accion: TextButton(
            onPressed: _refrescar,
            child: const Text('Reintentar'),
          ),
        );
      }
      return const _Vacio(
        icono: Icons.notifications_off_outlined,
        titulo: 'No tienes notificaciones.',
        detalle: 'Aquí verás los pedidos nuevos y entregados.',
      );
    }
    final visibles = _avisos.where(_filtro.acepta).toList();
    final nuevas =
        widget.contador.value ?? _avisos.where((a) => !a.leida).length;
    final ahora = DateTime.now();
    final tarjetas = <Widget>[];
    String? ultimoDia;
    for (final aviso in visibles) {
      final fecha = aviso.fecha?.toLocal();
      final dia = fecha == null ? null : _etiquetaDia(fecha, ahora);
      if (dia != null && dia != ultimoDia) {
        tarjetas.add(_EncabezadoDia(dia));
        ultimoDia = dia;
      }
      tarjetas.add(
        _TarjetaAviso(
          aviso: aviso,
          cuando: fecha == null ? null : _hace(fecha, ahora),
          onTap: () => _abrir(aviso),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _refrescar(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          _Resumen(nuevas: nuevas),
          const SizedBox(height: 14),
          _Segmentos(
            seleccionado: _filtro,
            nuevas: nuevas,
            onCambio: (f) => setState(() => _filtro = f),
          ),
          const SizedBox(height: 6),
          if (visibles.isEmpty)
            _Vacio(
              icono: _filtro == _Filtro.noLeidas
                  ? Icons.done_all_rounded
                  : Icons.mark_email_read_outlined,
              color: _filtro == _Filtro.noLeidas
                  ? BarroTheme.success
                  : BarroTheme.primary,
              fondo: _filtro == _Filtro.noLeidas ? _verdeSuave : productoSuave,
              titulo: _filtro == _Filtro.noLeidas
                  ? '¡Todo al día!'
                  : 'Aún no hay notificaciones leídas.',
              detalle: _ultima
                  ? (_filtro == _Filtro.noLeidas
                        ? 'No tienes notificaciones sin leer.'
                        : null)
                  : 'Hay notificaciones más antiguas por revisar.',
            ),
          ...tarjetas,
          if (!_ultima)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: _cargandoMas
                    ? const CircularProgressIndicator()
                    : OutlinedButton.icon(
                        onPressed: _cargarMas,
                        icon: const Icon(Icons.expand_more_rounded),
                        label: const Text('Cargar más notificaciones'),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

const _verdeSuave = Color(0xFFE3F1EA);
const _meses = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// "Hoy", "Ayer" o la fecha, para agrupar los avisos por día.
String _etiquetaDia(DateTime fecha, DateTime ahora) {
  final dias = DateTime(
    ahora.year,
    ahora.month,
    ahora.day,
  ).difference(DateTime(fecha.year, fecha.month, fecha.day)).inDays;
  if (dias <= 0) return 'Hoy';
  if (dias == 1) return 'Ayer';
  final anio = fecha.year == ahora.year ? '' : ' de ${fecha.year}';
  return '${fecha.day} de ${_meses[fecha.month - 1]}$anio';
}

/// Tiempo transcurrido si es reciente; si no, la hora (el día ya va en el grupo).
String _hace(DateTime fecha, DateTime ahora) {
  final pasado = ahora.difference(fecha);
  if (pasado.inMinutes < 1) return 'Ahora';
  if (pasado.inMinutes < 60) return 'Hace ${pasado.inMinutes} min';
  if (pasado.inHours < 24 && fecha.day == ahora.day) {
    return 'Hace ${pasado.inHours} h';
  }
  final h = fecha.hour.toString().padLeft(2, '0');
  final m = fecha.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// Resumen de arriba: cuántas hay por leer, o que todo está al día.
class _Resumen extends StatelessWidget {
  const _Resumen({required this.nuevas});
  final int nuevas;

  @override
  Widget build(BuildContext context) {
    final alDia = nuevas == 0;
    final color = alDia ? BarroTheme.success : BarroTheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BarroTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: alDia ? _verdeSuave : productoSuave,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              alDia
                  ? Icons.notifications_none_rounded
                  : Icons.notifications_active_outlined,
              color: color,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alDia
                      ? 'Estás al día'
                      : nuevas == 1
                      ? '1 notificación nueva'
                      : '$nuevas notificaciones nuevas',
                  style: BarroTheme.type(16, 23, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  alDia
                      ? 'No tienes avisos pendientes.'
                      : 'Toca una para ver el pedido.',
                  style: BarroTheme.type(13, 19, color: BarroTheme.secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Selector No leídas / Leídas / Todas en una sola barra.
class _Segmentos extends StatelessWidget {
  const _Segmentos({
    required this.seleccionado,
    required this.nuevas,
    required this.onCambio,
  });
  final _Filtro seleccionado;
  final int nuevas;
  final ValueChanged<_Filtro> onCambio;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xFFF3EEEB),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        for (final filtro in _Filtro.values)
          Expanded(
            child: Semantics(
              button: true,
              selected: filtro == seleccionado,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onCambio(filtro),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: filtro == seleccionado
                        ? BarroTheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          filtro.texto,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BarroTheme.type(
                            13,
                            18,
                            weight: filtro == seleccionado
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: filtro == seleccionado
                                ? Colors.white
                                : BarroTheme.secondary,
                          ),
                        ),
                      ),
                      if (filtro == _Filtro.noLeidas && nuevas > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: filtro == seleccionado
                                ? Colors.white
                                : BarroTheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            nuevas > 99 ? '99+' : '$nuevas',
                            style: BarroTheme.type(
                              11,
                              15,
                              weight: FontWeight.w700,
                              color: filtro == seleccionado
                                  ? BarroTheme.primary
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _EncabezadoDia extends StatelessWidget {
  const _EncabezadoDia(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
    child: Text(
      texto.toUpperCase(),
      style: BarroTheme.type(
        12,
        16,
        weight: FontWeight.w700,
        color: BarroTheme.placeholder,
      ),
    ),
  );
}

/// Aviso en tarjeta. El color e ícono distinguen pedido nuevo (terracota) de
/// entregado (verde); los no leídos van en blanco con un punto sobre el ícono.
class _TarjetaAviso extends StatelessWidget {
  const _TarjetaAviso({required this.aviso, required this.onTap, this.cuando});
  final AvisoPedido aviso;
  final VoidCallback onTap;
  final String? cuando;

  @override
  Widget build(BuildContext context) {
    final nueva = !aviso.leida;
    final entregado = aviso.titulo.toLowerCase().contains('entregado');
    final color = entregado ? BarroTheme.success : BarroTheme.primary;
    final tinte = entregado ? _verdeSuave : productoSuave;
    final abre = aviso.pedidoId != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        label: nueva ? 'Sin leer' : 'Leída',
        child: Material(
          color: nueva ? Colors.white : Colors.white.withValues(alpha: 0.6),
          elevation: nueva ? 1.5 : 0,
          shadowColor: BarroTheme.primary.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: nueva
                  ? BarroTheme.primary.withValues(alpha: 0.3)
                  : BarroTheme.border,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: nueva || abre ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: nueva ? tinte : const Color(0xFFF3EEEB),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          entregado
                              ? Icons.local_shipping_outlined
                              : Icons.shopping_bag_outlined,
                          size: 25,
                          color: nueva ? color : BarroTheme.placeholder,
                        ),
                      ),
                      if (nueva)
                        Positioned(
                          top: -3,
                          right: -3,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: BarroTheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                            if (cuando != null) ...[
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  cuando!,
                                  style: BarroTheme.type(
                                    11,
                                    16,
                                    weight: nueva
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: nueva
                                        ? BarroTheme.primary
                                        : BarroTheme.placeholder,
                                  ),
                                ),
                              ),
                            ],
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
                        if (abre) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Ver pedido',
                                style: BarroTheme.type(
                                  12,
                                  16,
                                  weight: FontWeight.w700,
                                  color: nueva ? color : BarroTheme.placeholder,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: nueva ? color : BarroTheme.placeholder,
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
    this.color = BarroTheme.primary,
    this.fondo = productoSuave,
  });
  final IconData icono;
  final String titulo;
  final String? detalle;
  final Widget? accion;
  final Color color;
  final Color fondo;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: fondo,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Icon(icono, size: 36, color: color),
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
