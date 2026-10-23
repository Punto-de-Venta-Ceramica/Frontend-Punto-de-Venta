import 'package:flutter/material.dart';
import 'package:punto_de_venta/features/connection/application/ports/inbound/check_connection_use_case.dart';
import 'package:punto_de_venta/features/connection/domain/connection_failure.dart';

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({required this.checkConnection, super.key});
  final CheckConnectionUseCase checkConnection;

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  bool _loading = true;
  bool _connected = false;
  String _message = 'Comprobando conexión…';

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _loading = true;
      _connected = false;
    });
    try {
      await widget.checkConnection.execute();
      if (!mounted) return;
      setState(() {
        _connected = true;
        _message = 'Backend conectado';
      });
    } on ConnectionFailure catch (error) {
      if (!mounted) return;
      setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('BarroControl')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Punto de venta',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  const Text('Tu espacio para administrar el negocio.'),
                  const SizedBox(height: 28),
                  if (_loading)
                    const LinearProgressIndicator()
                  else
                    Icon(
                      _connected
                          ? Icons.cloud_done_outlined
                          : Icons.cloud_off_outlined,
                      color: _connected
                          ? Colors.green
                          : Theme.of(context).colorScheme.error,
                      size: 40,
                    ),
                  const SizedBox(height: 16),
                  Text(
                    _loading ? 'Comprobando conexión…' : _message,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Las funciones de productos, ventas e inventario estarán disponibles cuando se implementen sus endpoints.',
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _loading ? null : _check,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Comprobar conexión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
