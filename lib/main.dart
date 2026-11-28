import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:material_ui/material_ui.dart'
    as mui
    show GlobalMaterialLocalizations;
import 'package:http/http.dart' as http;
import 'package:toastification/toastification.dart';
import 'package:punto_de_venta/core/infrastructure/services/notificacion_servicio.dart';
import 'core/infrastructure/cache/consultas_compartidas.dart';
import 'core/infrastructure/widgets/barro_header.dart';
import 'features/areas_categorias/infrastructure/adapters/outbound/cache/cached_catalogo_gateway.dart';
import 'features/corte_caja/infrastructure/adapters/outbound/cache/cached_corte_caja_gateway.dart';
import 'features/empleados/infrastructure/adapters/outbound/cache/cached_empleado_gateway.dart';
import 'features/pedidos/infrastructure/adapters/outbound/pedidos_con_memoria.dart';
import 'features/authentication/infrastructure/adapters/inbound/flutter/perfil_usuario_page.dart';
import 'features/authentication/application/services/authentication_services.dart';
import 'features/authentication/domain/auth_session.dart';
import 'features/authentication/infrastructure/adapters/outbound/http/http_authentication_gateway.dart';
import 'features/authentication/infrastructure/adapters/inbound/flutter/session_page.dart';
import 'features/authentication/application/ports/outbound/session_store.dart';
import 'features/authentication/infrastructure/adapters/outbound/storage/secure_session_store.dart';
import 'features/sucursal/application/services/gestion_sucursales.dart';
import 'features/sucursal/infrastructure/adapters/outbound/http/http_sucursal_gateway.dart';
import 'features/sucursal/infrastructure/adapters/inbound/flutter/administrar_sucursal_page.dart';
import 'features/sucursal/infrastructure/adapters/inbound/flutter/sucursales_page.dart';
import 'features/sucursal/domain/sucursal.dart';
import 'features/descuentos/application/services/gestion_descuentos.dart';
import 'features/descuentos/infrastructure/adapters/inbound/flutter/descuentos_page.dart';
import 'features/descuentos/infrastructure/adapters/outbound/http/http_descuento_gateway.dart';
import 'features/descuentos/infrastructure/adapters/outbound/cache/cached_descuento_gateway.dart';
import 'features/productos/application/services/gestion_productos.dart';
import 'features/productos/application/services/imagenes_producto.dart';
import 'features/productos/domain/producto.dart';
import 'features/productos/infrastructure/adapters/inbound/flutter/productos_page.dart';
import 'features/productos/infrastructure/adapters/outbound/cache/cache_productos.dart';
import 'features/productos/infrastructure/adapters/outbound/http/http_existencias_gateway.dart';
import 'features/productos/infrastructure/adapters/outbound/http/http_producto_gateway.dart';
import 'features/productos/infrastructure/imagenes_producto.dart';
import 'features/pedidos/application/gestion_pedidos.dart';
import 'features/pedidos/infrastructure/adapters/outbound/http_pedidos_gateway.dart';
import 'features/pedidos/infrastructure/adapters/inbound/pedidos_page.dart';
import 'features/pedidos/infrastructure/adapters/inbound/pedidos_negocio_page.dart';
import 'features/pedidos/infrastructure/adapters/inbound/notificaciones_page.dart';
import 'features/notificaciones/application/contador_notificaciones.dart';
import 'features/notificaciones/infrastructure/indicador_icono_movil.dart';
import 'features/negocios/application/services/gestion_negocios.dart';
import 'features/negocios/domain/negocio.dart';
import 'features/negocios/infrastructure/adapters/inbound/flutter/negocios_page.dart';
import 'features/negocios/infrastructure/adapters/outbound/http/http_negocio_gateway.dart';
import 'features/negocios/infrastructure/adapters/outbound/files/file_selector_logo.dart';
import 'features/areas_categorias/application/services/gestion_catalogo.dart';
import 'features/areas_categorias/domain/catalogo.dart';
import 'features/areas_categorias/infrastructure/adapters/inbound/flutter/catalogo_page.dart';
import 'features/areas_categorias/infrastructure/adapters/outbound/http/http_catalogo_gateway.dart';
import 'features/empleados/application/services/gestion_empleados.dart';
import 'features/empleados/domain/empleado.dart';
import 'features/empleados/infrastructure/adapters/inbound/flutter/empleados_page.dart';
import 'features/empleados/infrastructure/adapters/outbound/http/http_empleado_gateway.dart';
import 'features/corte_caja/application/services/gestion_corte_caja.dart';
import 'features/corte_caja/infrastructure/adapters/outbound/http/http_corte_caja_gateway.dart';
import 'features/corte_caja/infrastructure/adapters/inbound/flutter/corte_caja_page.dart';
import 'features/ventas/application/services/gestion_ventas.dart';
import 'features/ventas/domain/venta.dart';
import 'features/ventas/infrastructure/adapters/inbound/flutter/registrar_venta_page.dart';
import 'features/ventas/infrastructure/adapters/inbound/flutter/ventas_widgets.dart';
import 'features/ventas/infrastructure/adapters/outbound/http/http_ventas_gateway.dart';
import 'features/reportes/application/services/gestion_reportes.dart';
import 'features/reportes/infrastructure/adapters/inbound/flutter/datos_contables_page.dart';
import 'features/reportes/infrastructure/adapters/outbound/files/exportador_xlsx.dart';
import 'features/reportes/infrastructure/adapters/outbound/http/http_reportes_gateway.dart';

