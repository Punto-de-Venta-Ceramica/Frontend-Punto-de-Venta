import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';

abstract interface class IndicadorIcono {
  Future<void> actualizar(int cantidad);
}

/// Mantiene el conteo del usuario conectado mientras la aplicación está activa.
class ContadorNotificaciones extends ValueNotifier<int?>
    with WidgetsBindingObserver {
  ContadorNotificaciones(
    this._api,
    this._icono, {
    this.intervalo = const Duration(seconds: 45),
  }) : super(null) {
    WidgetsBinding.instance.addObserver(this);
  }

  final ApiClient _api;
  final IndicadorIcono _icono;
  final Duration intervalo;
  Timer? _timer;
  String? _sesion;
  int _generacion = 0;
  int _solicitud = 0;
  bool _activa = true;
  Future<void> _colaIcono = Future.value();

  void iniciar(String token) {
    if (_sesion == token) return;
    _timer?.cancel();
    _sesion = token;
    _generacion++;
    value = null;
    _encolarIcono(0);
    _timer = Timer.periodic(intervalo, (_) {
      if (_activa) unawaited(actualizar());
    });
    unawaited(actualizar());
  }

  Future<void> actualizar() async {
    if (_sesion == null || !_activa) return;
    final generacion = _generacion;
    final solicitud = ++_solicitud;
    try {
      final data = await _api.getJson('api/notificaciones/no-leidas/conteo');
      final cantidad = data['cantidad'];
      if (cantidad is! int || cantidad < 0) return;
      if (generacion != _generacion || solicitud != _solicitud || !_activa) {
        return;
      }
      value = cantidad;
      _encolarIcono(cantidad);
    } catch (_) {
      // Conserva el último conteo conocido si falla la conexión.
    }
  }

  void cerrarSesion() {
    _generacion++;
    _solicitud++;
    _sesion = null;
    _timer?.cancel();
    _timer = null;
    value = null;
    _encolarIcono(0);
  }

  void _encolarIcono(int cantidad) {
    _colaIcono = _colaIcono
        .then((_) => _icono.actualizar(cantidad))
        .catchError((Object _) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _activa = state == AppLifecycleState.resumed;
    if (_activa) unawaited(actualizar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _generacion++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
