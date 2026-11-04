import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class BotonNotificaciones extends StatelessWidget {
  const BotonNotificaciones({
    required this.conteo,
    required this.onPressed,
    super.key,
  });
  final ValueListenable<int?> conteo;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int?>(
    valueListenable: conteo,
    builder: (context, cantidad, _) => IconButton(
      tooltip: cantidad == null
          ? 'Notificaciones'
          : 'Notificaciones: $cantidad sin leer',
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: cantidad != null && cantidad > 0,
        label: Text(
          cantidad != null && cantidad > 99 ? '99+' : '${cantidad ?? 0}',
        ),
        child: const Icon(Icons.notifications_outlined),
      ),
    ),
  );
}
