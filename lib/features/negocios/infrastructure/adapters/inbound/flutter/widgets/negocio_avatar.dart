import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'negocios_scaffold.dart';

class NegocioAvatar extends StatelessWidget {
  const NegocioAvatar({
    required this.iniciales,
    this.logo,
    this.contenido,
    this.size = 56,
    super.key,
  });
  final String iniciales;
  final String? logo;
  final Uint8List? contenido;
  final double size;

  Uint8List? get _bytes {
    if (contenido != null) return contenido;
    if (logo == null || !logo!.startsWith('data:')) return null;
    try {
      final data = UriData.parse(logo!);
      if (!const ['image/png', 'image/jpeg'].contains(data.mimeType)) {
        return null;
      }
      return data.contentAsBytes();
    } on FormatException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    final fallback = NegocioInitials(iniciales: iniciales, size: size);
    if (bytes == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: 192,
        errorBuilder: (_, error, stack) => fallback,
      ),
    );
  }
}
