import 'package:flutter/material.dart';

import 'core/infrastructure/config/api_config.dart';
import 'core/infrastructure/network/api_client.dart';
import 'features/connection/application/services/check_connection.dart';
import 'features/connection/infrastructure/adapters/outbound/http/http_health_gateway.dart';
import 'features/connection/infrastructure/adapters/inbound/flutter/connection_page.dart';

void main() => runApp(const PuntoDeVentaApp());

class PuntoDeVentaApp extends StatelessWidget {
  const PuntoDeVentaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BarroControl',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF985A3B)),
      useMaterial3: true,
    ),
    home: const _ConnectionHome(),
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
