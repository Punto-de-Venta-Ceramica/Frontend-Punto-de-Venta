import 'dart:async';
import 'package:flutter/material.dart';
import 'package:punto_de_venta/features/authentication/domain/auth_session.dart';

class SessionPage extends StatefulWidget {
  const SessionPage({
    required this.session,
    required this.clearSession,
    super.key,
  });
  final AuthSession session;
  final VoidCallback clearSession;
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
    _expiryTimer = Timer(
      widget.session.expiresAt.difference(DateTime.now()),
      () => _logout(expired: true),
    );
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('BarroControl')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, size: 56),
            const SizedBox(height: 16),
            Text(
              'Sesión iniciada',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('Perfil: ${widget.session.role}'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _logout,
              child: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    ),
  );
}
