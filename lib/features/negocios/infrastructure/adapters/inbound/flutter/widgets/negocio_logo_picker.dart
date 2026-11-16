import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'negocios_scaffold.dart' show negociosSuave;
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
      Text.rich(
        TextSpan(
          text: 'Logo del negocio',
          children: [
            TextSpan(
              text: '  (opcional)',
              style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
            ),
          ],
        ),
        style: BarroTheme.type(13, 18, weight: FontWeight.w500),
      ),
      const SizedBox(height: 10),
      Semantics(
        button: true,
        enabled: onSeleccionar != null,
        child: Material(
          color: BarroTheme.background,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onSeleccionar,
            borderRadius: BorderRadius.circular(18),
            child: CustomPaint(
              painter: _DashedBorderPainter(
                color: _seleccionado ? BarroTheme.primary : BarroTheme.border,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 22,
                ),
                child: Column(
                  children: [
                    if (_seleccionado)
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: BarroTheme.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: NegocioAvatar(
                              iniciales: iniciales ?? '',
                              logo: logo,
                              contenido: contenido,
                              size: 88,
                            ),
                          ),
                          Positioned(
                            right: -6,
                            bottom: -6,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle_rounded,
                                size: 22,
                                color: BarroTheme.success,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: negociosSuave,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 32,
                          color: BarroTheme.primary,
                        ),
                      ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: negociosSuave,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _seleccionado
                                ? Icons.sync_rounded
                                : Icons.upload_rounded,
                            size: 18,
                            color: BarroTheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _seleccionado ? 'Cambiar logo' : 'Seleccionar logo',
                            style: BarroTheme.type(
                              14,
                              20,
                              weight: FontWeight.w600,
                              color: BarroTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
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
          child: TextButton.icon(
            onPressed: onQuitar,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Quitar logo'),
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 44),
              foregroundColor: BarroTheme.error,
              disabledForegroundColor: BarroTheme.error.withValues(alpha: 0.5),
              textStyle: BarroTheme.type(14, 20, weight: FontWeight.w500),
            ),
          ),
        ),
      ],
    ],
  );
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.5),
          const Radius.circular(18),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final metric in path.computeMetrics()) {
      for (double start = 0; start < metric.length; start += 8) {
        canvas.drawPath(metric.extractPath(start, start + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
