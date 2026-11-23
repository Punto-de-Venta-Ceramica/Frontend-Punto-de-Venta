import 'venta.dart';

class BusquedaProductosVenta {
  BusquedaProductosVenta(String texto) : _texto = texto.trim().toLowerCase();

  final String _texto;

  List<ProductoVenta> filtrar(Iterable<ProductoVenta> productos) {
    if (_texto.isEmpty) return productos.toList();
    final id = int.tryParse(_texto);
    final prefijo =
        id == null &&
            _texto.length >= 2 &&
            !RegExp(r'^[0-9]+$').hasMatch(_texto)
        ? _texto.substring(0, 2)
        : '';
    int prioridad(ProductoVenta producto) {
      final nombre = producto.nombre.toLowerCase();
      if (producto.id == id || nombre == _texto) return 0;
      if (nombre.contains(_texto)) return 1;
      if (prefijo.isNotEmpty && nombre.startsWith(prefijo)) return 2;
      return 3;
    }

    final resultado = productos
        .where((producto) => prioridad(producto) < 3)
        .toList();
    resultado.sort((a, b) {
      final coincidencia = prioridad(a).compareTo(prioridad(b));
      if (coincidencia != 0) return coincidencia;
      final nombre = a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
      return nombre != 0 ? nombre : a.id.compareTo(b.id);
    });
    return resultado;
  }
}
