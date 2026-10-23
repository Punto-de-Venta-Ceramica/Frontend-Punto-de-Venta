import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import '../../../../application/ports/inbound/gestion_sucursales_use_case.dart';
import '../../../../domain/sucursal.dart';
import 'sucursal_widgets.dart';

typedef ResultadoSucursal = ({Sucursal? sucursal, bool eliminada});

class SucursalFormPage extends StatefulWidget {
  const SucursalFormPage({
    required this.negocio,
    required this.gestion,
    required this.onSesionExpirada,
    this.sucursal,
    super.key,
  });
  final NegocioSucursal negocio;
  final GestionSucursalesUseCase gestion;
  final VoidCallback onSesionExpirada;
  final Sucursal? sucursal;
  @override
  State<SucursalFormPage> createState() => _SucursalFormPageState();
}

class _SucursalFormPageState extends State<SucursalFormPage> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _campos;
  final _servidor = <String, String>{};
  bool _busy = false;
  String? _error;
  bool get _edicion => widget.sucursal != null;
  DatosSucursal get _datos => DatosSucursal(
    nombre: _campos['nombre']!.text,
    descripcion: _campos['descripcion']!.text,
    ciudad: _campos['ciudad']!.text,
    calle: _campos['calle']!.text,
    codigoPostal: _campos['codigoPostal']!.text,
  );
  @override
  void initState() {
    super.initState();
    final s = widget.sucursal;
    _campos = {
      for (final e in {
        'nombre': s?.nombre ?? '',
        'descripcion': s?.descripcion ?? '',
        'ciudad': s?.ciudad ?? '',
        'calle': s?.calle ?? '',
        'codigoPostal': s?.codigoPostal ?? '',
      }.entries)
        e.key: TextEditingController(text: e.value),
    };
  }

  @override
  void dispose() {
    for (final c in _campos.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _fallo(SucursalFailure e) {
    if (e.sesionExpirada) {
      widget.onSesionExpirada();
      return;
    }
    setState(() {
      _servidor.addAll(e.fieldErrors);
      _error = e.message;
    });
    _form.currentState?.validate();
  }

  Future<void> _guardar() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    _servidor.clear();
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final guardada = _edicion
          ? await widget.gestion.editar(widget.sucursal!.id, _datos)
          : await widget.gestion.crear(widget.negocio.id, _datos);
      if (!mounted) return;
      // Desbloquea PopScope antes de devolver el resultado confirmado.
      setState(() => _busy = false);
      Navigator.of(
        context,
      ).pop<ResultadoSucursal>((sucursal: guardada, eliminada: false));
    } on SucursalFailure catch (e) {
      if (mounted) _fallo(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _eliminar() async {
    if (_busy) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0EE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.priority_high,
                    color: BarroTheme.error,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '¿Eliminar sucursal?',
                  style: BarroTheme.type(23, 30, weight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Text(
                  'Confirma que deseas eliminar:',
                  style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.sucursal!.nombre,
                  style: BarroTheme.type(16, 23, weight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Negocio: ${widget.negocio.nombre}',
                  style: BarroTheme.type(12, 19, color: BarroTheme.secondary),
                ),
                const SizedBox(height: 26),
                SucursalBoton(
                  texto: 'Eliminar sucursal',
                  destructivo: true,
                  onPressed: () => Navigator.pop(context, true),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmar != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.gestion.eliminar(widget.sucursal!.id);
      if (!mounted) return;
      setState(() => _busy = false);
      Navigator.of(
        context,
      ).pop<ResultadoSucursal>((sucursal: null, eliminada: true));
    } on SucursalFailure catch (e) {
      if (mounted) _fallo(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _campo(
    String clave,
    String etiqueta,
    String hint, {
    bool direccion = false,
    int lineas = 1,
  }) {
    final soloLectura = direccion && _edicion;
    OutlineInputBorder borde(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: BarroTheme.type(13, 19, weight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: ValueKey('sucursal-$clave'),
            controller: _campos[clave],
            enabled: !_busy,
            readOnly: soloLectura,
            minLines: lineas,
            maxLines: lineas,
            style: BarroTheme.type(14, 21),
            keyboardType: clave == 'codigoPostal'
                ? TextInputType.number
                : lineas > 1
                ? TextInputType.multiline
                : TextInputType.text,
            textCapitalization: clave == 'codigoPostal'
                ? TextCapitalization.none
                : TextCapitalization.sentences,
            inputFormatters: clave == 'codigoPostal' && !soloLectura
                ? [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ]
                : null,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (_) => soloLectura
                ? null
                : _servidor[clave] ??
                      _datos.validar(registro: !_edicion)[clave],
            onChanged: (_) {
              if (_servidor.containsKey(clave)) {
                setState(() => _servidor.remove(clave));
              }
            },
            decoration: InputDecoration(
              hintText: soloLectura ? 'Sin registrar' : hint,
              hintStyle: BarroTheme.type(14, 21, color: BarroTheme.placeholder),
              filled: true,
              fillColor: soloLectura ? const Color(0xFFF2EDEA) : Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: borde(BarroTheme.border),
              enabledBorder: borde(BarroTheme.border),
              disabledBorder: borde(BarroTheme.border),
              focusedBorder: borde(BarroTheme.primary),
              errorBorder: borde(BarroTheme.error),
              focusedErrorBorder: borde(BarroTheme.error),
              errorMaxLines: 3,
              suffixIcon: soloLectura
                  ? const Icon(
                      Icons.lock_outline,
                      size: 17,
                      color: BarroTheme.placeholder,
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 36,
                  ),
                  child: IntrinsicHeight(
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SucursalCabecera(),
                          const SizedBox(height: 14),
                          TextButton.icon(
                            onPressed: _busy
                                ? null
                                : () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              alignment: Alignment.centerLeft,
                            ),
                            icon: const Icon(Icons.arrow_back, size: 18),
                            label: const Text('Sucursales'),
                          ),
                          NegocioSucursalPanel(negocio: widget.negocio),
                          const SizedBox(height: 16),
                          Text(
                            _edicion ? 'Editar sucursal' : 'Registrar sucursal',
                            style: BarroTheme.type(
                              28,
                              36,
                              weight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _edicion
                                ? 'Actualiza los datos de tu sucursal.'
                                : 'Agrega una sucursal a este negocio.',
                            style: BarroTheme.type(
                              14,
                              21,
                              color: BarroTheme.secondary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (_error != null) ...[
                            SucursalAviso(_error!, error: true),
                            const SizedBox(height: 16),
                          ],
                          _campo(
                            'nombre',
                            'Nombre de la sucursal *',
                            'Ej. Sucursal Norte',
                          ),
                          _campo(
                            'descripcion',
                            'Descripción (opcional)',
                            'Describe tu sucursal (opcional)',
                            lineas: 3,
                          ),
                          if (_edicion)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                'La dirección es de consulta. Solo puedes editar el nombre y la descripción.',
                                style: BarroTheme.type(
                                  12,
                                  18,
                                  color: BarroTheme.secondary,
                                ),
                              ),
                            ),
                          _campo(
                            'ciudad',
                            _edicion ? 'Ciudad' : 'Ciudad *',
                            'Ej. Dolores Hidalgo',
                            direccion: true,
                          ),
                          _campo(
                            'calle',
                            _edicion ? 'Calle' : 'Calle *',
                            'Ej. Av. de los Héroes 24',
                            direccion: true,
                          ),
                          _campo(
                            'codigoPostal',
                            _edicion ? 'Código postal' : 'Código postal *',
                            'Ej. 37800',
                            direccion: true,
                          ),
                          Text(
                            '* Campos obligatorios.',
                            style: BarroTheme.type(
                              12,
                              18,
                              color: BarroTheme.secondary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Spacer(),
                          if (_edicion) ...[
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _busy ? null : _eliminar,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: BarroTheme.error,
                                  minimumSize: const Size.fromHeight(48),
                                  side: const BorderSide(
                                    color: BarroTheme.error,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Eliminar sucursal'),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          SucursalBoton(
                            key: const ValueKey('sucursal-guardar'),
                            texto: _edicion
                                ? 'Guardar cambios'
                                : 'Registrar sucursal',
                            busy: _busy,
                            onPressed: _guardar,
                          ),
                          const SizedBox(height: 4),
                          Center(
                            child: TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => Navigator.pop(context),
                              child: const Text('Cancelar'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
