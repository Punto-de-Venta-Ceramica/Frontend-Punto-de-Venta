import 'package:flutter/material.dart';

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

class PuntoDeVentaApp extends StatelessWidget {
  const PuntoDeVentaApp({this.initialRoute = '/', super.key});
  final String initialRoute;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BarroControl',
    debugShowCheckedModeBanner: false,
    theme: BarroTheme.data,
    initialRoute: initialRoute,
    home: const LoginPage(validateLogin: ValidateLogin()),
    routes: {
      '/login': (_) => const LoginPage(validateLogin: ValidateLogin()),
      '/register': (_) => const OwnerRegistrationPage(
        validateRegistration: ValidateOwnerRegistration(),
      ),
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
