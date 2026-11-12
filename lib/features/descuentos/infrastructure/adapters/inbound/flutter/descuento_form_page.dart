import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/productos/domain/producto.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/inbound/flutter/producto_widgets.dart';
import '../../../../application/ports/inbound/gestion_descuentos_use_case.dart';
import '../../../../domain/descuento.dart';
import 'descuento_widgets.dart';

/// Registro o edición de un descuento. En edición también permite activarlo,
/// desactivarlo y eliminarlo. Se cierra con un [ResultadoDescuento].
class DescuentoFormPage extends StatefulWidget {
  const DescuentoFormPage({
    required this.negocio,
    required this.gestion,
    required this.onSesionExpirada,
    this.descuento,
    super.key,
  });
  final NegocioProducto negocio;
  final GestionDescuentosUseCase gestion;
  final VoidCallback onSesionExpirada;
  final Descuento? descuento;
  @override
  State<DescuentoFormPage> createState() => _DescuentoFormPageState();
}

class _DescuentoFormPageState extends State<DescuentoFormPage> {
  final _nombre = TextEditingController();
  final _minimo = TextEditingController();
  final _maximo = TextEditingController();
  final _porcentaje = TextEditingController();
  final _errores = <String, String>{};
  bool _busy = false;
  String? _error;
  bool get _edicion => widget.descuento != null;

  @override
  void initState() {
    super.initState();
    final d = widget.descuento;
    if (d != null) {
      _nombre.text = d.nombre;
      _minimo.text = '${d.cantidadMinima}';
      _maximo.text = d.cantidadMaxima == null ? '' : '${d.cantidadMaxima}';
      _porcentaje.text = d.porcentajeTexto;
    }
  }

  @override
  void dispose() {
    for (final c in [_nombre, _minimo, _maximo, _porcentaje]) {
      c.dispose();
    }
    super.dispose();
  }

  DatosDescuento _datos() => DatosDescuento(
    nombre: _nombre.text,
    cantidadMinima: _minimo.text,
    cantidadMaxima: _maximo.text,
    porcentaje: _porcentaje.text,
  );

  void _fallo(DescuentoFailure e) {
    if (e.sesionExpirada) {
      widget.onSesionExpirada();
      return;
    }
    setState(() {
      _error = e.message;
      _busy = false;
      for (final entry in e.fieldErrors.entries) {
        _errores[entry.key.split('.').last] = entry.value;
      }
      // El rango choca con otro descuento: se señala dónde corregir.
      if (e.traslape && _maximo.text.trim().isNotEmpty) {
        _errores['cantidadMaxima'] = 'Ajusta el rango.';
      } else if (e.traslape) {
        _errores['cantidadMinima'] = 'Ajusta el rango.';
      }
    });
  }

