import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

  /// Descuentos del propietario: lista 5 min, catálogo para asignar 10 min.
  late final CachedDescuentoGateway _descuentos;

  /// Caché del empleado por sucursal (mismas vigencias que la del propietario:
  /// listado 5 min, áreas/categorías 30 min). Usa gateways con alcance de
  /// sucursal, por eso no comparte la del propietario.
  final _productosEmpleado = <int, CacheProductos>{};

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
    _productos = CacheProductos(
      HttpProductoGateway(_api),
      HttpExistenciasGateway(_api),
    );
    _descuentos = CachedDescuentoGateway(HttpDescuentoGateway(_api));
  }

  GestionProductos get _gestionProductos => GestionProductos(
    _productos.productos,
    _productos.existencias,
    cache: _productos,
  );

  @override
  void dispose() {
    _contador.dispose();
    _sesionExpirada.dispose();
    _api.close();
    super.dispose();
  }

  Widget _login(BuildContext context) => LoginPage(
    validateLogin: const ValidateLogin(),
    signIn: SignIn(_authentication),
    initialEmail: ModalRoute.of(context)?.settings.arguments is String
        ? ModalRoute.of(context)!.settings.arguments as String
        : '',
  );

  void _cerrarSesion(BuildContext context) {
    widget.sessionStore.borrar();
    _api.cerrarSesion();
    _sesionActual = null;
    _contador.cerrarSesion();
    _productos.descartar();
    _descuentos.descartar();
    _productosEmpleado.clear();
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
        gestion: GestionSucursales(HttpSucursalGateway(_api)),
        negocioInicial: NegocioSucursal(id: negocio.id, nombre: negocio.nombre),
        registrarAlAbrir: registrar,
        onSesionExpirada: () => _cerrarSesion(context),
        onAreasCategorias: (negocio) => _abrirCatalogo(context, negocio),
        onProductos: (negocio) => _abrirProductosNegocio(context, negocio),
        onDescuentos: (negocio) => _abrirDescuentosNegocio(context, negocio),
        onEmpleados: (negocio) => _abrirEmpleadosNegocio(context, negocio),
        onAdministrar: (negocio, sucursal) =>
            _abrirAdministracion(context, negocio, sucursal),
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
                gestion: GestionCatalogo(HttpCatalogoGateway(_api)),
                onSesionExpirada: () => _cerrarSesion(context),
              ),
            ),
          )
          .whenComplete(_productos.descartar);

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
        gestion: GestionEmpleados(HttpEmpleadoGateway(_api)),
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
        gestion: GestionCorteCaja(HttpCorteCajaGateway(_api)),
        sucursalId: sucursal.id,
        sucursalNombre: sucursal.nombre,
        negocioNombre: negocio.nombre,
        usuarioNombre: _sesionActual?.role ?? 'Propietario',
        esPropietario: true,
        onSesionExpirada: () => _cerrarSesion(context),
        onInicio: () => Navigator.of(cajaContext).popUntil((r) => r.isFirst),
        onPedidos: () =>
            _abrirPedidos(cajaContext, negocio, sucursal, reemplazar: true),
        onInventario: () =>
            _abrirProductos(cajaContext, negocio, sucursal, reemplazar: true),
      ),
    );
    final navigator = Navigator.of(context);
    return reemplazar ? navigator.pushReplacement(ruta) : navigator.push(ruta);
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
        gestion: GestionEmpleados(HttpEmpleadoGateway(_api)),
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
        .whenComplete(_productos.descartar);
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
      ),
    );
    final navigator = Navigator.of(context);
    return reemplazar ? navigator.pushReplacement(ruta) : navigator.push(ruta);
  }

  Future<void> _abrirPedidos(
    BuildContext context,
    NegocioSucursal negocio,
    Sucursal sucursal, {
    bool reemplazar = false,
  }) {
    final ruta = MaterialPageRoute<void>(
      builder: (pedidosContext) => PedidosPage(
        gestion: GestionPedidos(HttpPedidosGateway(_api)),
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
      gestion: GestionPedidos(HttpPedidosGateway(_api)),
      sucursalId: s.sucursalId,
      sucursalNombre: s.sucursal,
      negocio: NegocioProducto(id: s.negocioId, nombre: s.negocio),
      esPropietario: false,
      contador: _contador,
    ),
    construirCaja: (s) => CorteCajaPage(
      gestion: GestionCorteCaja(HttpCorteCajaGateway(_api)),
      sucursalId: s.sucursalId,
      sucursalNombre: s.sucursal,
      negocioNombre: s.negocio,
      usuarioNombre: _sesionActual?.role ?? 'Empleado',
      esPropietario: false,
      onSesionExpirada: () => _cerrarSesion(context),
    ),
    // Mismo listado y detalle que el propietario, en solo lectura: el
    // empleado únicamente ajusta existencias de su sucursal.
    construirInventario: (s) => ProductosPage(
      gestion: () {
        final cache = _cacheEmpleado(s);
        return GestionProductos(
          cache.productos,
          cache.existencias,
          cache: cache,
        );
      }(),
      negocioInicial: NegocioProducto(id: s.negocioId, nombre: s.negocio),
      sucursal: SucursalProducto(id: s.sucursalId, nombre: s.sucursal),
      soloLectura: true,
      onSesionExpirada: () => _cerrarSesion(context),
    ),
    onCerrarSesion: () => _cerrarSesion(context),
    conteoNotificaciones: _contador,
    onNotificaciones: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificacionesPage(
          gestion: GestionPedidos(HttpPedidosGateway(_api)),
          contador: _contador,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BarroControl',
    debugShowCheckedModeBanner: false,
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
          clearSession: () {
            widget.sessionStore.borrar();
            _api.cerrarSesion();
            _sesionActual = null;
            _contador.cerrarSesion();
            _productos.descartar();
            _productosEmpleado.clear();
          },
          conteoNotificaciones: _contador,
          openNotifications: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => NotificacionesPage(
                gestion: GestionPedidos(HttpPedidosGateway(_api)),
                contador: _contador,
              ),
            ),
          ),
          home: session.role == 'PROPIETARIO'
              ? NegociosPage(
                  gestion: GestionNegocios(HttpNegocioGateway(_api)),
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
                        gestion: GestionPedidos(HttpPedidosGateway(_api)),
                        contador: _contador,
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
  );
}

/// Pantalla de arranque: si hay una sesión guardada y vigente entra directo a
/// ella (el token de acceso vencido se renueva solo con el de renovación);
/// si no, muestra el login.
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