import 'features/empleados/domain/sucursal_asignada.dart';
import 'features/empleados/infrastructure/adapters/inbound/flutter/empleado_inicio_page.dart';

import 'core/infrastructure/config/api_config.dart';
import 'core/infrastructure/network/api_client.dart';
import 'core/infrastructure/theme/barro_theme.dart';
import 'features/login/application/services/validate_login.dart';
import 'features/login/infrastructure/adapters/inbound/flutter/login_page.dart';
import 'features/owner_registration/application/services/validate_owner_registration.dart';
import 'features/owner_registration/infrastructure/adapters/inbound/flutter/owner_registration_page.dart';
import 'features/connection/application/services/check_connection.dart';
import 'features/connection/infrastructure/adapters/outbound/http/http_health_gateway.dart';
import 'features/connection/infrastructure/adapters/inbound/flutter/connection_page.dart';

void main() => runApp(const PuntoDeVentaApp());

class PuntoDeVentaApp extends StatefulWidget {
  const PuntoDeVentaApp({
    this.initialRoute = '/',
    this.httpClient,
    this.sessionStore = const SecureSessionStore(),
    super.key,
  });
  final String initialRoute;
  final http.Client? httpClient;

  /// Dónde se guarda la sesión para que sobreviva al cierre de la app.
  final SessionStore sessionStore;

  @override
  State<PuntoDeVentaApp> createState() => _PuntoDeVentaAppState();
}

class _PuntoDeVentaAppState extends State<PuntoDeVentaApp> {
  late final ApiClient _api;
  late final HttpAuthenticationGateway _authentication;
  late final ImagenesProducto _imagenesProducto;
  late final ContadorNotificaciones _contador;
  late final CacheProductos _productos;

  /// Negocios y sucursales, compartidos por todos los módulos: 30 min.
  late final ConsultasCompartidas _compartidas;

  /// Áreas y categorías (módulo de clasificación): 30 min.
  late final CachedCatalogoGateway _catalogo;

  /// Empleados: 10 min.
  late final CachedEmpleadoGateway _empleados;

  /// Pedidos: siempre se consultan; lo último recibido se muestra mientras.
  late final PedidosConMemoria _pedidos;

  /// Detalle de cortes cerrados: toda la sesión.
  late final CachedCorteCajaGateway _cortes;

  /// Descuentos del propietario: lista 5 min, catálogo para asignar 10 min.
  late final CachedDescuentoGateway _descuentos;

  /// Ventas: artículo artesanal (toda la sesión) y categorías del filtro (30 min) por sucursal.
  late final GestionVentas _ventas;

