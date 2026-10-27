import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'negocios_scaffold.dart';
import 'negocio_avatar.dart';
import 'dart:typed_data';

class NegocioLogoPicker extends StatelessWidget {
  const NegocioLogoPicker({
    this.iniciales,
    this.logo,
    this.contenido,
    this.onSeleccionar,
    this.onQuitar,
    super.key,
  });

  final String? iniciales;
  final String? logo;
  final Uint8List? contenido;
  final VoidCallback? onSeleccionar;
  final VoidCallback? onQuitar;
  bool get _seleccionado =>
      iniciales != null || logo != null || contenido != null;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Logo del negocio (opcional)', style: BarroTheme.type(13, 18)),
      const SizedBox(height: 10),
      Semantics(
        button: true,
        enabled: onSeleccionar != null,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onSeleccionar,
            borderRadius: BorderRadius.circular(22),
            child: CustomPaint(
              painter: const _DashedBorderPainter(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Column(
                  children: [
                    if (_seleccionado)
                      NegocioAvatar(
                        iniciales: iniciales ?? '',
                        logo: logo,
                        contenido: contenido,
                        size: 64,
                      )
                    else
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: negociosSuave,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 28,
                          color: BarroTheme.primary,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        _seleccionado ? 'Cambiar logo' : 'Seleccionar logo',
                        textAlign: TextAlign.center,
                        style: BarroTheme.type(
                          14,
                          20,
                          weight: FontWeight.w500,
                          color: BarroTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      !_seleccionado
                          ? 'Puedes agregarlo ahora o más adelante.'
                          : 'Logo seleccionado',
                      textAlign: TextAlign.center,
                      style: BarroTheme.type(
                        12,
                        18,
                        color: BarroTheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      if (_seleccionado) ...[
        const SizedBox(height: 4),
        Center(
          child: NegociosTextButton(label: 'Quitar logo', onPressed: onQuitar),
        ),
      ],
    ],
  );
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.5),
          const Radius.circular(22),
        ),
      );
    final paint = Paint()
      ..color = BarroTheme.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      for (double start = 0; start < metric.length; start += 8) {
        canvas.drawPath(metric.extractPath(start, start + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => false;
}
