import 'package:punto_de_venta/core/infrastructure/cache/cache_en_memoria.dart';

import '../../../../application/ports/outbound/descuento_gateway.dart';
import '../../../../domain/descuento.dart';

/// Caché en memoria de descuentos, por negocio. Decora el gateway HTTP y la
/// aplicación lo usa como si fuera el original.
///
/// - Lista de descuentos: [vigenciaListado]. Cualquier cambio hecho desde esta
///   app (crear, editar, eliminar, activar, asignar, quitar) la descarta, así
///   que solo otro dispositivo puede verla atrasada, como mucho esa vigencia.
/// - Catálogo para asignar (productos, categorías, áreas): [vigenciaCatalogo].
///   Es lo más costoso (una petición por área). [descartarCatalogo] lo limpia
///   cuando cambian productos, áreas o categorías.
/// - Las peticiones simultáneas a lo mismo comparten una sola llamada y los
///   errores nunca se guardan.
class CachedDescuentoGateway implements DescuentoGateway {
  CachedDescuentoGateway(
    this._origen, {
    Duration vigenciaListado = const Duration(minutes: 5),
    Duration vigenciaCatalogo = const Duration(minutes: 10),
    DateTime Function()? ahora,
  }) : _listados = CacheEnMemoria(vigencia: vigenciaListado, ahora: ahora),
       _catalogos = CacheEnMemoria(vigencia: vigenciaCatalogo, ahora: ahora);

  final DescuentoGateway _origen;

  final CacheEnMemoria<int, List<Descuento>> _listados;
  final CacheEnMemoria<int, CatalogoDescuento> _catalogos;

  /// Ejecuta un cambio y, si sale bien, descarta la lista del negocio.
  Future<T> _cambio<T>(int negocioId, Future<T> Function() accion) async {
    final resultado = await accion();
    _listados.descartar(negocioId);
    return resultado;
  }

  void descartarCatalogo() => _catalogos.limpiar();

  void descartar() {
    _listados.limpiar();
    _catalogos.limpiar();
  }

  @override
  Future<List<Descuento>> listar(int negocioId) =>
      _listados.obtener(negocioId, () => _origen.listar(negocioId));

  /// Sale de la lista del negocio si está vigente; si no, se piden al servidor
  /// solo los de ese producto.
  @override
  Future<List<Descuento>> deProducto(int negocioId, int productoId) async {
    final lista = _listados.vigente(negocioId);
    if (lista == null) return _origen.deProducto(negocioId, productoId);
    return [
      for (final d in await lista)
        if (d.productoIds.contains(productoId)) d,
    ];
  }

  @override
  Future<List<Descuento>> guardarDeProducto(
    int negocioId,
    int productoId, {
    required List<DescuentoAGuardar> lineas,
    required Set<int> eliminar,
  }) => _cambio(
    negocioId,
    () => _origen.guardarDeProducto(
      negocioId,
      productoId,
      lineas: lineas,
      eliminar: eliminar,
    ),
  );

  @override
  Future<CatalogoDescuento> catalogo(int negocioId) =>
      _catalogos.obtener(negocioId, () => _origen.catalogo(negocioId));

  @override
  Future<Descuento> crear(int negocioId, DatosDescuento datos) =>
      _cambio(negocioId, () => _origen.crear(negocioId, datos));

  @override
  Future<Descuento> editar(int negocioId, int id, DatosDescuento datos) =>
      _cambio(negocioId, () => _origen.editar(negocioId, id, datos));

  @override
  Future<void> eliminar(int negocioId, int id) =>
      _cambio(negocioId, () => _origen.eliminar(negocioId, id));

  @override
  Future<Descuento> cambiarEstado(
    int negocioId,
    int id, {
    required bool activo,
  }) => _cambio(
    negocioId,
    () => _origen.cambiarEstado(negocioId, id, activo: activo),
  );

  @override
  Future<Descuento> asignar(
    int negocioId,
    int id,
    DestinoDescuento destino,
    int destinoId,
  ) => _cambio(
    negocioId,
    () => _origen.asignar(negocioId, id, destino, destinoId),
  );

  @override
  Future<Descuento> quitar(
    int negocioId,
    int id,
    DestinoDescuento destino,
    int destinoId,
  ) => _cambio(
    negocioId,
    () => _origen.quitar(negocioId, id, destino, destinoId),
  );
}
