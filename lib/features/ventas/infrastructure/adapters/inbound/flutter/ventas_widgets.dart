import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';

const _fondoSuave = Color(0xFFF8E7DF);

class VentaScaffold extends StatelessWidget {
  const VentaScaffold({
    required this.contexto,
    required this.paso,
    required this.accion,
    required this.children,
    required this.onCancelar,
    this.onAccion,
    this.iconoAccion,
    this.procesando = false,
    this.resumen,
    this.debajoAccion,
    this.textoCancelar = 'Cancelar',
    this.espacioAntesContenido = 28,
    super.key,
  });

  final VentaContexto contexto;
  final String paso;
  final String accion;
  final List<Widget> children;
  final VoidCallback? onAccion;

  /// Ícono opcional que acompaña al texto de la acción principal.
  final IconData? iconoAccion;
  final VoidCallback? onCancelar;
  final bool procesando;
  final Widget? resumen;

  /// Contenido entre la acción principal y el botón de cancelar (p. ej. la
  /// sección para imprimir el ticket de la venta registrada).
  final Widget? debajoAccion;
  final String textoCancelar;
  final double espacioAntesContenido;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BarroTheme.background,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
                  children: [
                    contexto,
                    const SizedBox(height: 28),
                    Text(
                      'Registro de venta',
                      style: BarroTheme.type(30, 36, weight: FontWeight.w700),
                    ),
                    Text(
                      paso,
                      style: BarroTheme.type(
                        14,
                        20,
                        color: BarroTheme.secondary,
                      ),
                    ),
                    SizedBox(height: espacioAntesContenido),
                    ...children,
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (resumen case final contenido?) ...[
                      contenido,
                      const SizedBox(height: 8),
                    ],
                    _AccionesVenta(
                      accion: accion,
                      iconoAccion: iconoAccion,
                      onAccion: onAccion,
                      onCancelar: onCancelar,
                      procesando: procesando,
                      debajoAccion: debajoAccion,
                      textoCancelar: textoCancelar,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class VentaContexto extends StatelessWidget {
  const VentaContexto({
    required this.negocio,
    required this.sucursal,
    required this.rol,
    super.key,
  });

  final String negocio;
  final String sucursal;
  final String rol;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          SvgPicture.asset(
            'assets/icons/brand.svg',
            width: 32,
            height: 32,
            excludeFromSemantics: true,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'BarroControl',
              style: BarroTheme.type(18, 24, weight: FontWeight.w700),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: _fondoSuave,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                rol,
                style: BarroTheme.type(12, 16, color: BarroTheme.primary),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _fondoSuave,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$negocio · $sucursal',
              style: BarroTheme.type(13, 18, weight: FontWeight.w700),
            ),
            Text(
              'Sesión actual',
              style: BarroTheme.type(12, 17, color: BarroTheme.secondary),
            ),
          ],
        ),
      ),
    ],
  );
}

class VentaCampo extends StatelessWidget {
  const VentaCampo({
    required this.etiqueta,
    required this.child,
    this.accionEtiqueta,
    super.key,
  });

  final String etiqueta;
  final Widget child;
  final Widget? accionEtiqueta;

  @override
  Widget build(BuildContext context) {
    final titulo = ExcludeSemantics(
      child: Text(
        etiqueta,
        style: BarroTheme.type(13, 18, weight: FontWeight.w500),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (accionEtiqueta case final accion?)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(flex: 2, child: titulo),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Align(alignment: Alignment.bottomRight, child: accion),
              ),
            ],
          )
        else
          titulo,
        const SizedBox(height: 6),
        Semantics(label: etiqueta, child: child),
      ],
    );
  }
}

InputDecoration decoracionCampoVenta({String? indicacion, String? error}) =>
    InputDecoration(
      hintText: indicacion,
      errorText: error,
      errorMaxLines: 3,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BarroTheme.border),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );

String dineroVenta(num importe) => '\$${importe.toStringAsFixed(2)}';

class AvisoVenta extends StatelessWidget {
  const AvisoVenta(this.mensaje, {this.onReintentar, super.key});

  final String mensaje;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) => VentaPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            mensaje,
            style: BarroTheme.type(14, 20, color: BarroTheme.error),
          ),
        ),
        if (onReintentar != null)
          TextButton(onPressed: onReintentar, child: const Text('Reintentar')),
      ],
    ),
  );
}

class VentaPanel extends StatelessWidget {
  const VentaPanel({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: BarroTheme.border),
      borderRadius: BorderRadius.circular(20),
    ),
    child: child,
  );
}

class _AccionesVenta extends StatelessWidget {
  const _AccionesVenta({
    required this.accion,
    required this.iconoAccion,
    required this.onAccion,
    required this.onCancelar,
    required this.procesando,
    required this.debajoAccion,
    required this.textoCancelar,
  });

  final String accion;
  final IconData? iconoAccion;
  final VoidCallback? onAccion;
  final VoidCallback? onCancelar;
  final bool procesando;
  final Widget? debajoAccion;
  final String textoCancelar;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilledButton(
        onPressed: onAccion,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: BarroTheme.type(14, 20, weight: FontWeight.w600),
        ),
        child: procesando
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  semanticsLabel: 'Registrando venta',
                ),
              )
            : iconoAccion == null
            ? Text(accion, textAlign: TextAlign.center)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: Text(accion, textAlign: TextAlign.center)),
                  const SizedBox(width: 8),
                  Icon(iconoAccion, size: 20),
                ],
              ),
      ),
      if (debajoAccion case final contenido?) ...[
        const SizedBox(height: 8),
        contenido,
      ],
      TextButton(
        onPressed: onCancelar,
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          textStyle: BarroTheme.type(14, 20, weight: FontWeight.w600),
        ),
        child: Text(textoCancelar),
      ),
    ],
  );
}
