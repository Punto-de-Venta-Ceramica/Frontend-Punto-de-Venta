import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import '../../../application/gestion_pedidos.dart';
import '../../../domain/pedido.dart';
import 'package:punto_de_venta/features/notificaciones/application/contador_notificaciones.dart';

class NotificacionesPage extends StatefulWidget {
  const NotificacionesPage({
    required this.gestion,
    required this.contador,
    super.key,
  });
  final GestionPedidos gestion;
  final ContadorNotificaciones contador;
  @override
  State<NotificacionesPage> createState() => _NotificacionesPageState();
}

class _NotificacionesPageState extends State<NotificacionesPage> {
  late Future<List<AvisoPedido>> _avisos;
  @override
  void initState() {
    super.initState();
    _avisos = widget.gestion.notificaciones();
    widget.contador.addListener(_actualizarLista);
  }

  @override
  void didUpdateWidget(covariant NotificacionesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contador != widget.contador) {
      oldWidget.contador.removeListener(_actualizarLista);
      widget.contador.addListener(_actualizarLista);
    }
  }

  @override
  void dispose() {
    widget.contador.removeListener(_actualizarLista);
    super.dispose();
  }

  void _actualizarLista() {
    if (mounted) {
      setState(() {
        _avisos = widget.gestion.notificaciones();
      });
    }
  }

  Future<void> _marcar(AvisoPedido aviso) async {
    if (aviso.leida) return;
    try {
      await widget.gestion.marcarLeida(aviso.id);
      if (mounted) {
        _actualizarLista();
        await widget.contador.actualizar();
      }
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
    appBar: AppBar(
      title: const Text('Notificaciones'),
      actions: [
        IconButton(
          tooltip: 'Actualizar notificaciones',
          onPressed: () {
            _actualizarLista();
            widget.contador.actualizar();
          },
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
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
