enum PasoArea { datos, sucursales, categorias }

enum TipoClasificacion { area, categoria }

class AreaVista {
  const AreaVista({
    required this.nombre,
    required this.descripcion,
    this.categorias = 0,
    this.id,
  });
  final String nombre;
  final String descripcion;
  final int categorias;
  final int? id;
}

class CategoriaVista {
  const CategoriaVista({
    required this.nombre,
    required this.descripcion,
    this.id,
  });
  final String nombre;
  final String descripcion;
  final int? id;
}

class SucursalVista {
  const SucursalVista({required this.nombre, this.seleccionada = false});
  final String nombre;
  final bool seleccionada;
}
