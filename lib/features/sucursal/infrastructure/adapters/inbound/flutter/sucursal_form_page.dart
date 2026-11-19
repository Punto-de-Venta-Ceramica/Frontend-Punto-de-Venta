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
        backgroundColor: BarroTheme.background,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDECEA),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFF6C9C4),
                        width: 6,
                      ),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 32,
                      color: BarroTheme.error,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '¿Eliminar sucursal?',
                  textAlign: TextAlign.center,
                  style: BarroTheme.type(21, 27, weight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Esta acción no se puede deshacer.',
                  textAlign: TextAlign.center,
                  style: BarroTheme.type(13, 19, color: BarroTheme.placeholder),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: BarroTheme.border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: sucursalSuave,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.storefront_outlined,
                          size: 21,
                          color: BarroTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.sucursal!.nombre,
                              style: BarroTheme.type(
                                15,
                                21,
                                weight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Negocio: ${widget.negocio.nombre}',
                              style: BarroTheme.type(
                                12,
                                18,
                                color: BarroTheme.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SucursalBoton(
                  texto: 'Eliminar sucursal',
                  destructivo: true,
                  icono: Icons.delete_outline_rounded,
                  onPressed: () => Navigator.pop(context, true),
                ),
                const SizedBox(height: 8),
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
    required IconData icono,
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
              fillColor: soloLectura
                  ? const Color(0xFFF5F0ED)
                  : BarroTheme.background,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              prefixIcon: Padding(
                // En el campo de varias líneas el icono se queda arriba.
                padding: EdgeInsets.only(
                  left: 12,
                  right: 8,
                  bottom: lineas > 1 ? 44 : 0,
                ),
                child: Icon(
                  icono,
                  size: 20,
                  color: soloLectura
                      ? BarroTheme.placeholder
                      : BarroTheme.primary,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 44),
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

  /// Encabezado con icono, título y descripción de la pantalla.
  Widget _encabezado() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: BarroTheme.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: BarroTheme.primary.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          _edicion
              ? Icons.edit_location_alt_outlined
              : Icons.add_business_outlined,
          color: Colors.white,
          size: 26,
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _edicion ? 'Editar sucursal' : 'Registrar sucursal',
              style: BarroTheme.type(26, 33, weight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              _edicion
                  ? 'Actualiza los datos de tu sucursal.'
                  : 'Agrega una sucursal a este negocio.',
              style: BarroTheme.type(14, 21, color: BarroTheme.secondary),
            ),
          ],
        ),
      ),
    ],
  );

  /// Aviso de que la dirección no se puede editar.
  Widget _avisoDireccion() => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFEFF4FB),
      border: Border.all(color: const Color(0xFFCBDCF0)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.lock_outline_rounded,
          size: 18,
          color: Color(0xFF2F5C8F),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'La dirección es de consulta. Solo puedes editar el nombre y la descripción.',
            style: BarroTheme.type(12, 18, color: const Color(0xFF244A75)),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SucursalCabecera(),
                    const SizedBox(height: 14),
                    TextButton.icon(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                      ),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Sucursales'),
                    ),
                    NegocioSucursalPanel(negocio: widget.negocio),
                    const SizedBox(height: 20),
                    _encabezado(),
                    const SizedBox(height: 22),
                    if (_error != null) ...[
                      SucursalAviso(_error!, error: true),
                      const SizedBox(height: 16),
                    ],
                    SucursalSeccion(
                      icono: Icons.storefront_outlined,
                      titulo: 'Datos generales',
                      subtitulo: 'Cómo identificarás a esta sucursal.',
                      children: [
                        _campo(
                          'nombre',
                          'Nombre de la sucursal *',
                          'Ej. Sucursal Norte',
                          icono: Icons.badge_outlined,
                        ),
                        _campo(
                          'descripcion',
                          'Descripción (opcional)',
                          'Describe tu sucursal (opcional)',
                          icono: Icons.notes_rounded,
                          lineas: 3,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SucursalSeccion(
                      icono: Icons.location_on_outlined,
                      titulo: 'Ubicación',
                      subtitulo: _edicion
                          ? 'Dirección registrada de la sucursal.'
                          : 'Dónde se encuentra la sucursal.',
                      children: [
                        if (_edicion) _avisoDireccion(),
                        _campo(
                          'ciudad',
                          _edicion ? 'Ciudad' : 'Ciudad *',
                          'Ej. Dolores Hidalgo',
                          icono: Icons.location_city_outlined,
                          direccion: true,
                        ),
                        _campo(
                          'calle',
                          _edicion ? 'Calle' : 'Calle *',
                          'Ej. Av. de los Héroes 24',
                          icono: Icons.signpost_outlined,
                          direccion: true,
                        ),
                        _campo(
                          'codigoPostal',
                          _edicion ? 'Código postal' : 'Código postal *',
                          'Ej. 37800',
                          icono: Icons.markunread_mailbox_outlined,
                          direccion: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 15,
                          color: BarroTheme.secondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '* Campos obligatorios.',
                          style: BarroTheme.type(
                            12,
                            18,
                            color: BarroTheme.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SucursalBoton(
                      key: const ValueKey('sucursal-guardar'),
                      texto: _edicion
                          ? 'Guardar cambios'
                          : 'Registrar sucursal',
                      icono: _edicion
                          ? Icons.save_outlined
                          : Icons.add_business_outlined,
                      busy: _busy,
                      onPressed: _guardar,
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: TextButton(
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    // Separada de "Guardar" para evitar toques por error.
                    if (_edicion) ...[
                      const SizedBox(height: 12),
                      const Divider(color: BarroTheme.border),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _eliminar,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: BarroTheme.error,
                            backgroundColor: const Color(0xFFFFF5F4),
                            minimumSize: const Size.fromHeight(48),
                            side: const BorderSide(color: Color(0xFFF0B7B1)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                          ),
                          label: const Text('Eliminar sucursal'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
