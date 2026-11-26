import 'package:flutter/material.dart';
import 'package:punto_de_venta/features/notificaciones/application/contador_notificaciones.dart';
import 'package:punto_de_venta/features/productos/domain/producto.dart';
import 'package:punto_de_venta/features/reportes/infrastructure/adapters/inbound/flutter/reporte_widgets.dart';
import 'package:punto_de_venta/features/sucursal/application/ports/inbound/gestion_sucursales_use_case.dart';
import 'package:punto_de_venta/features/sucursal/domain/sucursal.dart';
import 'package:punto_de_venta/features/sucursal/infrastructure/adapters/inbound/flutter/encabezado_sucursal_negocio.dart';

import '../../../application/gestion_pedidos.dart';
import 'pedidos_page.dart';

/// Pedidos desde el negocio (propietario): se elige la sucursal en la misma
/// pantalla, con el diseño de Datos contables, y debajo aparece su listado.
class PedidosNegocioPage extends StatefulWidget {
  const PedidosNegocioPage({
    required this.negocio,
    required this.sucursales,
    required this.gestion,
    required this.contador,
    required this.onSesionExpirada,
    super.key,
  });

  final NegocioSucursal negocio;
  final GestionSucursalesUseCase sucursales;
  final GestionPedidos gestion;
  final ContadorNotificaciones contador;
  final VoidCallback onSesionExpirada;

  @override
  State<PedidosNegocioPage> createState() => _PedidosNegocioPageState();
}

class _PedidosNegocioPageState extends State<PedidosNegocioPage> {
  List<Sucursal> _sucursales = const [];
  int? _sucursalId;
  String? _error;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarSucursales();
  }

  Future<void> _cargarSucursales() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final sucursales = await widget.sucursales.listar(widget.negocio.id);
      if (!mounted) return;
      setState(() {
        _sucursales = sucursales;
        // Con una sola sucursal no hay nada que elegir.
        if (sucursales.length == 1) _sucursalId = sucursales.first.id;
        _cargando = false;
      });
    } on SucursalFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _cargando = false;
      });
      if (error.sesionExpirada) widget.onSesionExpirada();
    }
  }

  Widget _encabezado() => EncabezadoSucursalNegocio(
    icono: Icons.receipt_long_outlined,
    titulo: 'Pedidos',
    descripcion: 'Da seguimiento a los pedidos de tu sucursal.',
    negocio: widget.negocio.nombre,
    sucursales: _sucursales,
    sucursalId: _sucursalId,
    cargando: _cargando,
    error: _error,
    onReintentar: _cargarSucursales,
    onElegir: (id) {
      if (id != null && id != _sucursalId) setState(() => _sucursalId = id);
    },
  );

  @override
  Widget build(BuildContext context) {
    final id = _sucursalId;
    if (id == null) {
      return PantallaNegocio(
        children: [
          _encabezado(),
          if (!_cargando && _error == null && _sucursales.isNotEmpty) ...[
            const SizedBox(height: 40),
            const SeleccionSucursalPendiente(
              icono: Icons.receipt_long_outlined,
              detalle:
                  'Selecciona una sucursal para ver sus pedidos y cambiar su estado.',
            ),
          ],
        ],
      );
    }
    final sucursal = _sucursales.firstWhere((s) => s.id == id);
    return PedidosPage(
      // Otra sucursal = otro listado (filtros, páginas y búsqueda desde cero).
      key: ValueKey(id),
      gestion: widget.gestion,
      sucursalId: id,
      sucursalNombre: sucursal.nombre,
      negocio: NegocioProducto(
        id: widget.negocio.id,
        nombre: widget.negocio.nombre,
      ),
      esPropietario: true,
      contador: widget.contador,
      encabezado: _encabezado(),
    );
  }
}
