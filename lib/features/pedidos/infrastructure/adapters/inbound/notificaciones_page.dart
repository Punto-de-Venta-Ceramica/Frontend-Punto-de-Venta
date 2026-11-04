import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import '../../../application/gestion_pedidos.dart';
import '../../../domain/pedido.dart';

class NotificacionesPage extends StatefulWidget {
  const NotificacionesPage({required this.gestion, super.key});
  final GestionPedidos gestion;
  @override
  State<NotificacionesPage> createState() => _NotificacionesPageState();
}

class _NotificacionesPageState extends State<NotificacionesPage> {
  late Future<List<AvisoPedido>> _avisos;
  @override
  void initState() {
    super.initState();
    _avisos = widget.gestion.notificaciones();
  }

  Future<void> _marcar(AvisoPedido aviso) async {
    if (aviso.leida) return;
    try {
      await widget.gestion.marcarLeida(aviso.id);
      if (mounted) setState(() => _avisos = widget.gestion.notificaciones());
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notificaciones')),
    body: FutureBuilder<List<AvisoPedido>>(
      future: _avisos,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(
            child: Text('No se pudieron cargar las notificaciones.'),
          );
        }
        final avisos = snapshot.data ?? [];
        if (avisos.isEmpty) {
          return const Center(child: Text('No tienes notificaciones.'));
        }
        return ListView.builder(
          itemCount: avisos.length,
          itemBuilder: (context, index) {
            final aviso = avisos[index];
            return ListTile(
              leading: Icon(
                aviso.leida
                    ? Icons.notifications_none
                    : Icons.notifications_active,
              ),
              title: Text(aviso.titulo),
              subtitle: Text(aviso.mensaje),
              trailing: aviso.leida ? null : const Text('Nueva'),
              onTap: () => _marcar(aviso),
            );
          },
        );
      },
    ),
  );
}
