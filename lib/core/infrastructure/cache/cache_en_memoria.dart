/// Caché en memoria con vigencia, para decorar gateways HTTP.
///
/// - Lo guardado se reutiliza mientras no pase [vigencia].
/// - Las peticiones simultáneas a la misma clave comparten una sola llamada.
/// - Los errores nunca se guardan: el siguiente intento vuelve al servidor.
/// - Como mucho guarda [maximoEntradas]; al pasarse descarta la más antigua.
class CacheEnMemoria<K, T> {
  CacheEnMemoria({
    required this.vigencia,
    this.maximoEntradas = 200,
    DateTime Function()? ahora,
  }) : _ahora = ahora ?? DateTime.now;

  final Duration vigencia;
  final int maximoEntradas;
  final DateTime Function() _ahora;
  final _entradas = <K, _Entrada<T>>{};

  /// Lo guardado si sigue vigente; si no, el resultado de [cargar].
  Future<T> obtener(K clave, Future<T> Function() cargar) {
    final guardada = _entradas[clave];
    if (guardada != null && _ahora().difference(guardada.guardado) < vigencia) {
      return guardada.valor;
    }
    final nueva = _Entrada(cargar(), _ahora());
    _entradas.remove(clave);
    _entradas[clave] = nueva;
    if (_entradas.length > maximoEntradas) {
      _entradas.remove(_entradas.keys.first);
    }
    nueva.valor.then<void>(
      (_) {},
      onError: (Object _) {
        if (identical(_entradas[clave], nueva)) _entradas.remove(clave);
      },
    );
    return nueva.valor;
  }

  void descartar(K clave) => _entradas.remove(clave);

  void descartarSi(bool Function(K clave) condicion) =>
      _entradas.removeWhere((clave, _) => condicion(clave));

  void limpiar() => _entradas.clear();
}

class _Entrada<T> {
  _Entrada(this.valor, this.guardado);
  final Future<T> valor;
  final DateTime guardado;
}
