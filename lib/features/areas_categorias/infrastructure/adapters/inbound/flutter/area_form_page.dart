import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'widgets/clasificacion_cards.dart';
import 'widgets/clasificacion_scaffold.dart';
import 'widgets/clasificacion_vista.dart';
import 'widgets/clasificacion_widgets.dart';

class AreaFormPage extends StatelessWidget {
  const AreaFormPage({
    required this.negocio,
    this.paso = PasoArea.datos,
    this.editando = false,
    this.nombre = '',
    this.descripcion = '',
    this.errorNombre,
    this.errorDescripcion,
    this.error,
    this.mensaje,
    this.sucursales = const [],
    this.categorias = const [],
    this.pasosDisponibles,
    this.nombreController,
    this.descripcionController,
    this.onNombreChanged,
    this.onDescripcionChanged,
    this.onContinuar,
    this.onCancelar,
    this.onRegistrarCategoria,
    this.onEditarCategoria,
    this.onEliminarCategoria,
    this.mostrarEliminarCategorias = true,
    this.ocupado = false,
    this.accion,
    this.textoCancelar = 'Cancelar',
    super.key,
  });
  final String negocio;
  final PasoArea paso;
  final bool editando;
  final String nombre;
  final String descripcion;
  final String? errorNombre;
  final String? errorDescripcion;
  final String? error;
  final String? mensaje;
  final List<SucursalVista> sucursales;
  final List<CategoriaVista> categorias;
  final List<PasoArea>? pasosDisponibles;
  final TextEditingController? nombreController;
  final TextEditingController? descripcionController;
  final ValueChanged<String>? onNombreChanged;
  final ValueChanged<String>? onDescripcionChanged;
  final VoidCallback? onContinuar;
  final VoidCallback? onCancelar;
  final VoidCallback? onRegistrarCategoria;
  final ValueChanged<int>? onEditarCategoria;
  final ValueChanged<int>? onEliminarCategoria;
  final bool mostrarEliminarCategorias;
  final bool ocupado;
  final String? accion;
  final String textoCancelar;

  @override
  Widget build(BuildContext context) {
    final pasos =
        pasosDisponibles ??
        [
          PasoArea.datos,
          PasoArea.sucursales,
          if (!editando) PasoArea.categorias,
        ];
    return ClasificacionScaffold(
      negocio: negocio,
      volver: 'Áreas',
      onVolver: ocupado ? null : onCancelar,
      footer: ClasificacionPie(
        accion: accion ?? (editando ? 'Guardar cambios' : 'Continuar'),
        onContinuar: onContinuar,
        onCancelar: onCancelar,
        ocupado: ocupado,
        textoCancelar: textoCancelar,
      ),
      children: [
        ClasificacionTitulo(
          editando ? 'Editar área' : 'Registrar área',
          descripcion: editando
              ? 'Actualiza los datos del área.'
              : 'Agrega un área a tu negocio.',
        ),
        if (pasos.length > 1) ...[
          const SizedBox(height: 16),
          ClasificacionPasos(
            paso: paso,
            editando: editando,
            pasosDisponibles: pasos,
          ),
        ],
        const SizedBox(height: 24),
        if (mensaje != null) ...[
          ClasificacionAviso(mensaje!),
          const SizedBox(height: 16),
        ],
        if (error != null) ...[
          ClasificacionAviso(error!, error: true),
          const SizedBox(height: 16),
        ],
        ...switch (paso) {
          PasoArea.datos => [
            ClasificacionCampo(
              etiqueta: 'Nombre del área *',
              hint: 'Ej. Cocina',
              valor: nombre,
              controller: nombreController,
              onChanged: onNombreChanged,
              error: errorNombre,
              enabled: !ocupado,
              maxLength: 100,
            ),
            const SizedBox(height: 20),
            ClasificacionCampo(
              etiqueta: 'Descripción',
              hint: 'Ej. Área enfocada en artículos de…',
              valor: descripcion,
              controller: descripcionController,
              onChanged: onDescripcionChanged,
              error: errorDescripcion,
              enabled: !ocupado,
              multilinea: true,
            ),
          ],
          PasoArea.sucursales => [
            for (var i = 0; i < sucursales.length; i++) ...[
              if (i > 0) const SizedBox(height: 20),
              SucursalClasificacionCard(
                sucursal: sucursales[i],
                unica: sucursales.length == 1,
              ),
            ],
            if (sucursales.length == 1) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: clasificacionSuave,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Este negocio tiene una sola sucursal.\nEl área se asignará a ella automáticamente.',
                  style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
                ),
              ),
            ],
          ],
          PasoArea.categorias => [
            if (categorias.isEmpty)
              ClasificacionEmptyState(
                simbolo: 'C',
                titulo: 'Agrega tu primera categoría',
                descripcion: 'Registra su nombre y descripción.',
                accion: 'Registrar mi primera categoría',
                onAccion: ocupado ? null : onRegistrarCategoria,
              )
            else ...[
              ClasificacionBoton(
                '+ Registrar categoría',
                onPressed: ocupado ? null : onRegistrarCategoria,
              ),
              const SizedBox(height: 20),
              for (var i = 0; i < categorias.length; i++) ...[
                if (i > 0) const SizedBox(height: 16),
                CategoriaCard(
                  categoria: categorias[i],
                  mostrarEliminar: mostrarEliminarCategorias,
                  onEditar:
                      ocupado ||
                          onEditarCategoria == null ||
                          categorias[i].id == null
                      ? null
                      : () => onEditarCategoria!(categorias[i].id!),
                  onEliminar:
                      ocupado ||
                          onEliminarCategoria == null ||
                          categorias[i].id == null
                      ? null
                      : () => onEliminarCategoria!(categorias[i].id!),
                ),
              ],
            ],
          ],
        },
      ],
    );
  }
}
