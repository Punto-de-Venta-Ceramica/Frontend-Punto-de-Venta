import 'package:punto_de_venta/core/infrastructure/cache/cache_en_memoria.dart';
import '../../../../application/ports/outbound/empleado_gateway.dart';
import '../../../../domain/empleado.dart';

/// Caché en memoria de empleados. Decora el gateway HTTP y la aplicación lo
/// usa como si fuera el original.
///
/// - Listados: [vigencia] (10 min). Solo el propietario los cambia, pero
///   asignar sucursales cambia lo que el empleado puede hacer, por eso es más
///   corta que la de negocios. Registrar, asignar o dar de baja desde esta app
///   descarta los listados del negocio al momento.
/// - Sucursales: pasan directo al gateway de origen, que usa la caché
///   compartida de negocios y sucursales.
class CachedEmpleadoGateway implements EmpleadoGateway {
  CachedEmpleadoGateway(
    this._origen, {
    Duration vigencia = const Duration(minutes: 10),
    DateTime Function()? ahora,
  }) : _listados = CacheEnMemoria(vigencia: vigencia, ahora: ahora);

  final EmpleadoGateway _origen;

  /// Clave: (negocio, incluirAsignacion, sucursal).
  final CacheEnMemoria<(int, bool, int?), List<Empleado>> _listados;

  void _descartarNegocio(int negocioId) =>
      _listados.descartarSi((clave) => clave.$1 == negocioId);

  void descartar() => _listados.limpiar();

  /// Las sucursales del negocio cambiaron (alta, nombre o baja): los listados
  /// muestran las sucursales asignadas de cada empleado, así que se descartan.
  /// Sin [negocioId] se descartan los de todos los negocios.
  void sucursalesCambiaron(int? negocioId) =>
      negocioId == null ? descartar() : _descartarNegocio(negocioId);

  @override
  Future<List<SucursalEmpleado>> sucursales(int negocioId) =>
      _origen.sucursales(negocioId);

  @override
  Future<List<Empleado>> listar(
    int negocioId, {
    bool incluirAsignacion = true,
    int? sucursalId,
  }) => _listados.obtener(
    (negocioId, incluirAsignacion, sucursalId),
    () => _origen.listar(
      negocioId,
      incluirAsignacion: incluirAsignacion,
      sucursalId: sucursalId,
    ),
  );

  @override
  Future<EmpleadoCreado> registrar(NuevoEmpleado datos) async {
    final creado = await _origen.registrar(datos);
    _descartarNegocio(datos.negocioId);
    return creado;
  }

  @override
  Future<Empleado> asignarSucursales({
    required int negocioId,
    required int empleadoId,
    required List<int> sucursalIds,
  }) async {
    final empleado = await _origen.asignarSucursales(
      negocioId: negocioId,
      empleadoId: empleadoId,
      sucursalIds: sucursalIds,
    );
    _descartarNegocio(negocioId);
    return empleado;
  }

  @override
  Future<void> eliminar(int negocioId, int empleadoId) async {
    await _origen.eliminar(negocioId, empleadoId);
    _descartarNegocio(negocioId);
  }
}