  /// Caché del empleado por sucursal (mismas vigencias que la del propietario:
  /// listado 5 min, áreas/categorías 30 min). Usa gateways con alcance de
  /// sucursal, por eso no comparte la del propietario.
  final _productosEmpleado = <int, CacheProductos>{};
  final _revisionInventarioEmpleado = ValueNotifier<int>(0);

  CacheProductos _cacheEmpleado(SucursalAsignada s) =>
      _productosEmpleado.putIfAbsent(
        s.sucursalId,
        () => CacheProductos(
          HttpProductoGateway(_api, sucursalEmpleado: s.sucursalId),
          HttpExistenciasGateway(
            _api,
            alcanceEmpleado: (s.negocioId, s.sucursalId),
          ),
        ),
      );
  String _rol = '';
  final ValueNotifier<int> _sesionExpirada = ValueNotifier(0);
  AuthSession? _sesionActual;
  @override
  void initState() {
    super.initState();
    _api = ApiClient(baseUrl: ApiConfig.baseUrl, client: widget.httpClient)
      ..onSessionExpired = () {
        _sesionExpirada.value++;
      }
      ..onSessionRenewed =
          ({
            required token,
            required expiresAt,
            required refreshToken,
            required refreshExpiresAt,
          }) {
            final actual = _sesionActual;
            if (actual == null) return;
            // Solo se persiste: _sesionActual se conserva para que la ruta no
            // reinstale los tokens del inicio de sesión.
            widget.sessionStore.guardar(
              AuthSession(
                token: token,
                expiresAt: expiresAt,
                refreshToken: refreshToken,
                refreshExpiresAt: refreshExpiresAt,
                userId: actual.userId,
                role: actual.role,
              ),
            );
          };
    _authentication = HttpAuthenticationGateway(_api);
    _imagenesProducto = crearImagenesProducto();
    _contador = ContadorNotificaciones(_api, IndicadorIconoMovil());
    _compartidas = ConsultasCompartidas(_api);
    _productos = CacheProductos(
      HttpProductoGateway(_api, compartidas: _compartidas),
      HttpExistenciasGateway(_api),
    );
    _catalogo = CachedCatalogoGateway(HttpCatalogoGateway(_api));
    _empleados = CachedEmpleadoGateway(
      HttpEmpleadoGateway(_api, compartidas: _compartidas),
    );
    // Los listados de empleados muestran sus sucursales asignadas: dar de
    // baja o renombrar una sucursal los deja atrasados.
    _compartidas.escucharCambiosSucursales(_empleados.sucursalesCambiaron);
    _pedidos = PedidosConMemoria(HttpPedidosGateway(_api));
    _cortes = CachedCorteCajaGateway(HttpCorteCajaGateway(_api));
    _descuentos = CachedDescuentoGateway(HttpDescuentoGateway(_api));
    _ventas = GestionVentas(HttpVentasGateway(_api));
    // Las categorías del filtro de ventas dependen de las áreas de la sucursal.
    _compartidas.escucharCambiosSucursales((_) => _ventas.descartar());
    BarroHeader.accionPerfilGlobal = (ctx) => Navigator.of(ctx).push(
      PerfilUsuarioPage.route(
        api: _api,
        gateway: _authentication,
        onCerrarSesion: () => _cerrarSesion(ctx),
      ),
    );
  }

  GestionProductos get _gestionProductos => GestionProductos(
    _productos.productos,
    _productos.existencias,
    cache: _productos,
    // Deslizar para actualizar también vuelve a pedir negocios y sucursales.
    alDescartarCache: _compartidas.descartar,
  );

  GestionPedidos get _gestionPedidos =>
      GestionPedidos(_pedidos, memoria: _pedidos);

  GestionSucursales get _gestionSucursales =>
      GestionSucursales(HttpSucursalGateway(_api, compartidas: _compartidas));

  /// Al cerrar sesión: todo lo guardado pertenece al usuario anterior.
  void _descartarCaches() {
    _compartidas.descartar();
    _productos.descartar();
    _descuentos.descartar();
    _catalogo.descartar();
    _empleados.descartar();
    _pedidos.descartar();
    _cortes.descartar();
    _ventas.descartar();
    _productosEmpleado.clear();
  }

