import 'package:flutter/material.dart';
import 'core/infrastructure/theme/barro_theme.dart';
import 'features/areas_categorias/infrastructure/adapters/inbound/flutter/area_detalle_page.dart';
import 'features/areas_categorias/infrastructure/adapters/inbound/flutter/area_form_page.dart';
import 'features/areas_categorias/infrastructure/adapters/inbound/flutter/areas_page.dart';
import 'features/areas_categorias/infrastructure/adapters/inbound/flutter/categoria_form_page.dart';
import 'features/areas_categorias/infrastructure/adapters/inbound/flutter/widgets/acceso_areas_categorias.dart';
import 'features/areas_categorias/infrastructure/adapters/inbound/flutter/widgets/clasificacion_scaffold.dart';
import 'features/areas_categorias/infrastructure/adapters/inbound/flutter/widgets/clasificacion_vista.dart';
import 'features/areas_categorias/infrastructure/adapters/inbound/flutter/widgets/clasificacion_widgets.dart';
import 'features/areas_categorias/infrastructure/adapters/inbound/flutter/widgets/confirmar_eliminar_clasificacion_dialog.dart';

const _negocio = 'Cerámica del Centro';
const _area = AreaVista(
  nombre: 'Baño',
  descripcion: 'Área enfocada a artículos para baño.',
  categorias: 2,
);
const _areas = [
  AreaVista(
    nombre: 'Jardinería',
    descripcion: 'Área enfocada en artículos para jardinería.',
    categorias: 2,
  ),
  AreaVista(
    nombre: 'Cocina',
    descripcion: 'Área enfocada en artículos para cocina.',
    categorias: 3,
  ),
];
const _categorias = [
  CategoriaVista(
    nombre: 'Jabonero',
    descripcion: 'Categoría enfocada a artículos de tipo jabonero.',
  ),
  CategoriaVista(
    nombre: 'Porta Jabones',
    descripcion: 'Categoría enfocada a artículos de tipo porta jabones.',
  ),
];
const _sucursales = [
  SucursalVista(nombre: 'Sucursal Centro', seleccionada: true),
  SucursalVista(nombre: 'Sucursal Norte', seleccionada: true),
  SucursalVista(nombre: 'Sucursal Mercado'),
];

