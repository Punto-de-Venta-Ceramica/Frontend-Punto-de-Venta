import '../../domain/descuento.dart';
import '../ports/inbound/gestion_descuentos_use_case.dart';
import '../ports/outbound/descuento_gateway.dart';

class GestionDescuentos implements GestionDescuentosUseCase {
  const GestionDescuentos(this._gateway);
  final DescuentoGateway _gateway;

  void _validarIds(int negocioId, [int? id, int? destinoId]) {
    if (negocioId <= 0 || (id != null && id <= 0)) {
      throw const DescuentoFailure(
        'Selecciona un negocio y descuento válidos.',
      );
    }
    if (destinoId != null && destinoId <= 0) {
      throw const DescuentoFailure('Selecciona un elemento válido.');
    }
  }

  void _validar(DatosDescuento datos) {
    final errores = datos.validar();
    if (errores.isNotEmpty) {
      throw DescuentoFailure(
        'Revisa los campos señalados.',
        fieldErrors: errores,
      );
    }
  }

  @override
  Future<List<Descuento>> listar(int negocioId) {
    _validarIds(negocioId);
    return _gateway.listar(negocioId);
  }

  @override
  Future<Descuento> crear(int negocioId, DatosDescuento datos) {
    _validarIds(negocioId);
    _validar(datos);
    return _gateway.crear(negocioId, datos);
  }

  @override
  Future<Descuento> editar(int negocioId, int id, DatosDescuento datos) {
    _validarIds(negocioId, id);
    _validar(datos);
    return _gateway.editar(negocioId, id, datos);
  }

  @override
  Future<void> eliminar(int negocioId, int id) {
    _validarIds(negocioId, id);
    return _gateway.eliminar(negocioId, id);
  }

  @override
  Future<Descuento> cambiarEstado(
    int negocioId,
    int id, {
    required bool activo,
  }) {
    _validarIds(negocioId, id);
    return _gateway.cambiarEstado(negocioId, id, activo: activo);
  }

  @override
  Future<CatalogoDescuento> catalogo(int negocioId) {
    _validarIds(negocioId);
    return _gateway.catalogo(negocioId);
  }

  @override
  Future<DescuentosDeProducto> delProducto(
    int negocioId,
    int productoId,
  ) async {
    _validarIds(negocioId, productoId);
    final propios = <Descuento>[];
    final compartidos = <Descuento>[];
    for (final d in await _gateway.listar(negocioId)) {
      if (!d.productoIds.contains(productoId)) continue;
      final soloEsteProducto =
          d.productoIds.length == 1 &&
          d.categoriaIds.isEmpty &&
          d.areaIds.isEmpty;
      (soloEsteProducto ? propios : compartidos).add(d);
    }
    return DescuentosDeProducto(propios: propios, compartidos: compartidos);
  }

  @override
  Future<void> guardarDeProducto(
    int negocioId,
    int productoId,
    String nombreProducto,
    List<LineaDescuento> lineas,
    Set<int> eliminar, {
    List<Descuento> compartidos = const [],
  }) async {
    _validarIds(negocioId, productoId);
    // [compartidos] los aporta quien ya los cargó (el formulario), para no
    // volver a pedir la lista de descuentos al guardar.
    final errores = validarLineasDescuento(lineas, compartidos: compartidos);
    if (errores.isNotEmpty) {
      throw const DescuentoFailure('Revisa los descuentos señalados.');
    }
    for (final id in [...eliminar]) {
      await _gateway.eliminar(negocioId, id);
      eliminar.remove(id);
    }
    final maximos = maximosDeLineas(lineas, compartidos: compartidos);
    // El servidor no admite dos descuentos activos del producto con rangos
    // cruzados, ni siquiera de forma momentánea. Los que cambian de rango se
    // desactivan primero; al final cada uno vuelve al estado elegido, ya con
    // rangos que no se cruzan.
    for (final linea in lineas) {
      final actual = linea.original;
      if (actual != null &&
          actual.activo &&
          _cambiaRango(actual, linea, maximos[linea])) {
        linea.original = await _gateway.cambiarEstado(
          negocioId,
          actual.id,
          activo: false,
        );
      }
    }
    for (final linea in lineas) {
      if (linea.original == null) {
        final creado = await _gateway.crear(
          negocioId,
          DatosDescuento(
            nombre: _nombreAutomatico(
              nombreProducto,
              linea.cantidadMinimaNumero!,
            ),
            cantidadMinima: linea.cantidadMinima,
            cantidadMaxima: maximos[linea]?.toString() ?? '',
            porcentaje: linea.porcentaje,
          ),
        );
        linea.original = creado;
      }
      await _sincronizar(negocioId, productoId, linea, maximos[linea]);
    }
  }

  bool _cambiaRango(Descuento actual, LineaDescuento linea, int? maximo) =>
      actual.cantidadMinima != linea.cantidadMinimaNumero ||
      actual.cantidadMaxima != maximo;

  /// Lleva al servidor lo que difiera entre la línea y su última versión conocida.
  Future<void> _sincronizar(
    int negocioId,
    int productoId,
    LineaDescuento linea,
    int? maximo,
  ) async {
    var actual = linea.original!;
    // Si quedará inactivo se desactiva antes que nada: así ni la edición ni la
    // asignación chocan con los demás descuentos activos del producto.
    if (!linea.activo && actual.activo) {
      actual = linea.original = await _gateway.cambiarEstado(
        negocioId,
        actual.id,
        activo: false,
      );
    }
    final cambioDatos =
        _cambiaRango(actual, linea, maximo) ||
        actual.porcentaje != linea.porcentajeNumero;
    if (cambioDatos) {
      actual = linea.original = await _gateway.editar(
        negocioId,
        actual.id,
        DatosDescuento(
          nombre: actual.nombre,
          cantidadMinima: linea.cantidadMinima,
          cantidadMaxima: maximo?.toString() ?? '',
          porcentaje: linea.porcentaje,
        ),
      );
    }
    if (!actual.productoIds.contains(productoId)) {
      actual = linea.original = await _gateway.asignar(
        negocioId,
        actual.id,
        DestinoDescuento.producto,
        productoId,
      );
    }
    if (linea.activo && !actual.activo) {
      linea.original = await _gateway.cambiarEstado(
        negocioId,
        actual.id,
        activo: true,
      );
    }
  }

  String _nombreAutomatico(String producto, int minimo) {
    final nombre = '$producto · desde $minimo piezas';
    return nombre.length <= 120 ? nombre : nombre.substring(0, 120);
  }

  @override
  Future<Descuento> asignar(
    int negocioId,
    int id,
    DestinoDescuento destino,
    int destinoId,
  ) {
    _validarIds(negocioId, id, destinoId);
    return _gateway.asignar(negocioId, id, destino, destinoId);
  }

  @override
  Future<Descuento> quitar(
    int negocioId,
    int id,
    DestinoDescuento destino,
    int destinoId,
  ) {
    _validarIds(negocioId, id, destinoId);
    return _gateway.quitar(negocioId, id, destino, destinoId);
  }
}
