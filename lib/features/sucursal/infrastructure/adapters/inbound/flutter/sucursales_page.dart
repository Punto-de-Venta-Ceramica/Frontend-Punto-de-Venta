import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import '../../../../application/ports/inbound/gestion_sucursales_use_case.dart';
import '../../../../domain/sucursal.dart';
import 'sucursal_form_page.dart';
import 'sucursal_widgets.dart';

class SucursalesPage extends StatefulWidget {
  const SucursalesPage({
    required this.gestion,
    required this.onSesionExpirada,
    this.negocioInicial,
    this.registrarAlAbrir = false,
    super.key,
  });
  final GestionSucursalesUseCase gestion;
  final VoidCallback onSesionExpirada;
  final NegocioSucursal? negocioInicial;
  final bool registrarAlAbrir;
  @override
  State<SucursalesPage> createState() => _SucursalesPageState();
}

class _SucursalesPageState extends State<SucursalesPage> {
  List<NegocioSucursal> _negocios = [];
  NegocioSucursal? _negocio;
  List<Sucursal> _sucursales = [];
  bool _busy = true;
  String? _error;
  String? _mensaje;
  int _carga = 0;
  bool _registroAbierto = false;
  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  void _fallo(SucursalFailure e) {
    if (e.sesionExpirada) {
      widget.onSesionExpirada();
      return;
    }
    setState(() {
      _error = e.message;
      _busy = false;
    });
  }

