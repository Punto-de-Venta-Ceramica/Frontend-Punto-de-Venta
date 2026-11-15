import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/core/infrastructure/widgets/barro_header.dart';
import 'package:punto_de_venta/features/authentication/application/ports/outbound/authentication_gateway.dart';
import 'package:punto_de_venta/features/authentication/domain/auth_session.dart';
import 'package:punto_de_venta/features/authentication/infrastructure/adapters/inbound/flutter/cambiar_password_dialog.dart';

class SessionPage extends StatefulWidget {
  const SessionPage({
    required this.session,
    required this.clearSession,
    this.home,
    this.openOrders,
    this.conteoNotificaciones,
    this.openNotifications,
    this.sessionExpired,
    this.refreshExpiresAt,
    this.authGateway,
    super.key,
  });
  final AuthSession session;
  final VoidCallback clearSession;

  /// Pantalla que sustituye a la de sesión (p. ej. "Mis negocios" del
  /// propietario); la página sigue vigilando la expiración de la sesión.
  final Widget? home;
  final VoidCallback? openOrders;
  final ValueListenable<int?>? conteoNotificaciones;
  final VoidCallback? openNotifications;

  /// Gateway de autenticación para cambiar contraseña desde la sesión.
  final AuthenticationGateway? authGateway;

  /// Avisa que la sesión terminó (el token de renovación ya no sirve).
  final Listenable? sessionExpired;

  /// Vencimiento vigente del token de renovación; cambia con cada renovación
  /// (deslizante). Si no se da, se usa el de [session].
  final DateTime Function()? refreshExpiresAt;
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

  DateTime get _vence =>
      widget.refreshExpiresAt?.call() ?? widget.session.refreshExpiresAt;

  /// Cierra sesión solo cuando vence el token de renovación (no el de acceso, que
  /// se renueva solo). Se re-programa por tramos para no depender de temporizadores
  /// larguísimos.
  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    final programado = _vence;
    final remaining = programado.difference(DateTime.now());
    const maxStep = Duration(hours: 6);
    if (remaining <= Duration.zero) {
      _expiryTimer = Timer(Duration.zero, () => _logout(expired: true));
    } else if (remaining > maxStep) {
      _expiryTimer = Timer(maxStep, _scheduleExpiry);
    } else {
      // Al vencer se vuelve a revisar: una renovación pudo extender la sesión.
      _expiryTimer = Timer(remaining, () {
        if (_vence != programado) {
          _scheduleExpiry();
        } else {
          _logout(expired: true);
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_vence.isAfter(DateTime.now())) {
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
  Widget build(BuildContext context) =>
      widget.home ??
      Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: BarroHeader(
                  conteoNotificaciones: widget.conteoNotificaciones,
                  onNotificaciones: widget.openNotifications,
                ),
              ),
              Expanded(
                child: Center(
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
                          if (widget.session.role == 'EMPLEADO' &&
                              widget.openOrders != null)
                            _accion(
                              icono: Icons.receipt_long_outlined,
                              titulo: 'Pedidos',
                              descripcion: 'Registra y consulta los pedidos',
                              onTap: widget.openOrders,
                            ),
                          const SizedBox(height: 4),
                          if (widget.authGateway != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: OutlinedButton.icon(
                                onPressed: () => showDialog<void>(
                                  context: context,
                                  builder: (_) => CambiarPasswordDialog(
                                    gateway: widget.authGateway!,
                                    obligatorio: false,
                                  ),
                                ),
                                icon: const Icon(Icons.lock_outline_rounded),
                                label: const Text('Cambiar contraseña'),
                              ),
                            ),
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
              ),
            ],
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