  /// Ejecuta [accion] y cierra la pantalla con su resultado.
  Future<void> _ejecutar(Future<ResultadoDescuento> Function() accion) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final resultado = await accion();
      if (!mounted) return;
      setState(() => _busy = false);
      Navigator.of(context).pop<ResultadoDescuento>(resultado);
    } on DescuentoFailure catch (e) {
      if (mounted) _fallo(e);
    }
  }

  Future<void> _guardar() async {
    final errores = _datos().validar();
    if (errores.isNotEmpty) {
      setState(() {
        _errores
          ..clear()
          ..addAll(errores);
        _error = null;
      });
      return;
    }
    await _ejecutar(() async {
      final negocioId = widget.negocio.id;
      if (_edicion) {
        final d = await widget.gestion.editar(
          negocioId,
          widget.descuento!.id,
          _datos(),
        );
        return ResultadoDescuento(
          descuento: d,
          mensaje: 'Cambios guardados correctamente.',
        );
      }
      final d = await widget.gestion.crear(negocioId, _datos());
      return ResultadoDescuento(
        descuento: d,
        mensaje: 'Descuento registrado correctamente.',
      );
    });
  }

  Future<void> _cambiarEstado() => _ejecutar(() async {
    final activar = !widget.descuento!.activo;
    final d = await widget.gestion.cambiarEstado(
      widget.negocio.id,
      widget.descuento!.id,
      activo: activar,
    );
    return ResultadoDescuento(
      descuento: d,
      mensaje: activar
          ? 'Descuento activado correctamente.'
          : 'Descuento desactivado correctamente.',
    );
  });

  Future<void> _eliminar() async {
    if (_busy) return;
    final confirmado = await confirmarEliminarDescuento(
      context,
      descuento: widget.descuento!,
    );
    if (!confirmado || !mounted) return;
    await _ejecutar(() async {
      await widget.gestion.eliminar(widget.negocio.id, widget.descuento!.id);
      return const ResultadoDescuento(
        mensaje: 'Descuento eliminado correctamente.',
        eliminado: true,
      );
    });
  }

  void _limpiar(String clave) {
    if (_errores.containsKey(clave) || _error != null) {
      setState(() => _errores.remove(clave));
    }
  }

  Widget _texto(
    String clave,
    String etiqueta,
    TextEditingController controller, {
    String? hint,
    TextInputType? teclado,
    List<TextInputFormatter>? formatos,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ProductoEtiqueta(etiqueta),
      TextField(
        key: ValueKey('descuento-$clave'),
        controller: controller,
        enabled: !_busy,
        keyboardType: teclado,
        inputFormatters: formatos,
        style: BarroTheme.type(14, 21),
        decoration: productoDecoracion(hint: hint, error: _errores[clave]),
        onChanged: (_) => _limpiar(clave),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final minimo = int.tryParse(_minimo.text.trim());
    final maximo = int.tryParse(_maximo.text.trim());
    final porcentaje = double.tryParse(
      _porcentaje.text.trim().replaceAll(',', '.'),
    );
    final vistaPrevia =
        minimo != null &&
            minimo > 0 &&
            porcentaje != null &&
            porcentaje > 0 &&
            porcentaje <= 100
        ? (maximo == null
              ? 'Desde $minimo piezas, se aplica un ${_porcentaje.text.trim()} % de descuento.'
              : 'De $minimo a $maximo piezas, se aplica un ${_porcentaje.text.trim()} % de descuento.')
        : null;
    return PopScope(
      canPop: !_busy,
      child: ProductoScaffold(
        children: [
          const SizedBox(height: 14),
          DescuentoEnlaceVolver(
            onPressed: _busy ? null : () => Navigator.pop(context),
          ),
          ProductoNegocioPanel(negocio: widget.negocio),
          const SizedBox(height: 16),
          Text(
            _edicion ? 'Editar descuento' : 'Registrar descuento',
            style: BarroTheme.type(28, 36, weight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            _edicion
                ? 'Actualiza los datos o el estado del descuento.'
                : 'Crea un descuento por cantidad para tu negocio.',
            style: BarroTheme.type(14, 21, color: BarroTheme.secondary),
          ),
          const SizedBox(height: 20),
          if (_error != null) ...[
            ProductoAviso(_error!, error: true),
            const SizedBox(height: 16),
          ],
          _texto(
            'nombre',
            'Nombre del descuento *',
            _nombre,
            hint: 'Ej. Mayoreo de ollas',
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _texto(
                  'cantidadMinima',
                  'Desde (piezas) *',
                  _minimo,
                  teclado: TextInputType.number,
                  formatos: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _texto(
                  'cantidadMaxima',
                  'Hasta (piezas)',
                  _maximo,
                  hint: 'Sin tope',
                  teclado: TextInputType.number,
                  formatos: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _texto(
            'porcentaje',
            'Descuento (%) *',
            _porcentaje,
            hint: 'Ej. 10',
            teclado: const TextInputType.numberWithOptions(decimal: true),
            formatos: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          ),
          const SizedBox(height: 12),
          Text(
            vistaPrevia ??
                'Deja "Hasta" vacío si el descuento no tiene límite de piezas.',
            key: const ValueKey('descuento-vista-previa'),
            style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
          ),
          const SizedBox(height: 28),
          ProductoBoton(
            key: const ValueKey('descuento-guardar'),
            texto: _edicion ? 'Guardar cambios' : 'Registrar descuento',
            busy: _busy,
            onPressed: _guardar,
          ),
          if (_edicion) ...[
            const SizedBox(height: 28),
            Text(
              'Estado y eliminación',
              style: BarroTheme.type(18, 26, weight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              widget.descuento!.activo
                  ? 'Mientras esté activo, el descuento se aplica a sus productos asignados.'
                  : 'Está inactivo: no se aplica en los pedidos, pero conserva sus asignaciones.',
              style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
            ),
            const SizedBox(height: 14),
            DescuentoBotonContorno(
              key: const ValueKey('descuento-estado'),
              texto: widget.descuento!.activo
                  ? 'Desactivar descuento'
                  : 'Activar descuento',
              onPressed: _busy ? null : _cambiarEstado,
            ),
            const SizedBox(height: 12),
            ProductoBotonPeligro(
              key: const ValueKey('descuento-eliminar'),
              texto: 'Eliminar descuento',
              onPressed: _busy ? null : _eliminar,
            ),
          ],
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ),
        ],
      ),
    );
  }
}
