import 'package:flutter/material.dart';
import 'core/infrastructure/theme/barro_theme.dart';
import 'features/negocios/domain/negocio.dart';
import 'features/negocios/infrastructure/adapters/inbound/flutter/mis_negocios_page.dart';
import 'features/negocios/infrastructure/adapters/inbound/flutter/negocio_form_page.dart';
import 'features/negocios/infrastructure/adapters/inbound/flutter/widgets/confirmar_eliminar_negocio_dialog.dart';

/// Isolated visual scenarios. No API client or authenticated session is created.
void main() {
  final estado =
      Uri.base.queryParameters['estado'] ??
      const String.fromEnvironment('NEGOCIOS_PREVIEW', defaultValue: 'lista');
  final pantalla = switch (estado) {
    'vacio' => const MisNegociosPage(),
    'lista' => const MisNegociosPage(
      negocios: [
        Negocio(id: 1, nombre: 'Cerámica del Centro'),
        Negocio(id: 2, nombre: 'Artesanías La Esquina'),
      ],
    ),
    'registro' => const NegocioFormPage(),
    'completo' => const NegocioFormPage(
      nombreInicial: 'Cerámica del Centro',
      inicialesLogo: 'CC',
    ),
    'validacion' => const NegocioFormPage(
      errorNombre: 'Escribe el nombre de tu negocio.',
    ),
    'editar' => const NegocioFormPage(
      editando: true,
      nombreInicial: 'Cerámica del Centro MX',
      inicialesLogo: 'CC',
    ),
    'guardado' => const MisNegociosPage(
      mensajeExito: 'Cambios guardados correctamente.',
      negocios: [
        Negocio(id: 1, nombre: 'Cerámica del Centro MX'),
        Negocio(id: 2, nombre: 'Artesanías La Esquina'),
      ],
    ),
    'eliminar' => const Stack(
      children: [
        NegocioFormPage(
          editando: true,
          nombreInicial: 'Cerámica del Centro',
          inicialesLogo: 'CC',
          mostrarEliminar: true,
        ),
        Positioned.fill(
          child: ModalBarrier(dismissible: false, color: Color(0x61000000)),
        ),
        Center(
          child: ConfirmarEliminarNegocioDialog(
            nombreNegocio: 'Cerámica del Centro',
          ),
        ),
      ],
    ),
    _ => throw ArgumentError.value(
      estado,
      'NEGOCIOS_PREVIEW',
      'Estado visual desconocido',
    ),
  };

  runApp(
    MaterialApp(
      title: 'BarroControl · Negocios',
      debugShowCheckedModeBanner: false,
      theme: BarroTheme.data,
      home: pantalla,
    ),
  );
}
