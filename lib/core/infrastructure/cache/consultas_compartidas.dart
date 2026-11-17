import '../network/api_client.dart';
import 'cache_en_memoria.dart';

/// Consultas de negocios y sucursales que piden varios módulos (negocios,
/// sucursales, productos, empleados y datos contables), en una sola caché.
///
/// Guarda la respuesta JSON tal como llega: cada gateway la convierte a su
/// propio modelo y envuelve los errores ([ApiException]) en los suyos, igual
/// que si hubiera hecho la petición él mismo. Nadie debe modificar el JSON
/// devuelto, porque es el mismo objeto para todos.
///
/// Vigencia: [vigencia] (30 min). Los cambios hechos desde esta app la
/// descartan al momento ([descartarNegocios], [descartarSucursales]); la
/// vigencia solo limita lo atrasado que puede verse un cambio hecho desde
/// otro dispositivo.
class ConsultasCompartidas {
  ConsultasCompartidas(
    this._api, {
    Duration vigencia = const Duration(minutes: 30),
    DateTime Function()? ahora,
  }) : _negocios = CacheEnMemoria(vigencia: vigencia, ahora: ahora),
       _sucursales = CacheEnMemoria(vigencia: vigencia, ahora: ahora);

  final ApiClient _api;
  final CacheEnMemoria<int, Object?> _negocios;
  final CacheEnMemoria<int, Object?> _sucursales;
  final _oyentesSucursales = <void Function(int? negocioId)>[];

  /// Avisa cuando se crea, edita o elimina una sucursal (o se elimina su
  /// negocio) desde esta app, para que otras cachés que guardan datos de
  /// sucursales (p. ej. las asignaciones de empleados) se descarten también.
  /// Recibe el negocio afectado, o null si no se sabe cuál.
  void escucharCambiosSucursales(void Function(int? negocioId) oyente) =>
      _oyentesSucursales.add(oyente);

  /// `GET api/negocios`: negocios del propietario en sesión.
  Future<Object?> negocios() =>
      _negocios.obtener(0, () => _api.requestJson('GET', 'api/negocios'));

  /// `POST api/sucursales/consultar`: sucursales del negocio.
  Future<Object?> sucursales(int negocioId) => _sucursales.obtener(
    negocioId,
    () => _api.requestJson(
      'POST',
      'api/sucursales/consultar',
      body: {'negocioId': negocioId},
    ),
  );

  void descartarNegocios() => _negocios.limpiar();

  /// Sin [negocioId] descarta las sucursales de todos los negocios. Se llama
  /// tras un cambio, así que también avisa a [escucharCambiosSucursales].
  void descartarSucursales([int? negocioId]) {
    negocioId == null
        ? _sucursales.limpiar()
        : _sucursales.descartar(negocioId);
    for (final oyente in _oyentesSucursales) {
      oyente(negocioId);
    }
  }

  /// Al cerrar sesión: lo guardado pertenece al usuario anterior.
  void descartar() {
    _negocios.limpiar();
    _sucursales.limpiar();
  }
}