/// Escenarios de diseño aislados: todos los datos son ejemplos de presentación.
void main() {
  final estado =
      Uri.base.queryParameters['estado'] ??
      const String.fromEnvironment(
        'AREAS_CATEGORIAS_PREVIEW',
        defaultValue: 'lista',
      );
  final pantalla = switch (estado) {
    'inicio' => const _InicioNegocioPreview(),
    'vacio' => const AreasPage(negocio: _negocio),
    'lista' => const AreasPage(negocio: _negocio, areas: _areas),
    'registrar' => const AreaFormPage(negocio: _negocio),
    'registro_validacion' => const AreaFormPage(
      negocio: _negocio,
      errorNombre: 'Escribe el nombre del área.',
    ),
    'sucursal_unica' => const AreaFormPage(
      negocio: _negocio,
      paso: PasoArea.sucursales,
      sucursales: [
        SucursalVista(nombre: 'Sucursal Centro', seleccionada: true),
      ],
    ),
    'sucursales' => const AreaFormPage(
      negocio: _negocio,
      paso: PasoArea.sucursales,
      sucursales: _sucursales,
    ),
    'categorias_vacias' => const AreaFormPage(
      negocio: _negocio,
      paso: PasoArea.categorias,
    ),
    'categorias' => const AreaFormPage(
      negocio: _negocio,
      paso: PasoArea.categorias,
      categorias: _categorias,
    ),
    'registrar_categoria' => const CategoriaFormPage(negocio: _negocio),
    'categoria_validacion' => const CategoriaFormPage(
      negocio: _negocio,
      errorNombre: 'Escribe el nombre de la categoría.',
    ),
    'editar_datos' => const AreaFormPage(
      negocio: _negocio,
      editando: true,
      nombre: 'Baño',
      descripcion: 'Área enfocada a artículos para baño.',
    ),
    'editar_sucursales' => const AreaFormPage(
      negocio: _negocio,
      editando: true,
      paso: PasoArea.sucursales,
      sucursales: _sucursales,
    ),
    'editar_categoria' => const CategoriaFormPage(
      negocio: _negocio,
      editando: true,
      nombre: 'Jabonero',
      descripcion: 'Categoría enfocada a artículos de tipo jabonero.',
    ),
    'detalle' => const AreaDetallePage(
      negocio: _negocio,
      area: _area,
      categorias: _categorias,
    ),
    'area_guardada' => const AreaDetallePage(
      negocio: _negocio,
      area: _area,
      categorias: _categorias,
      mensaje: 'Área guardada correctamente.',
    ),
    'area_editada' => const AreaDetallePage(
      negocio: _negocio,
      area: _area,
      categorias: _categorias,
      mensaje: 'Área editada correctamente.',
    ),
    'categoria_guardada' => const AreaDetallePage(
      negocio: _negocio,
      area: _area,
      categorias: _categorias,
      mensaje: 'Categoría guardada correctamente.',
    ),
    'categoria_editada' => const AreaDetallePage(
      negocio: _negocio,
      area: _area,
      categorias: _categorias,
      mensaje: 'Categoría editada correctamente.',
    ),
    'categoria_eliminada' => const AreaDetallePage(
      negocio: _negocio,
      area: _area,
      categorias: [
        CategoriaVista(
          nombre: 'Porta Jabones',
          descripcion: 'Categoría enfocada a artículos de tipo porta jabones.',
        ),
      ],
      mensaje: 'Categoría eliminada correctamente.',
    ),
    'area_eliminada' => const AreasPage(
      negocio: _negocio,
      areas: _areas,
      mensaje: 'Área eliminada correctamente.',
    ),
    'confirmar_area' => const _ConfirmacionPreview(
      tipo: TipoClasificacion.area,
    ),
    'confirmar_categoria' => const _ConfirmacionPreview(
      tipo: TipoClasificacion.categoria,
    ),
    _ => const AreasPage(negocio: _negocio, areas: _areas),
  };
  runApp(
    MaterialApp(
      title: 'BarroControl · Áreas y categorías',
      debugShowCheckedModeBanner: false,
      theme: BarroTheme.data,
      home: pantalla,
    ),
  );
}

class _ConfirmacionPreview extends StatelessWidget {
  const _ConfirmacionPreview({required this.tipo});
  final TipoClasificacion tipo;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const AreaDetallePage(
        negocio: _negocio,
        area: _area,
        categorias: _categorias,
      ),
      const Positioned.fill(
        child: ModalBarrier(dismissible: false, color: Color(0x66000000)),
      ),
      Center(
        child: ConfirmarEliminarClasificacionDialog(
          tipo: tipo,
          nombre: tipo == TipoClasificacion.area ? 'Baño' : 'Jabonero',
          negocio: _negocio,
        ),
      ),
    ],
  );
}

class _InicioNegocioPreview extends StatelessWidget {
  const _InicioNegocioPreview();
  @override
  Widget build(BuildContext context) => ClasificacionScaffold(
    negocio: _negocio,
    mostrarNavegacion: true,
    children: [
      Text(
        'Catálogo del negocio',
        style: BarroTheme.type(
          13,
          20,
          weight: FontWeight.w600,
          color: BarroTheme.secondary,
        ),
      ),
      const SizedBox(height: 8),
      const AccesoAreasCategorias(),
      const SizedBox(height: 28),
      const ClasificacionTitulo(
        'Sucursales',
        descripcion: 'Administra las sucursales de tu negocio.',
      ),
      const SizedBox(height: 20),
      const ClasificacionBoton('+ Registrar sucursal'),
      const SizedBox(height: 24),
      for (final nombre in ['Sucursal Centro', 'Sucursal Norte']) ...[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: clasificacionBorde),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombre,
                style: BarroTheme.type(18, 25, weight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Sucursal de este negocio',
                style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ClasificacionEnlace(texto: 'Administrar'),
                  ClasificacionEnlace(texto: 'Editar'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    ],
  );
}
