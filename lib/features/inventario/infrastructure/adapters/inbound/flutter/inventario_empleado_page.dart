import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/productos/domain/producto.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_widgets.dart';
import '../../../../application/ports/outbound/inventario_gateway.dart';
import '../../../../domain/existencia_inventario.dart';

/// Productos y existencias de la sucursal del empleado. Solo consulta y ajusta
/// existencias: no crea, edita ni elimina productos.
class InventarioEmpleadoPage extends StatefulWidget {
  const InventarioEmpleadoPage({
    required this.gateway,
    required this.negocio,
    required this.sucursalId,
    required this.sucursalNombre,
    required this.onSesionExpirada,
    super.key,
  });

  final InventarioGateway gateway;
  final NegocioProducto negocio;
  final int sucursalId;
  final String sucursalNombre;
  final VoidCallback onSesionExpirada;

  @override
  State<InventarioEmpleadoPage> createState() => _InventarioEmpleadoPageState();
}

class _InventarioEmpleadoPageState extends State<InventarioEmpleadoPage> {
  List<ExistenciaInventario> _items = [];
  bool _cargando = true;
  String? _error;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final items = await widget.gateway.deSucursal(
        widget.negocio.id,
        widget.sucursalId,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _cargando = false;
      });
    } on InventarioFailure catch (e) {
      if (!mounted) return;
      if (e.sesionExpirada) {
        widget.onSesionExpirada();
        return;
      }
      setState(() {
        _error = e.message;
        _cargando = false;
      });
    }
  }

  Future<void> _ajustar(ExistenciaInventario item) async {
    final controlador = TextEditingController();
    final cantidad = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item.productoNombre),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Existencia actual: ${formatoPiezas(item.existencia)}'),
            const SizedBox(height: 12),
            TextField(
              controller: controlador,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(
                labelText: 'Piezas a sumar (o restar con -)',
                hintText: 'Ej. 5 o -2',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final valor = int.tryParse(controlador.text.trim());
              if (valor == null || valor == 0) return;
              Navigator.pop(dialogContext, valor);
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
    controlador.dispose();
    if (cantidad == null || !mounted) return;
    try {
      final nueva = await widget.gateway.ajustar(item.inventarioId, cantidad);
      if (!mounted) return;
      setState(() {
        _items = [
          for (final i in _items)
            i.inventarioId == item.inventarioId ? i.conExistencia(nueva) : i,
        ];
      });
    } on InventarioFailure catch (e) {
      if (!mounted) return;
      if (e.sesionExpirada) {
        widget.onSesionExpirada();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: BarroTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibles = _items
        .where(
          (i) =>
              i.productoNombre.toLowerCase().contains(_busqueda.toLowerCase()),
        )
        .toList();
    return ProductoScaffold(
      onRefresh: _cargar,
      children: [
        const SizedBox(height: 20),
        ProductoNegocioPanel(
          negocio: widget.negocio,
          sucursal: widget.sucursalNombre,
        ),
        const SizedBox(height: 20),
        Text(
          'Inventario',
          style: BarroTheme.type(28, 36, weight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Consulta los productos y ajusta su existencia.',
          style: BarroTheme.type(14, 20, color: BarroTheme.secondary),
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(hintText: 'Buscar producto...'),
          onChanged: (v) => setState(() => _busqueda = v),
        ),
        const SizedBox(height: 16),
        if (_cargando)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null) ...[
          Text(
            _error!,
            style: BarroTheme.type(14, 20, color: BarroTheme.error),
          ),
          TextButton(onPressed: _cargar, child: const Text('Reintentar')),
        ] else if (visibles.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                _items.isEmpty
                    ? 'Esta sucursal aún no tiene productos.'
                    : 'Sin resultados.',
                style: BarroTheme.type(14, 20, color: BarroTheme.secondary),
              ),
            ),
          )
        else
          for (final item in visibles)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: BarroTheme.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productoNombre,
                          style: BarroTheme.type(
                            15,
                            21,
                            weight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          formatoPiezas(item.existencia),
                          style: BarroTheme.type(
                            13,
                            18,
                            color: item.existencia == 0
                                ? BarroTheme.error
                                : BarroTheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _ajustar(item),
                    child: const Text('Ajustar'),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
