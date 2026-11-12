import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/authentication/domain/auth_session.dart';
import 'package:punto_de_venta/features/notificaciones/infrastructure/boton_notificaciones.dart';

class SessionPage extends StatefulWidget {
  const SessionPage({
    required this.session,
    required this.clearSession,
    this.openBusinesses,
    this.openEmployees,
    this.openOrders,
    this.openCorteCaja,
    this.conteoNotificaciones,
    this.openNotifications,
    this.sessionExpired,
    super.key,
  });
  final AuthSession session;
  final VoidCallback clearSession;
  final VoidCallback? openBusinesses;
  final VoidCallback? openEmployees;
  final VoidCallback? openOrders;
  final VoidCallback? openCorteCaja;
  final ValueListenable<int?>? conteoNotificaciones;
  final VoidCallback? openNotifications;

  /// Avisa que la sesión terminó (el token de renovación ya no sirve).
  final Listenable? sessionExpired;
  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> with WidgetsBindingObserver {
  Timer? _expiryTimer;
  bool _ended = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.sessionExpired?.addListener(_onSessionExpired);
    _scheduleExpiry();
  }

  void _onSessionExpired() => _logout(expired: true);

  /// Cierra sesión solo cuando vence el token de renovación (no el de acceso, que
  /// se renueva solo). Se re-programa por tramos para no depender de temporizadores
  /// larguísimos.
  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    final remaining = widget.session.refreshExpiresAt.difference(
      DateTime.now(),
    );
    const maxStep = Duration(hours: 6);
    if (remaining <= Duration.zero) {
      _expiryTimer = Timer(Duration.zero, () => _logout(expired: true));
    } else if (remaining > maxStep) {
      _expiryTimer = Timer(maxStep, _scheduleExpiry);
    } else {
      _expiryTimer = Timer(remaining, () => _logout(expired: true));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.session.isExpired) {
      _logout(expired: true);
    }
  }

  void _logout({bool expired = false}) {
    if (!mounted || _ended) return;
    _ended = true;
    widget.clearSession();
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    if (expired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu sesión expiró. Inicia sesión de nuevo.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    widget.sessionExpired?.removeListener(_onSessionExpired);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 84,
      titleSpacing: 24,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/icons/brand.svg',
            width: 36,
            height: 36,
            semanticsLabel: 'Logo de BarroControl',
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'BarroControl',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BarroTheme.type(21, 28, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
      actions: [
        if (widget.conteoNotificaciones != null &&
            widget.openNotifications != null)
          BotonNotificaciones(
            conteo: widget.conteoNotificaciones!,
            onPressed: widget.openNotifications!,
          ),
      ],
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(
                    color: _suave,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 48,
                    color: BarroTheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Sesión iniciada',
                textAlign: TextAlign.center,
                style: BarroTheme.type(28, 36, weight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _suave,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Perfil: ${widget.session.role}',
                    style: BarroTheme.type(
                      13,
                      19,
                      weight: FontWeight.w700,
                      color: BarroTheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              if (widget.session.role == 'EMPLEADO') ...[
                if (widget.openOrders != null)
                  _accion(
                    icono: Icons.receipt_long_outlined,
                    titulo: 'Pedidos',
                    descripcion: 'Registra y consulta los pedidos',
                    onTap: widget.openOrders,
                  ),
                if (widget.openCorteCaja != null)
                  _accion(
                    icono: Icons.point_of_sale_outlined,
                    titulo: 'Corte de caja',
                    descripcion: 'Abrir turno o realizar corte de caja',
                    onTap: widget.openCorteCaja,
                  ),
              ],
              if (widget.session.role == 'PROPIETARIO') ...[
                if (widget.openBusinesses != null)
                  _accion(
                    icono: Icons.storefront_outlined,
                    titulo: 'Administrar negocios',
                    descripcion: 'Sucursales, productos y más',
                    onTap: widget.openBusinesses,
                  ),
                if (widget.openEmployees != null)
                  _accion(
                    icono: Icons.people_outline_rounded,
                    titulo: 'Gestionar empleados',
                    descripcion: 'Gestiona a las personas de tu equipo',
                    onTap: widget.openEmployees,
                  ),
              ],
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  static const _suave = Color(0xFFF7E7DF);

  Widget _accion({
    required IconData icono,
    required String titulo,
    required String descripcion,
    required VoidCallback? onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(21),
        side: const BorderSide(color: BarroTheme.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(21),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _suave,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icono, size: 30, color: BarroTheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: BarroTheme.type(17, 24, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      descripcion,
                      style: BarroTheme.type(
                        13,
                        19,
                        color: BarroTheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: BarroTheme.primary),
            ],
          ),
        ),
      ),
    ),
  );
}
