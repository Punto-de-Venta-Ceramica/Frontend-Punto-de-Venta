import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:punto_de_venta/core/infrastructure/network/api_client.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/productos/domain/producto.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_widgets.dart';
import '../../../application/gestion_pedidos.dart';
import '../../../domain/pedido.dart';
import 'pedido_input_formatters.dart';

/// Edición de los datos de un pedido (solo propietario): descripción, entrega y
/// datos del cliente. No cambia productos ni pagos.
///
/// Devuelve `true` al cerrar si se guardaron los cambios.
class EditarPedidoPage extends StatefulWidget {
  const EditarPedidoPage({
    required this.gestion,
    required this.pedido,
    required this.negocio,
    this.sucursalNombre,
    super.key,
  });
  final GestionPedidos gestion;
  final Pedido pedido;
  final NegocioProducto negocio;
  final String? sucursalNombre;

  @override
  State<EditarPedidoPage> createState() => _EditarPedidoPageState();
}

class _EditarPedidoPageState extends State<EditarPedidoPage> {
  final _form = GlobalKey<FormState>();
  late final _descripcion = TextEditingController(
    text: widget.pedido.descripcion,
  );
  late final _envio = TextEditingController(
    text: widget.pedido.descripcionEnvio,
  );
  late final _nombre = TextEditingController(text: widget.pedido.cliente);
  late final _telefono = TextEditingController(text: widget.pedido.telefono);
  late final _ciudad = TextEditingController(text: widget.pedido.ciudad);
  late final _colonia = TextEditingController(text: widget.pedido.colonia);
  late final _calle = TextEditingController(text: widget.pedido.calle);
  late String _entrega = widget.pedido.tipoEntrega == 'DOMICILIO'
      ? 'DOMICILIO'
      : 'LOCAL';
  Map<String, String> _errores = {};
  String? _error;
  bool _guardando = false;

  @override
  void dispose() {
    for (final c in [
      _descripcion,
      _envio,
      _nombre,
      _telefono,
      _ciudad,
      _colonia,
      _calle,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando || !_form.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
      _errores = {};
    });
    try {
      await widget.gestion.editarDatos(
        widget.pedido.id,
        DatosEdicionPedido(
          descripcion: PedidoInputFormatters.limpiarEspacios(_descripcion.text),
          tipoEntrega: _entrega,
          descripcionEnvio: PedidoInputFormatters.limpiarEspacios(_envio.text),
          cliente: PedidoInputFormatters.limpiarEspacios(_nombre.text),
          telefono: _telefono.text.trim(),
          ciudad: PedidoInputFormatters.limpiarEspacios(_ciudad.text),
          colonia: PedidoInputFormatters.limpiarEspacios(_colonia.text),
          calle: PedidoInputFormatters.limpiarEspacios(_calle.text),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errores = Map.of(e.fieldErrors);
        _error = _errores.isEmpty
            ? e.message
            : 'Revisa los campos marcados para guardar los cambios.';
      });
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _campo(
    String etiqueta,
    TextEditingController controller, {
    required String campo,
    required String ayuda,
    String? hint,
    int? maxLength,
    TextInputType? teclado,
    List<TextInputFormatter>? formatos,
    String? Function(String?)? validar,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProductoEtiqueta(etiqueta),
        TextFormField(
          key: ValueKey('editar-$campo'),
          controller: controller,
          maxLength: maxLength,
          keyboardType: teclado,
          inputFormatters: formatos,
          validator: validar,
          decoration: productoDecoracion(hint: hint, error: _errores[campo])
              .copyWith(
                counterText: '',
                helperText: ayuda,
                helperMaxLines: 3,
                helperStyle: BarroTheme.type(
                  12,
                  18,
                  color: BarroTheme.secondary,
                ),
              ),
          onChanged: (_) {
            if (_errores.containsKey(campo)) {
              setState(() => _errores.remove(campo));
            }
          },
        ),
      ],
    ),
  );

  Widget _seccion(String titulo) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 10),
    child: Text(
      titulo,
      style: BarroTheme.type(18, 26, weight: FontWeight.w700),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_guardando,
    child: ProductoScaffold(
      rol: 'Propietario',
      children: [
        const SizedBox(height: 14),
        TextButton.icon(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
          ),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Detalle del pedido'),
        ),
        ProductoNegocioPanel(
          negocio: widget.negocio,
          sucursal: widget.sucursalNombre,
        ),
        const SizedBox(height: 16),
        Text(
          'Editar pedido',
          style: BarroTheme.type(28, 36, weight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Los productos y los pagos no se modifican aquí.',
          style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
        ),
        const SizedBox(height: 18),
        if (_error != null) ...[
          ProductoAviso(_error!, error: true),
          const SizedBox(height: 12),
        ],
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _seccion('Pedido'),
              _campo(
                'Descripción del pedido',
                _descripcion,
                campo: 'descripcion',
                hint: 'Ej. Personalizados con logotipo',
                maxLength: 2000,
                formatos: PedidoInputFormatters.texto,
                ayuda:
                    'Opcional. Detalles generales, como personalización, colores o acabados.',
              ),
              const ProductoEtiqueta('Tipo de entrega *'),
              ProductoSelector<String>(
                valor: _entrega,
                opciones: const [
                  ('LOCAL', 'En sucursal'),
                  ('DOMICILIO', 'A domicilio'),
                ],
                onChanged: (v) => setState(() => _entrega = v!),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 12, bottom: 14),
                child: Text(
                  'En sucursal: el cliente lo recoge. A domicilio: se envía a la dirección del cliente.',
                  style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
                ),
              ),
              _campo(
                'Descripción de envío',
                _envio,
                campo: 'descripcionEnvio',
                hint: 'Ej. Entregar por la tarde, casa con portón azul',
                maxLength: 2000,
                formatos: PedidoInputFormatters.texto,
                ayuda:
                    'Opcional. Indicaciones para la entrega, como horario o referencias.',
              ),
              _seccion('Cliente'),
              _campo(
                'Nombre del cliente *',
                _nombre,
                campo: 'cliente.nombre',
                maxLength: 150,
                formatos: PedidoInputFormatters.nombre,
                validar: PedidoInputFormatters.validarNombre,
                ayuda: 'Nombre y apellido, sin números.',
              ),
              _campo(
                'Teléfono *',
                _telefono,
                campo: 'cliente.telefono',
                maxLength: 10,
                teclado: TextInputType.phone,
                formatos: PedidoInputFormatters.telefono,
                validar: PedidoInputFormatters.validarTelefono,
                ayuda: '10 dígitos, sin espacios ni guiones.',
              ),
              _campo(
                'Ciudad',
                _ciudad,
                campo: 'cliente.ciudad',
                maxLength: 120,
                formatos: PedidoInputFormatters.texto,
                ayuda: 'Opcional.',
              ),
              _campo(
                'Colonia',
                _colonia,
                campo: 'cliente.colonia',
                maxLength: 120,
                formatos: PedidoInputFormatters.texto,
                ayuda: 'Opcional.',
              ),
              _campo(
                'Calle y número',
                _calle,
                campo: 'cliente.calle',
                maxLength: 200,
                formatos: PedidoInputFormatters.texto,
                ayuda: 'Opcional. Necesaria si la entrega es a domicilio.',
              ),
              const SizedBox(height: 8),
              ProductoBoton(
                texto: 'Guardar cambios',
                busy: _guardando,
                onPressed: _guardar,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
