import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';

class BarroInput extends StatefulWidget {
  const BarroInput({
    required this.fieldKey,
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.errors = const [],
    this.validName = false,
    this.password = false,
    this.bulletedErrors = false,
    this.keyboardType,
    this.autofillHints,
    this.inputFormatters,
    this.last = false,
    this.onSubmitted,
    super.key,
  });

  final String fieldKey;
  final String label;
  final String hint;
  final String icon;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onChanged;
  final List<String> errors;
  final bool validName;
  final bool password;
  final bool bulletedErrors;
  final bool last;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final VoidCallback? onSubmitted;

  @override
  State<BarroInput> createState() => _BarroInputState();
}

class _BarroInputState extends State<BarroInput> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errors.isNotEmpty;
    final color = hasError
        ? BarroTheme.error
        : widget.validName
        ? BarroTheme.success
        : widget.focusNode.hasFocus
        ? BarroTheme.primary
        : BarroTheme.border;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: BarroTheme.type(13, 18, weight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              SvgPicture.asset(
                'assets/icons/${widget.icon}.svg',
                width: 20,
                height: 20,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  label: widget.label,
                  child: TextField(
                    key: ValueKey(widget.fieldKey),
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    style: BarroTheme.type(
                      14,
                      20,
                      color: BarroTheme.placeholder,
                    ),
                    cursorColor: BarroTheme.primary,
                    obscureText: widget.password && !_visible,
                    obscuringCharacter: '•',
                    enableSuggestions: !widget.password,
                    autocorrect: !widget.password,
                    keyboardType: widget.keyboardType,
                    autofillHints: widget.autofillHints,
                    inputFormatters: widget.inputFormatters,
                    textCapitalization: widget.icon == 'person'
                        ? TextCapitalization.words
                        : TextCapitalization.none,
                    textInputAction: widget.last
                        ? TextInputAction.done
                        : TextInputAction.next,
                    onSubmitted: (_) {
                      if (widget.last) {
                        widget.onSubmitted?.call();
                      } else {
                        FocusScope.of(context).nextFocus();
                      }
                    },
                    onChanged: (_) => widget.onChanged(),
                    decoration: InputDecoration(
                      hintText: hasError && widget.controller.text.isEmpty
                          ? ''
                          : widget.hint,
                      hintStyle: BarroTheme.type(
                        14,
                        20,
                        color: BarroTheme.placeholder,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              if (widget.password)
                SizedBox(
                  width: 36,
                  height: 46,
                  child: IconButton(
                    key: ValueKey('${widget.fieldKey}-visibility'),
                    tooltip: _visible
                        ? 'Ocultar ${widget.label.toLowerCase()}'
                        : 'Mostrar ${widget.label.toLowerCase()}',
                    padding: const EdgeInsets.only(left: 12),
                    onPressed: () => setState(() => _visible = !_visible),
                    icon: SvgPicture.asset(
                      'assets/icons/eye.svg',
                      width: 20,
                      height: 20,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (hasError || widget.validName) ...[
          const SizedBox(height: 6),
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      minWidth: 20,
                      maxWidth: 20,
                      minHeight: 20,
                      maxHeight: 20,
                      child: SvgPicture.asset(
                        'assets/icons/${hasError ? 'error' : 'success'}.svg',
                        width: 20,
                        height: 20,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    hasError
                        ? widget.errors
                              .map((e) => widget.bulletedErrors ? '• $e' : e)
                              .join('\n')
                        : 'Nombre válido.',
                    style: BarroTheme.type(
                      12,
                      17,
                      color: hasError ? BarroTheme.error : BarroTheme.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