  Future<void> _iniciar() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final negocios = widget.negocioInicial == null
          ? await widget.gestion.negocios()
          : [widget.negocioInicial!];
      if (!mounted) return;
      setState(() {
        _negocios = negocios;
        _negocio = negocios.firstOrNull;
        _sucursales = [];
      });
      if (_negocio != null) {
        if (widget.registrarAlAbrir && !_registroAbierto) {
          // El negocio recién creado aún no tiene sucursales.
          _registroAbierto = true;
          setState(() => _busy = false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _formulario();
          });
        } else {
          await _cargar(_negocio!);
        }
      } else {
        setState(() => _busy = false);
      }
    } on SucursalFailure catch (e) {
      if (mounted) _fallo(e);
    }
  }

  Future<void> _cargar(NegocioSucursal negocio) async {
    final carga = ++_carga;
    setState(() {
      _negocio = negocio;
      _sucursales = [];
      _busy = true;
      _error = null;
      _mensaje = null;
    });
    try {
      final sucursales = await widget.gestion.listar(negocio.id);
      if (!mounted || carga != _carga) return;
      setState(() {
        _sucursales = sucursales;
        _busy = false;
      });
    } on SucursalFailure catch (e) {
      if (mounted && carga == _carga) _fallo(e);
    }
  }

  Future<void> _formulario([Sucursal? sucursal]) async {
    if (_busy || _negocio == null || _error != null) return;
    final resultado = await Navigator.of(context).push<ResultadoSucursal>(
      MaterialPageRoute(
        builder: (_) => SucursalFormPage(
          negocio: _negocio!,
          gestion: widget.gestion,
          sucursal: sucursal,
          onSesionExpirada: widget.onSesionExpirada,
        ),
      ),
    );
    if (!mounted || resultado == null) return;
    setState(() {
      if (resultado.eliminada) {
        _sucursales = _sucursales.where((s) => s.id != sucursal!.id).toList();
        _mensaje = 'Sucursal eliminada correctamente.';
      } else {
        final guardada = resultado.sucursal!;
        _sucursales = [
          ..._sucursales.where((s) => s.id != guardada.id),
          guardada,
        ]..sort((a, b) => a.id.compareTo(b.id));
        _mensaje = sucursal == null
            ? 'Sucursal registrada correctamente.'
            : 'Cambios guardados correctamente.';
      }
    });
  }

  void _detalles(Sucursal sucursal) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sucursal.nombre,
                style: BarroTheme.type(24, 32, weight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                sucursal.descripcion.isEmpty
                    ? 'Sin descripción.'
                    : sucursal.descripcion,
              ),
              const SizedBox(height: 12),
              Text(
                sucursal.direccion.isEmpty
                    ? 'Dirección pendiente de completar.'
                    : sucursal.direccion,
              ),
              if (sucursal.ciudad.isNotEmpty) Text(sucursal.ciudad),
              const SizedBox(height: 24),
              SucursalBoton(
                texto: 'Editar sucursal',
                onPressed: () {
                  Navigator.pop(context);
                  _formulario(sucursal);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tarjeta(Sucursal sucursal) => Container(
    margin: const EdgeInsets.only(bottom: 20),
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
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sucursalSuave,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'S',
                style: BarroTheme.type(
                  23,
                  30,
                  weight: FontWeight.w700,
                  color: BarroTheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sucursal.nombre,
                    style: BarroTheme.type(18, 25, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Sucursal de este negocio',
                    style: BarroTheme.type(12, 18, color: BarroTheme.secondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          sucursal.direccion.isEmpty
              ? 'Dirección pendiente de completar.'
              : sucursal.direccion,
          style: BarroTheme.type(14, 21, color: BarroTheme.secondary),
        ),
        if (sucursal.ciudad.isNotEmpty)
          Text(
            sucursal.ciudad,
            style: BarroTheme.type(14, 21, color: BarroTheme.secondary),
          ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () => _detalles(sucursal),
              child: const Text('Administrar'),
            ),
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () => _formulario(sucursal),
              child: const Text('Editar'),
            ),
          ],
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: const SucursalNavegacion(),
    body: SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: RefreshIndicator(
            onRefresh: _busy ? () async {} : _iniciar,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SucursalCabecera(),
                  const SizedBox(height: 20),
                  if (_negocio != null) ...[
                    NegocioSucursalPanel(
                      negocio: _negocio!,
                      negocios: _negocios,
                      onChanged: _busy ? null : _cargar,
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (_mensaje != null) ...[
                    SucursalAviso(_mensaje!),
                    const SizedBox(height: 20),
                  ],
                  Text(
                    'Sucursales',
                    style: BarroTheme.type(34, 43, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Administra las sucursales de tu negocio.',
                    style: BarroTheme.type(14, 22, color: BarroTheme.secondary),
                  ),
                  const SizedBox(height: 20),
                  if (_negocio != null) ...[
                    SucursalBoton(
                      texto: '+ Registrar sucursal',
                      onPressed: _busy || _error != null
                          ? null
                          : () => _formulario(),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null) ...[
                    SucursalAviso(_error!, error: true),
                    Center(
                      child: TextButton(
                        onPressed: _iniciar,
                        child: const Text('Reintentar'),
                      ),
                    ),
                  ] else if (_negocios.isEmpty)
                    const SucursalAviso(
                      'Aún no tienes negocios vinculados. Registra un negocio para gestionar sus sucursales.',
                    )
                  else ...[
                    Text(
                      '${_sucursales.length} ${_sucursales.length == 1 ? 'sucursal registrada' : 'sucursales registradas'}',
                      style: BarroTheme.type(
                        13,
                        20,
                        color: BarroTheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_sucursales.isEmpty)
                      const SucursalAviso(
                        'Este negocio aún no tiene sucursales. Registra la primera para comenzar.',
                      ),
                    for (final sucursal in _sucursales) _tarjeta(sucursal),
                    if (_sucursales.any((s) => s.direccionPendiente))
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: sucursalSuave,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Hay sucursales con dirección pendiente. Puedes actualizar su nombre y descripción desde Editar.',
                          style: BarroTheme.type(
                            14,
                            23,
                            color: BarroTheme.secondary,
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        widget.negocioInicial == null
                            ? 'Volver a mi sesión'
                            : 'Volver a mis negocios',
                      ),
                    ),
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