  @override
  void dispose() {
    _contador.dispose();
    _sesionExpirada.dispose();
    _revisionInventarioEmpleado.dispose();
    _api.close();
    super.dispose();
  }

  Widget _login(BuildContext context) => LoginPage(
    validateLogin: const ValidateLogin(),
    signIn: SignIn(_authentication),
    gateway: _authentication,
    initialEmail: ModalRoute.of(context)?.settings.arguments is String
        ? ModalRoute.of(context)!.settings.arguments as String
        : '',
  );

  void _cerrarSesion(BuildContext context) {
    widget.sessionStore.borrar();
    _api.cerrarSesion();
    _sesionActual = null;
    _contador.cerrarSesion();
    _descartarCaches();
    _rol = '';
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  Future<void> _abrirSucursales(
    BuildContext context,
    Negocio negocio, {
    bool registrar = false,
  }) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => SucursalesPage(
        gestion: _gestionSucursales,
        negocioInicial: NegocioSucursal(id: negocio.id, nombre: negocio.nombre),
        registrarAlAbrir: registrar,
        onSesionExpirada: () => _cerrarSesion(context),
        onAreasCategorias: (negocio) => _abrirCatalogo(context, negocio),
        onProductos: (negocio) => _abrirProductosNegocio(context, negocio),
        onDescuentos: (negocio) => _abrirDescuentosNegocio(context, negocio),
        onEmpleados: (negocio) => _abrirEmpleadosNegocio(context, negocio),
        onDatosContables: (negocio) => _abrirDatosContables(context, negocio),
        onPedidos: (negocio) => _abrirPedidosNegocio(context, negocio),
        onAdministrar: (negocio, sucursal) =>
            _abrirAdministracion(context, negocio, sucursal),
      ),
    ),
  );

  Future<void> _abrirDatosContables(
    BuildContext context,
    NegocioSucursal negocio, {
    int? sucursalInicialId,
  }) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (reportesContext) => DatosContablesPage(
        negocio: negocio,
        sucursalInicialId: sucursalInicialId,
        sucursales: _gestionSucursales,
        reportes: GestionReportes(
          HttpReportesGateway(_api),
          const ExportadorXlsx(),
        ),
        onSesionExpirada: () => _cerrarSesion(reportesContext),
      ),
    ),
  );

  Future<void> _abrirCatalogo(BuildContext context, NegocioSucursal negocio) =>
      Navigator.of(context)
          .push<void>(
            MaterialPageRoute(
              builder: (_) => CatalogoPage(
                negocio: NegocioCatalogo(
                  id: negocio.id,
                  nombre: negocio.nombre,
                ),
                gestion: GestionCatalogo(_catalogo),
                onSesionExpirada: () => _cerrarSesion(context),
              ),
            ),
          )
          .whenComplete(() {
            _productos.descartar();
            _ventas.descartar(); // Categorías del filtro de ventas.
          });

  Future<void> _abrirAdministracion(
    BuildContext context,
    NegocioSucursal negocio,
    Sucursal sucursal,
  ) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (administrarContext) => AdministrarSucursalPage(
        sucursal: sucursal,
        onProductos: () =>
            _abrirProductos(administrarContext, negocio, sucursal),
        onInventario: () =>
            _abrirProductos(administrarContext, negocio, sucursal),
        onPedidos: () => _abrirPedidos(administrarContext, negocio, sucursal),
        onEmpleados: () =>
            _abrirEmpleados(administrarContext, negocio, sucursal),
        onCorteCaja: () =>
            _abrirCorteCaja(administrarContext, negocio, sucursal),
        onDatosContables: () => _abrirDatosContables(
          administrarContext,
          negocio,
          sucursalInicialId: sucursal.id,
        ),
      ),
    ),
  );

  /// Empleados de todo el negocio: asignación a varias sucursales y baja.
  Future<void> _abrirEmpleadosNegocio(
    BuildContext context,
    NegocioSucursal negocio,
  ) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (empleadosContext) => EmpleadosPage(
        gestion: GestionEmpleados(_empleados),
        negocioInicial: NegocioEmpleado(id: negocio.id, nombre: negocio.nombre),
        onSesionExpirada: () => _cerrarSesion(empleadosContext),
      ),
    ),
  );

  Future<void> _abrirCorteCaja(
    BuildContext context,
    NegocioSucursal negocio,
    Sucursal sucursal, {
    bool reemplazar = false,
  }) {
    final ruta = MaterialPageRoute<void>(
      builder: (cajaContext) => CorteCajaPage(
        gestion: GestionCorteCaja(_cortes),
        sucursalId: sucursal.id,
        sucursalNombre: sucursal.nombre,
        negocioNombre: negocio.nombre,
        usuarioNombre: _sesionActual?.role ?? 'Propietario',
        esPropietario: true,
        onSesionExpirada: () => _cerrarSesion(context),
        onRegistrarVenta: (context) => _abrirRegistroVenta(
          context,
          sucursalId: sucursal.id,
          sucursal: sucursal.nombre,
          negocio: negocio.nombre,
          rol: 'Propietario',
        ),
        onInicio: () => Navigator.of(cajaContext).popUntil((r) => r.isFirst),
        onPedidos: () =>
            _abrirPedidos(cajaContext, negocio, sucursal, reemplazar: true),
        onInventario: () =>
            _abrirProductos(cajaContext, negocio, sucursal, reemplazar: true),
        onDatosContables: () => _abrirDatosContables(
          cajaContext,
          negocio,
          sucursalInicialId: sucursal.id,
        ),
      ),
    );
    final navigator = Navigator.of(context);
    return reemplazar ? navigator.pushReplacement(ruta) : navigator.push(ruta);
  }

  Future<bool> _abrirRegistroVenta(
    BuildContext context, {
    required int sucursalId,
    required String sucursal,
    required String negocio,
    required String rol,
  }) async {
    final venta = await Navigator.of(context).push<VentaRegistrada>(
      MaterialPageRoute(
        builder: (ventasContext) => RegistrarVentaPage(
          gestion: _ventas,
          sucursalId: sucursalId,
          contexto: VentaContexto(
            negocio: negocio,
            sucursal: sucursal,
            rol: rol,
          ),
          onSesionExpirada: () => _cerrarSesion(ventasContext),
        ),
      ),
    );
    if (venta == null || !mounted) return false;
    _productos.descartarSalvoCatalogos();
    _productosEmpleado[sucursalId]?.descartarSalvoCatalogos();
    _revisionInventarioEmpleado.value++;
    if (context.mounted) {
      final cambio = venta.cambio;
      final mensaje =
          'Venta ${venta.folio} registrada por ${dineroVenta(venta.total)}.';
      NotificacionServicio.exito(
        context,
        cambio == null ? mensaje : '$mensaje Cambio: ${dineroVenta(cambio)}.',
      );
    }
    return true;
  }

  Future<void> _abrirEmpleados(
    BuildContext context,
    NegocioSucursal negocio,
    Sucursal sucursal,
  ) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (empleadosContext) => EmpleadosPage(
        onPedidos: () => _abrirPedidos(
          empleadosContext,
          negocio,
          sucursal,
          reemplazar: true,
        ),
        onInventario: () => _abrirProductos(
          empleadosContext,
          negocio,
          sucursal,
          reemplazar: true,
        ),
        onCaja: () => _abrirCorteCaja(
          empleadosContext,
          negocio,
          sucursal,
          reemplazar: true,
        ),
        gestion: GestionEmpleados(_empleados),
        negocioInicial: NegocioEmpleado(id: negocio.id, nombre: negocio.nombre),
        sucursalNombre: sucursal.nombre,
        sucursalId: sucursal.id,
        onSesionExpirada: () => _cerrarSesion(empleadosContext),
      ),
    ),
  );

  /// Descuentos del negocio (no dependen de una sucursal).
  Future<void> _abrirDescuentosNegocio(
    BuildContext context,
    NegocioSucursal negocio,
  ) {
    // Productos, áreas o categorías pueden haber cambiado en otros módulos:
    // al entrar se pide fresco y dentro del módulo se reutiliza.
    _descuentos.descartarCatalogo();
    return Navigator.of(context)
        .push<void>(
          MaterialPageRoute(
            builder: (descuentosContext) => DescuentosPage(
              gestion: GestionDescuentos(_descuentos),
              negocio: NegocioProducto(id: negocio.id, nombre: negocio.nombre),
              onSesionExpirada: () => _cerrarSesion(descuentosContext),
            ),
          ),
        )
        .whenComplete(_productos.descartarSalvoCatalogos);
  }

  /// Catálogo de productos del negocio completo: todas las sucursales.
  Future<void> _abrirProductosNegocio(
    BuildContext context,
    NegocioSucursal negocio,
  ) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (productosContext) => ProductosPage(
        gestion: _gestionProductos,
        descuentos: GestionDescuentos(_descuentos),
        imagenes: _imagenesProducto,
        negocioInicial: NegocioProducto(id: negocio.id, nombre: negocio.nombre),
        onSesionExpirada: () => _cerrarSesion(productosContext),
      ),
    ),
  );

  /// Con [reemplazar] sustituye la pantalla actual (navegación entre módulos
  /// de la misma sucursal) para que "Inicio" siempre regrese a Administrar.
  Future<void> _abrirProductos(
    BuildContext context,
    NegocioSucursal negocio,
    Sucursal sucursal, {
    bool reemplazar = false,
  }) {
    final ruta = MaterialPageRoute<void>(
      builder: (productosContext) => ProductosPage(
        gestion: _gestionProductos,
        descuentos: GestionDescuentos(_descuentos),
        imagenes: _imagenesProducto,
        negocioInicial: NegocioProducto(id: negocio.id, nombre: negocio.nombre),
        onSesionExpirada: () => _cerrarSesion(productosContext),
        sucursal: SucursalProducto(id: sucursal.id, nombre: sucursal.nombre),
        onPedidos: () => _abrirPedidos(
          productosContext,
          negocio,
          sucursal,
          reemplazar: true,
        ),
        onCaja: () => _abrirCorteCaja(
          productosContext,
          negocio,
          sucursal,
          reemplazar: true,
        ),
        onDatosContables: () => _abrirDatosContables(
          productosContext,
          negocio,
          sucursalInicialId: sucursal.id,
        ),
      ),
    );
    final navigator = Navigator.of(context);
    return reemplazar ? navigator.pushReplacement(ruta) : navigator.push(ruta);
  }

  /// Pedidos desde el negocio: la sucursal se elige en la misma pantalla.
  Future<void> _abrirPedidosNegocio(
    BuildContext context,
    NegocioSucursal negocio,
  ) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (pedidosContext) => PedidosNegocioPage(
        negocio: negocio,
        sucursales: _gestionSucursales,
        gestion: _gestionPedidos,
        contador: _contador,
        onSesionExpirada: () => _cerrarSesion(pedidosContext),
      ),
    ),
  );

  Future<void> _abrirPedidos(
    BuildContext context,
    NegocioSucursal negocio,
    Sucursal sucursal, {
    bool reemplazar = false,
  }) {
    final ruta = MaterialPageRoute<void>(
      builder: (pedidosContext) => PedidosPage(
        gestion: _gestionPedidos,
        sucursalId: sucursal.id,
        sucursalNombre: sucursal.nombre,
        negocio: NegocioProducto(id: negocio.id, nombre: negocio.nombre),
        esPropietario: _rol == 'PROPIETARIO',
        contador: _contador,
        onInventario: () => _abrirProductos(
          pedidosContext,
          negocio,
          sucursal,
          reemplazar: true,
        ),
        onCaja: () => _abrirCorteCaja(
          pedidosContext,
          negocio,
          sucursal,
          reemplazar: true,
        ),
        onDatosContables: () => _abrirDatosContables(
          pedidosContext,
          negocio,
          sucursalInicialId: sucursal.id,
        ),
      ),
    );
    final navigator = Navigator.of(context);
    return reemplazar ? navigator.pushReplacement(ruta) : navigator.push(ruta);
  }

  /// Inicio del empleado: Pedidos, Caja (por defecto) e Inventario de su sucursal.
  Widget _inicioEmpleado(BuildContext context) => EmpleadoInicioPage(
    cargarSucursales: () async {
      final respuesta = await _api.requestJson(
        'GET',
        'api/pedidos/opciones/sucursales-asignadas',
      );
      if (respuesta is! List) throw const FormatException();
      return [
        for (final item in respuesta.whereType<Map<String, dynamic>>())
          SucursalAsignada.fromJson(item),
      ];
    },
    construirPedidos: (s) => PedidosPage(
      gestion: _gestionPedidos,
      sucursalId: s.sucursalId,
      sucursalNombre: s.sucursal,
      negocio: NegocioProducto(id: s.negocioId, nombre: s.negocio),
      esPropietario: false,
      contador: _contador,
    ),
    construirCaja: (s) => CorteCajaPage(
      gestion: GestionCorteCaja(_cortes),
      sucursalId: s.sucursalId,
      sucursalNombre: s.sucursal,
      negocioNombre: s.negocio,
      usuarioNombre: _sesionActual?.role ?? 'Empleado',
      esPropietario: false,
      onSesionExpirada: () => _cerrarSesion(context),
      onRegistrarVenta: (context) => _abrirRegistroVenta(
        context,
        sucursalId: s.sucursalId,
        sucursal: s.sucursal,
        negocio: s.negocio,
        rol: 'Empleado',
      ),
    ),
    // Mismo listado y detalle que el propietario, en solo lectura: el
    // empleado consulta existencias de su sucursal y puede registrar productos
    // (ajustarlas es solo del propietario, HU-05).
    construirInventario: (s) => ValueListenableBuilder<int>(
      valueListenable: _revisionInventarioEmpleado,
      builder: (_, revision, _) {
        final cache = _cacheEmpleado(s);
        return ProductosPage(
          key: ValueKey(revision),
          gestion: GestionProductos(
            cache.productos,
            cache.existencias,
            cache: cache,
          ),
          negocioInicial: NegocioProducto(id: s.negocioId, nombre: s.negocio),
          sucursal: SucursalProducto(id: s.sucursalId, nombre: s.sucursal),
          soloLectura: true,
          puedeRegistrar: true,
          imagenes: _imagenesProducto,
          onSesionExpirada: () => _cerrarSesion(context),
        );
      },
    ),
    onCerrarSesion: () => _cerrarSesion(context),
    conteoNotificaciones: _contador,
    onNotificaciones: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificacionesPage(
          gestion: _gestionPedidos,
          contador: _contador,
          esPropietario: _rol == 'PROPIETARIO',
        ),
      ),
    ),
  );

  final _navegador = GlobalKey<NavigatorState>();

  /// Campana de la cabecera en todas las pantallas: el scope va sobre el
  /// Navigator, así las rutas nuevas (sucursales, caja, áreas…) también lo ven.
  void _abrirNotificacionesGlobal() {
    if (_sesionActual == null) return;
    _navegador.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => NotificacionesPage(
          gestion: _gestionPedidos,
          contador: _contador,
          esPropietario: _rol == 'PROPIETARIO',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ToastificationWrapper(
    child: MaterialApp(
      navigatorKey: _navegador,
      builder: (context, child) => BarroHeaderScope(
        onNotificaciones: _abrirNotificacionesGlobal,
        conteoNotificaciones: _contador,
        child: child ?? const SizedBox.shrink(),
      ),
      title: 'BarroControl',
      debugShowCheckedModeBanner: false,
      // Todo en español (México): calendario, menús de texto y accesibilidad.
      // `dropdown_search` usa su propio material_ui: sus TextField piden las
      // traducciones de ese paquete (las de flutter_localizations no le sirven).
      localizationsDelegates: const [
        ...GlobalMaterialLocalizations.delegates,
        mui.GlobalMaterialLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'MX')],
      locale: const Locale('es', 'MX'),
      theme: BarroTheme.data,
      initialRoute: widget.initialRoute,
      home: _RestaurarSesion(store: widget.sessionStore, login: _login),
      routes: {
        '/login': _login,
        '/register': (_) => OwnerRegistrationPage(
          validateRegistration: const ValidateOwnerRegistration(),
          registerOwner: RegisterOwner(_authentication),
        ),
        '/session': (context) {
          final session = ModalRoute.of(context)?.settings.arguments;
          if (session is! AuthSession || session.isExpired) {
            return _login(context);
          }
          // Este builder se ejecuta en cada reconstrucción: instalar la sesión solo una
          // vez para no pisar los tokens ya renovados con los del inicio de sesión.
          if (!identical(_sesionActual, session)) {
            // Si entra otro usuario sin pasar por cerrar sesión (p. ej. una
            // sesión restaurada), nada de lo guardado debe verse.
            if (_sesionActual?.userId != session.userId) _descartarCaches();
            _sesionActual = session;
            widget.sessionStore.guardar(session);
            _api.iniciarSesion(
              token: session.token,
              expiresAt: session.expiresAt,
              refreshToken: session.refreshToken,
              refreshExpiresAt: session.refreshExpiresAt,
            );
          }
          _rol = session.role;
          _contador.iniciar(session.token);
          return SessionPage(
            session: session,
            sessionExpired: _sesionExpirada,
            refreshExpiresAt: () =>
                _api.refreshExpiresAt ?? session.refreshExpiresAt,
            authGateway: _authentication,
            clearSession: () {
              widget.sessionStore.borrar();
              _api.cerrarSesion();
              _sesionActual = null;
              _contador.cerrarSesion();
              _descartarCaches();
            },
            conteoNotificaciones: _contador,
            openNotifications: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => NotificacionesPage(
                  gestion: _gestionPedidos,
                  contador: _contador,
                  esPropietario: _rol == 'PROPIETARIO',
                ),
              ),
            ),
            home: session.role == 'PROPIETARIO'
                ? NegociosPage(
                    gestion: GestionNegocios(
                      HttpNegocioGateway(_api, compartidas: _compartidas),
                    ),
                    selectorLogo: const FileSelectorLogo(),
                    onSesionExpirada: () => _cerrarSesion(context),
                    onAdministrar: (negocio) =>
                        _abrirSucursales(context, negocio),
                    onNegocioCreado: (negocio) =>
                        _abrirSucursales(context, negocio, registrar: true),
                    onCerrarSesion: () => _cerrarSesion(context),
                    conteoNotificaciones: _contador,
                    onNotificaciones: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => NotificacionesPage(
                          gestion: _gestionPedidos,
                          contador: _contador,
                          esPropietario: _rol == 'PROPIETARIO',
                        ),
                      ),
                    ),
                  )
                : session.role == 'EMPLEADO'
                ? _inicioEmpleado(context)
                : null,
          );
        },
        '/connection': (_) => const _ConnectionHome(),
      },
    ),
  );
}

/// Al abrir la app entra directo con la sesión guardada; sin ella muestra el login.
class _RestaurarSesion extends StatefulWidget {
  const _RestaurarSesion({required this.store, required this.login});
  final SessionStore store;
  final WidgetBuilder login;

  @override
  State<_RestaurarSesion> createState() => _RestaurarSesionState();
}

class _RestaurarSesionState extends State<_RestaurarSesion> {
  bool _sinSesion = false;

  @override
  void initState() {
    super.initState();
    widget.store.leer().then((session) {
      if (!mounted) return;
      if (session == null) {
        setState(() => _sinSesion = true);
      } else {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/session', (_) => false, arguments: session);
      }
    });
  }

  @override
  Widget build(BuildContext context) => _sinSesion
      ? widget.login(context)
      : const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _ConnectionHome extends StatefulWidget {
  const _ConnectionHome();
  @override
  State<_ConnectionHome> createState() => _ConnectionHomeState();
}

class _ConnectionHomeState extends State<_ConnectionHome> {
  late final ApiClient _api;
  @override
  void initState() {
    super.initState();
    _api = ApiClient(baseUrl: ApiConfig.baseUrl);
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ConnectionPage(checkConnection: CheckConnection(HttpHealthGateway(_api)));
}
