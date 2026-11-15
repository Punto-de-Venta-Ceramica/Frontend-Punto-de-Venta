import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';

/// Servicio centralizado de notificaciones y alertas usando Toastification 3.2.2.
/// Muestra toasts verdes claros para registros, actualizaciones y eliminaciones exitosas.
class AlertaServicio {
  const AlertaServicio._();

  /// Verde claro suave característico de BarroControl
  static const Color fondoVerdeClaro = Color(0xFFECF7F1);
  static const Color textoVerde = Color(0xFF1B6A3E);
  static const Color iconoVerde = Color(0xFF2E8540);

  /// Muestra una alerta de éxito con estilo verde claro.
  static void exito(
    BuildContext context, {
    required String mensaje,
    String? titulo,
    Duration duracion = const Duration(seconds: 4),
  }) {
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.flat,
      autoCloseDuration: duracion,
      title: titulo != null
          ? Text(
              titulo,
              style: BarroTheme.type(
                14,
                20,
                weight: FontWeight.w700,
                color: textoVerde,
              ),
            )
          : null,
      description: Text(
        mensaje,
        style: BarroTheme.type(
          13,
          18,
          weight: FontWeight.w500,
          color: textoVerde,
        ),
      ),
      alignment: Alignment.topRight,
      direction: TextDirection.ltr,
      animationDuration: const Duration(milliseconds: 300),
      icon: const Icon(Icons.check_circle_rounded, color: iconoVerde, size: 22),
      primaryColor: iconoVerde,
      backgroundColor: fondoVerdeClaro,
      foregroundColor: textoVerde,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 16,
          offset: Offset(0, 4),
          spreadRadius: 0,
        ),
      ],
      showProgressBar: false,
      closeButton: ToastCloseButton(showType: CloseButtonShowType.always),
      closeOnClick: true,
      pauseOnHover: true,
      dragToClose: true,
    );
  }

  /// Notificación específica para cuando se registra algo exitosamente.
  static void registro(
    BuildContext context,
    String elemento, {
    String? detalle,
  }) {
    exito(
      context,
      titulo: 'Registro exitoso',
      mensaje: detalle ?? '$elemento registrado correctamente.',
    );
  }

  /// Notificación específica para cuando se actualiza algo exitosamente.
  static void actualizacion(
    BuildContext context,
    String elemento, {
    String? detalle,
  }) {
    exito(
      context,
      titulo: 'Actualización exitosa',
      mensaje: detalle ?? '$elemento actualizado correctamente.',
    );
  }

  /// Notificación específica para cuando se elimina algo exitosamente.
  static void eliminacion(
    BuildContext context,
    String elemento, {
    String? detalle,
  }) {
    exito(
      context,
      titulo: 'Eliminado',
      mensaje: detalle ?? '$elemento eliminado correctamente.',
    );
  }

  /// Alerta de error en caso de fallo.
  static void error(
    BuildContext context, {
    required String mensaje,
    String? titulo,
    Duration duracion = const Duration(seconds: 4),
  }) {
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.flat,
      autoCloseDuration: duracion,
      title: titulo != null
          ? Text(
              titulo,
              style: BarroTheme.type(
                14,
                20,
                weight: FontWeight.w700,
                color: BarroTheme.error,
              ),
            )
          : null,
      description: Text(
        mensaje,
        style: BarroTheme.type(
          13,
          18,
          weight: FontWeight.w500,
          color: BarroTheme.error,
        ),
      ),
      alignment: Alignment.topRight,
      direction: TextDirection.ltr,
      animationDuration: const Duration(milliseconds: 300),
      icon: const Icon(
        Icons.error_outline_rounded,
        color: BarroTheme.error,
        size: 22,
      ),
      primaryColor: BarroTheme.error,
      backgroundColor: const Color(0xFFFFF0EE),
      foregroundColor: BarroTheme.error,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      borderRadius: BorderRadius.circular(16),
      showProgressBar: false,
      closeButton: ToastCloseButton(showType: CloseButtonShowType.always),
      closeOnClick: true,
      pauseOnHover: true,
      dragToClose: true,
    );
  }
}
