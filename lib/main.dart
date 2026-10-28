import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'features/authentication/application/services/authentication_services.dart';
import 'features/authentication/domain/auth_session.dart';
import 'features/authentication/infrastructure/adapters/outbound/http/http_authentication_gateway.dart';
import 'features/authentication/infrastructure/adapters/inbound/flutter/session_page.dart';
import 'features/sucursal/application/services/gestion_sucursales.dart';
import 'features/sucursal/infrastructure/adapters/outbound/http/http_sucursal_gateway.dart';
import 'features/sucursal/infrastructure/adapters/inbound/flutter/sucursales_page.dart';
import 'features/sucursal/domain/sucursal.dart';
import 'features/negocios/application/services/gestion_negocios.dart';
import 'features/negocios/domain/negocio.dart';
import 'features/negocios/infrastructure/adapters/inbound/flutter/negocios_page.dart';
import 'features/negocios/infrastructure/adapters/outbound/http/http_negocio_gateway.dart';
import 'features/negocios/infrastructure/adapters/outbound/files/file_selector_logo.dart';

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
  const PuntoDeVentaApp({this.initialRoute = '/', this.httpClient, super.key});
  final String initialRoute;
  final http.Client? httpClient;

  @override
  State<PuntoDeVentaApp> createState() => _PuntoDeVentaAppState();
}

class _PuntoDeVentaAppState extends State<PuntoDeVentaApp> {
  late final ApiClient _api;
  late final HttpAuthenticationGateway _authentication;
  @override
  void initState() {
    super.initState();
    _api = ApiClient(baseUrl: ApiConfig.baseUrl, client: widget.httpClient);
    _authentication = HttpAuthenticationGateway(_api);
  }

  @override
  void dispose() {
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
    _api.bearerToken = null;
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
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BarroControl',
    debugShowCheckedModeBanner: false,
    theme: BarroTheme.data,
    initialRoute: widget.initialRoute,
    home: Builder(builder: _login),
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
        _api.bearerToken = session.token;
        return SessionPage(
          session: session,
          clearSession: () => _api.bearerToken = null,
          openBusinesses: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => NegociosPage(
                gestion: GestionNegocios(HttpNegocioGateway(_api)),
                selectorLogo: const FileSelectorLogo(),
                onSesionExpirada: () => _cerrarSesion(context),
                onAdministrar: (negocio) => _abrirSucursales(context, negocio),
                onNegocioCreado: (negocio) =>
                    _abrirSucursales(context, negocio, registrar: true),
              ),
            ),
          ),
        );
      },
      '/connection': (_) => const _ConnectionHome(),
    },
  );
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
