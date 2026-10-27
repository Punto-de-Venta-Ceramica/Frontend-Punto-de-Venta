import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';

const negociosSuave = Color(0xFFF8E7DF);

class NegociosScaffold extends StatelessWidget {
  const NegociosScaffold({required this.children, this.footer, super.key});

  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _NegociosHeader(),
                        const SizedBox(height: 28),
                        ...children,
                        if (footer != null) ...[
                          const SizedBox(height: 48),
                          const Spacer(),
                          footer!,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _NegociosHeader extends StatelessWidget {
  const _NegociosHeader();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SvgPicture.asset(
        'assets/icons/brand.svg',
        width: 32,
        height: 32,
        semanticsLabel: 'Logo de BarroControl',
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          'BarroControl',
          style: BarroTheme.type(18, 26, weight: FontWeight.w600),
        ),
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: negociosSuave,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Propietario',
          style: BarroTheme.type(11, 16, color: BarroTheme.primary),
        ),
      ),
    ],
  );
}

class NegociosPrimaryButton extends StatelessWidget {
  const NegociosPrimaryButton({
    required this.label,
    this.destructivo = false,
    this.onPressed,
    super.key,
  });

  final String label;
  final bool destructivo;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      disabledBackgroundColor: destructivo
          ? BarroTheme.error
          : BarroTheme.primary,
      disabledForegroundColor: Colors.white,
      backgroundColor: destructivo ? BarroTheme.error : BarroTheme.primary,
      foregroundColor: Colors.white,
      textStyle: BarroTheme.type(14, 20, weight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    child: Text(label, textAlign: TextAlign.center),
  );
}

class NegociosTextButton extends StatelessWidget {
  const NegociosTextButton({
    required this.label,
    this.icon,
    this.onPressed,
    super.key,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      minimumSize: const Size(48, 44),
      padding: const EdgeInsets.symmetric(vertical: 12),
      disabledForegroundColor: BarroTheme.primary,
      foregroundColor: BarroTheme.primary,
      textStyle: BarroTheme.type(14, 20, weight: FontWeight.w500),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: BarroTheme.secondary),
          const SizedBox(width: 10),
        ],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    ),
  );
}

class NegocioInitials extends StatelessWidget {
  const NegocioInitials({required this.iniciales, this.size = 56, super.key});

  final String iniciales;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: negociosSuave,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      iniciales,
      style: BarroTheme.type(
        size > 56 ? 30 : 18,
        size > 56 ? 36 : 26,
        weight: FontWeight.w600,
        color: BarroTheme.primary,
      ),
    ),
  );
}
