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
    this.vigenciaListado = const Duration(minutes: 5),
    this.vigenciaCatalogo = const Duration(minutes: 10),
    DateTime Function()? ahora,
  }) : _ahora = ahora ?? DateTime.now;

  final DescuentoGateway _origen;
  final Duration vigenciaListado;
  final Duration vigenciaCatalogo;
  final DateTime Function() _ahora;

  final _listados = <int, _Entrada<List<Descuento>>>{};
  final _catalogos = <int, _Entrada<CatalogoDescuento>>{};

  Future<T> _vigenteO<T>(
    Map<int, _Entrada<T>> cache,
    int negocioId,
    Duration vigencia,
    Future<T> Function() cargar,
  ) {
    final entrada = cache[negocioId];
    if (entrada != null && _ahora().difference(entrada.guardado) < vigencia) {
      return entrada.valor;
    }
    final nueva = _Entrada(cargar(), _ahora());
    cache[negocioId] = nueva;
    // Un error no se guarda: el siguiente intento vuelve al servidor.
    nueva.valor.then<void>(
      (_) {},
      onError: (Object _) {
        if (identical(cache[negocioId], nueva)) cache.remove(negocioId);
      },
    );
    return nueva.valor;
  }

  /// Ejecuta un cambio y, si sale bien, descarta la lista del negocio.
  Future<T> _cambio<T>(int negocioId, Future<T> Function() accion) async {
    final resultado = await accion();
    _listados.remove(negocioId);
    return resultado;
  }

  void descartarCatalogo() => _catalogos.clear();

  void descartar() {
    _listados.clear();
    _catalogos.clear();
  }

  @override
  Future<List<Descuento>> listar(int negocioId) => _vigenteO(
    _listados,
    negocioId,
    vigenciaListado,
    () => _origen.listar(negocioId),
  );

  @override
  Future<CatalogoDescuento> catalogo(int negocioId) => _vigenteO(
    _catalogos,
    negocioId,
    vigenciaCatalogo,
    () => _origen.catalogo(negocioId),
  );

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

class _Entrada<T> {
  _Entrada(this.valor, this.guardado);
  final Future<T> valor;
  final DateTime guardado;
}
