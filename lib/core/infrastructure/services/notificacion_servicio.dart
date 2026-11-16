import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

/// Acción opcional dentro de una notificación (p. ej. "Reintentar").
class AccionNotificacion {
  const AccionNotificacion(this.etiqueta, this.onPressed);
  final String etiqueta;
  final VoidCallback onPressed;
}

/// Notificaciones emergentes (toasts) de la app con Toastification.
///
/// Todas usan [ToastificationStyle.flatColored]: el color sale del tipo
/// (éxito, error, advertencia, información), así que no se fijan colores aquí.
/// Solo se llama desde los adaptadores de entrada (pantallas Flutter), nunca
/// desde la capa de aplicación ni del dominio.
class NotificacionServicio {
  const NotificacionServicio._();

  static const _duracion = Duration(seconds: 4);
  static const _duracionLarga = Duration(seconds: 6);

  static void exito(
    BuildContext context,
    String mensaje, {
    String titulo = 'Listo',
    AccionNotificacion? accion,
  }) => _mostrar(
    context,
    ToastificationType.success,
    titulo,
    mensaje,
    accion: accion,
  );

  /// Los errores duran más en pantalla para que se alcancen a leer.
  static void error(
    BuildContext context,
    String mensaje, {
    String titulo = 'Algo salió mal',
    AccionNotificacion? accion,
  }) => _mostrar(
    context,
    ToastificationType.error,
    titulo,
    mensaje,
    duracion: _duracionLarga,
    accion: accion,
  );

  static void advertencia(
    BuildContext context,
    String mensaje, {
    String titulo = 'Atención',
    AccionNotificacion? accion,
  }) => _mostrar(
    context,
    ToastificationType.warning,
    titulo,
    mensaje,
    duracion: _duracionLarga,
    accion: accion,
  );

  static void info(
    BuildContext context,
    String mensaje, {
    String titulo = 'Información',
    AccionNotificacion? accion,
  }) => _mostrar(
    context,
    ToastificationType.info,
    titulo,
    mensaje,
    accion: accion,
  );

  // Atajos para los resultados más comunes de un CRUD.

  static void registro(BuildContext context, String mensaje) =>
      exito(context, mensaje, titulo: 'Registro exitoso');

  static void actualizacion(BuildContext context, String mensaje) =>
      exito(context, mensaje, titulo: 'Actualización exitosa');

  static void eliminacion(BuildContext context, String mensaje) =>
      exito(context, mensaje, titulo: 'Eliminado');

  static void _mostrar(
    BuildContext context,
    ToastificationType tipo,
    String titulo,
    String mensaje, {
    Duration duracion = _duracion,
    AccionNotificacion? accion,
  }) {
    late final ToastificationItem item;
    item = toastification.show(
      context: context,
      type: tipo,
      style: ToastificationStyle.flatColored,
      title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
      description: accion == null
          ? Text(mensaje)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(mensaje),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: () {
                      toastification.dismiss(item);
                      accion.onPressed();
                    },
                    child: Text(accion.etiqueta),
                  ),
                ),
              ],
            ),
      alignment: Alignment.topRight,
      autoCloseDuration: duracion,
      animationDuration: const Duration(milliseconds: 300),
      showProgressBar: false,
      closeButton: const ToastCloseButton(showType: CloseButtonShowType.always),
      // Con una acción, tocar el aviso no debe cerrarlo antes de pulsar el botón.
      closeOnClick: accion == null,
      pauseOnHover: true,
      dragToClose: true,
    );
  }
}
