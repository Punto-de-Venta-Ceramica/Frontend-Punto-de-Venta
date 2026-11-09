import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/productos/domain/producto.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_widgets.dart';
import '../../../../application/ports/inbound/gestion_descuentos_use_case.dart';
import '../../../../domain/descuento.dart';
import 'descuento_detalle_page.dart';
import 'descuento_form_page.dart';
import 'descuento_widgets.dart';

/// Lista de todos los descuentos del negocio (activos e inactivos), con acceso
/// a registrar, administrar (asignaciones) y editar cada uno.
class DescuentosPage extends StatefulWidget {
  const DescuentosPage({
    required this.gestion,
    required this.negocio,
    required this.onSesionExpirada,
    super.key,
  });
  final GestionDescuentosUseCase gestion;
  final NegocioProducto negocio;
  final VoidCallback onSesionExpirada;
  @override
  State<DescuentosPage> createState() => _DescuentosPageState();
}

class _DescuentosPageState extends State<DescuentosPage> {
  List<Descuento> _descuentos = [];
  bool _busy = true;
  String? _error;
  String? _mensaje;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar({bool conservarMensaje = false}) async {
    setState(() {
      _busy = true;
      _error = null;
      if (!conservarMensaje) _mensaje = null;
    });
    try {
      final descuentos = await widget.gestion.listar(widget.negocio.id);
      if (!mounted) return;
      setState(() {
        _descuentos = descuentos;
        _busy = false;
      });
    } on DescuentoFailure catch (e) {
      if (!mounted) return;
      if (e.sesionExpirada) {
        widget.onSesionExpirada();
        return;
      }
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  Future<void> _formulario([Descuento? descuento]) async {
    if (_busy || _error != null) return;
    final resultado = await Navigator.of(context).push<ResultadoDescuento>(
      MaterialPageRoute(
        builder: (_) => DescuentoFormPage(
          negocio: widget.negocio,
          gestion: widget.gestion,
          descuento: descuento,
          onSesionExpirada: widget.onSesionExpirada,
        ),
      ),
    );
    if (!mounted || resultado == null) return;
    setState(() => _mensaje = resultado.mensaje);
    await _cargar(conservarMensaje: true);
  }

  Future<void> _administrar(Descuento descuento) async {
    if (_busy || _error != null) return;
    await Navigator.of(context).push<Descuento>(
      MaterialPageRoute(
        builder: (_) => DescuentoDetallePage(
          negocio: widget.negocio,
          descuento: descuento,
          gestion: widget.gestion,
          onSesionExpirada: widget.onSesionExpirada,
        ),
      ),
    );
    if (!mounted) return;
    await _cargar();
  }

  Widget _tarjeta(Descuento d) => Container(
    key: ValueKey('descuento-${d.id}'),
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: BarroTheme.border),
      borderRadius: BorderRadius.circular(21),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                d.nombre,
                style: BarroTheme.type(16, 23, weight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            DescuentoEstado(activo: d.activo),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${d.porcentajeTexto} % de descuento',
          style: BarroTheme.type(
            24,
            30,
            weight: FontWeight.w700,
            color: BarroTheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          d.rango,
          style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: productoSuave,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            d.sinAsignar ? 'Sin asignar' : 'Asignado a: ${d.asignacionTexto}',
            style: BarroTheme.type(
              11,
              16,
              weight: FontWeight.w700,
              color: BarroTheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              key: ValueKey('descuento-administrar-${d.id}'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () => _administrar(d),
              icon: const Icon(Icons.inventory_2_outlined, size: 18),
              label: const Text('Administrar'),
            ),
            TextButton.icon(
              key: ValueKey('descuento-editar-${d.id}'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () => _formulario(d),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Editar'),
            ),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ProductoScaffold(
    onRefresh: _busy ? () async {} : _cargar,
    children: [
      const SizedBox(height: 20),
      ProductoNegocioPanel(negocio: widget.negocio),
      const SizedBox(height: 20),
      Text('Descuentos', style: BarroTheme.type(34, 43, weight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(
        'Descuentos por cantidad de tu negocio.',
        style: BarroTheme.type(14, 22, color: BarroTheme.secondary),
      ),
      const SizedBox(height: 20),
      if (_mensaje != null) ...[
        ProductoAviso(_mensaje!),
        const SizedBox(height: 20),
      ],
      if (_busy)
        const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_error != null) ...[
        ProductoAviso(_error!, error: true),
        Center(
          child: TextButton(
            onPressed: _cargar,
            child: const Text('Reintentar'),
          ),
        ),
      ] else ...[
        ProductoBoton(
          key: const ValueKey('descuento-registrar'),
          texto: '+ Registrar descuento',
          onPressed: _formulario,
        ),
        const SizedBox(height: 20),
        if (_descuentos.isEmpty)
          const ProductoAviso('Aún no tienes descuentos registrados.')
        else ...[
          Text(
            '${_descuentos.length} ${_descuentos.length == 1 ? 'descuento registrado' : 'descuentos registrados'}',
            style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
          ),
          const SizedBox(height: 16),
          for (final d in _descuentos) _tarjeta(d),
        ],
      ],
      const SizedBox(height: 12),
      Center(
        child: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Volver'),
        ),
      ),
    ],
  );
}
