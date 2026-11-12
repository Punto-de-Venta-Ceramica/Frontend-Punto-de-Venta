import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';

const _fondoSuave = Color(0xFFF8E7DF);

/// Acciones del encabezado compartidas por todas las pantallas de un bloque: un
/// [BarroHeader] sin acciones propias usa las del [BarroHeaderScope] más cercano.
class BarroHeaderScope extends InheritedWidget {
  const BarroHeaderScope({
    required super.child,
    this.onPerfil,
    this.onNotificaciones,
    this.conteoNotificaciones,
    super.key,
  });

  final VoidCallback? onPerfil;
  final VoidCallback? onNotificaciones;
  final ValueListenable<int?>? conteoNotificaciones;

  static BarroHeaderScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BarroHeaderScope>();

  @override
  bool updateShouldNotify(BarroHeaderScope old) =>
      onPerfil != old.onPerfil ||
      onNotificaciones != old.onNotificaciones ||
      conteoNotificaciones != old.conteoNotificaciones;
}

/// Encabezado común: perfil a la izquierda, logo con nombre al centro y
/// notificaciones a la derecha.
class BarroHeader extends StatelessWidget {
  const BarroHeader({
    this.onPerfil,
    this.onNotificaciones,
    this.conteoNotificaciones,
    super.key,
  });

  final VoidCallback? onPerfil;
  final VoidCallback? onNotificaciones;

  /// Si se indica, el punto rojo solo aparece cuando hay notificaciones sin leer.
  final ValueListenable<int?>? conteoNotificaciones;

  @override
  Widget build(BuildContext context) {
    final alcance = BarroHeaderScope.maybeOf(context);
    final perfil = onPerfil ?? alcance?.onPerfil;
    final notificaciones = onNotificaciones ?? alcance?.onNotificaciones;
    final conteo = conteoNotificaciones ?? alcance?.conteoNotificaciones;
    return SizedBox(height: 48, child: _fila(perfil, notificaciones, conteo));
  }

  Widget _fila(
    VoidCallback? perfil,
    VoidCallback? notificaciones,
    ValueListenable<int?>? conteo,
  ) => Row(
    children: [
      _Circulo(
        tooltip: 'Perfil',
        onPressed: perfil,
        child: const Icon(
          Icons.person_rounded,
          size: 24,
          color: BarroTheme.primary,
        ),
      ),
      Expanded(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/icons/brand.svg',
              width: 30,
              height: 30,
              semanticsLabel: 'Logo de BarroControl',
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'BarroControl',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BarroTheme.type(18, 24, weight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
      _Campana(onPressed: notificaciones, conteo: conteo),
    ],
  );
}

class _Circulo extends StatelessWidget {
  const _Circulo({required this.child, this.onPressed, this.tooltip});
  final Widget child;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip ?? '',
    child: Material(
      color: _fondoSuave,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(width: 44, height: 44, child: Center(child: child)),
      ),
    ),
  );
}

class _Campana extends StatelessWidget {
  const _Campana({this.onPressed, this.conteo});
  final VoidCallback? onPressed;
  final ValueListenable<int?>? conteo;

  Widget _icono(bool punto) => Stack(
    clipBehavior: Clip.none,
    children: [
      const Icon(
        Icons.notifications_none_rounded,
        size: 28,
        color: BarroTheme.text,
      ),
      if (punto)
        Positioned(
          right: 1,
          top: 0,
          child: Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: BarroTheme.error,
              shape: BoxShape.circle,
            ),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final listenable = conteo;
    return _Circulo(
      tooltip: 'Notificaciones',
      onPressed: onPressed,
      child: listenable == null
          ? _icono(false)
          : ValueListenableBuilder<int?>(
              valueListenable: listenable,
              builder: (_, n, _) => _icono(n != null && n > 0),
            ),
    );
  }
}
