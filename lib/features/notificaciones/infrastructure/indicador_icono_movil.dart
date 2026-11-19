import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../application/contador_notificaciones.dart';

/// El contador nativo es opcional: no interfiere con la campana de la app.
class IndicadorIconoMovil implements IndicadorIcono {
  bool _permisoSolicitado = false;

  @override
  Future<void> actualizar(int cantidad) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    try {
      if (cantidad > 0) {
        var permiso = await Permission.notification.status;
        if (permiso.isDenied && !_permisoSolicitado) {
          _permisoSolicitado = true;
          permiso = await Permission.notification.request();
        }
        if (!permiso.isGranted && !permiso.isProvisional) return;
      }
      if (await AppBadgePlus.isSupported()) {
        await AppBadgePlus.updateBadge(cantidad);
      }
    } on PlatformException {
      // Algunos launchers no permiten insignias; el contador interno sigue funcionando.
    } on MissingPluginException {
      // Plataforma sin implementación nativa disponible.
    }
  }
}
