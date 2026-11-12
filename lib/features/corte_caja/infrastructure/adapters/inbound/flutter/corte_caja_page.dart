import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import '../../../../application/ports/inbound/gestion_corte_caja_use_case.dart';
import '../../../../domain/corte_caja.dart';
import 'corte_caja_widgets.dart';
import 'corte_realizado_page.dart';
import 'detalle_movimientos_page.dart';
import 'historial_cortes_page.dart';
import 'package:punto_de_venta/features/sucursal/infrastructure/adapters/inbound/flutter/sucursal_widgets.dart';

/// Pantalla principal de Corte de Caja (HU-13).
/// Muestra el arqueo y resumen de la caja activa (Screen 1 del mockup)
/// o el formulario para abrir turno si la caja está cerrada.
class CorteCajaPage extends StatefulWidget {
  const CorteCajaPage({
    required this.gestion,
    required this.sucursalId,
    required this.sucursalNombre,
    required this.esPropietario,
    this.negocioNombre = '',
    this.usuarioNombre = '',
    this.onSesionExpirada,
    this.onInicio,
    this.onPedidos,
    this.onInventario,
    super.key,
  });

  final GestionCorteCajaUseCase gestion;
  final int sucursalId;
  final String sucursalNombre;
  final bool esPropietario;
  final String negocioNombre;
  final String usuarioNombre;
  final VoidCallback? onSesionExpirada;
  final VoidCallback? onInicio;
  final VoidCallback? onPedidos;
  final VoidCallback? onInventario;

  @override
  State<CorteCajaPage> createState() => _CorteCajaPageState();
}

class _CorteCajaPageState extends State<CorteCajaPage> {
  bool _cargando = true;
  String? _error;
  CorteCaja? _corte;

  // Controladores para apertura y cierre
  final TextEditingController _contadoCtrl = TextEditingController();
  final TextEditingController _aperturaCtrl = TextEditingController(text: '0.00');
  double _diferencia = 0.0;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
    _contadoCtrl.addListener(_onContadoChanged);
  }

  @override
  void dispose() {
    _contadoCtrl.removeListener(_onContadoChanged);
    _contadoCtrl.dispose();
    _aperturaCtrl.dispose();
    super.dispose();
  }

  void _onContadoChanged() {
    if (_corte == null) return;
    final texto = _contadoCtrl.text.trim().replaceAll(',', '');
    final valor = double.tryParse(texto);
    if (valor != null) {
      setState(() {
        _diferencia = valor - _corte!.efectivoEsperado;
      });
    } else {
      setState(() {
        _diferencia = -_corte!.efectivoEsperado;
      });
    }
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final corte = await widget.gestion.obtenerCorteActivo(widget.sucursalId);
      if (!mounted) return;
      setState(() {
        _corte = corte;
        _cargando = false;
        if (corte != null) {
          // Pre-llenamos el efectivo contado con el esperado para agilizar
          final esperadoStr = corte.efectivoEsperado.toStringAsFixed(2);
          _contadoCtrl.text = esperadoStr;
          _diferencia = 0.0;
        }
      });
    } on CorteCajaFailure catch (e) {
      if (!mounted) return;
      if (e.sesionExpirada) {
        widget.onSesionExpirada?.call();
        return;
      }
      setState(() {
        _error = e.message;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Ocurrió un error inesperado al consultar la caja.';
        _cargando = false;
      });
    }
  }

  Future<void> _abrirCaja() async {
    final montoStr = _aperturaCtrl.text.trim().replaceAll(',', '');
    final monto = double.tryParse(montoStr);
    if (monto == null || monto < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto inicial válido mayor o igual a 0.')),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      final nuevoCorte = await widget.gestion.abrirCorte(
        sucursalId: widget.sucursalId,
        montoInicial: monto,
      );
      if (!mounted) return;
      setState(() {
        _corte = nuevoCorte;
        _guardando = false;
        final esperadoStr = nuevoCorte.efectivoEsperado.toStringAsFixed(2);
        _contadoCtrl.text = esperadoStr;
        _diferencia = 0.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Caja abierta correctamente.')),
      );
    } on CorteCajaFailure catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      if (e.sesionExpirada) {
        widget.onSesionExpirada?.call();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la caja.')),
      );
    }
  }

  Future<void> _confirmarYCerrarCorte() async {
    if (_corte == null) return;
    final contadoStr = _contadoCtrl.text.trim().replaceAll(',', '');
    final contado = double.tryParse(contadoStr);
    if (contado == null || contado < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa una cantidad de efectivo contado válida.')),
      );
      return;
    }

    final dif = contado - _corte!.efectivoEsperado;
    if (dif.abs() > 0.009) {
      final confirmacion = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: Text(
            'Diferencia detectada',
            style: BarroTheme.type(18, 24, weight: FontWeight.w700),
          ),
          content: Text(
            'Hay una diferencia de ${formatDinero(dif)} entre el efectivo contado y el esperado.\n\n¿Estás seguro de que deseas realizar el corte de caja con este monto?',
            style: BarroTheme.type(14, 20),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Revisar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: BarroTheme.primary,
              ),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Confirmar corte'),
            ),
          ],
        ),
      );

      if (confirmacion != true) return;
    }

    setState(() => _guardando = true);
    try {
      final corteCerrado = await widget.gestion.cerrarCorte(
        corteId: _corte!.id,
        totalReal: contado,
      );
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _corte = null; // Queda cerrada la caja
      });

      // Navegamos al comprobante contable (Screen 3)
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CorteRealizadoPage(
            corte: corteCerrado,
            esPropietario: widget.esPropietario,
            negocioNombre: widget.negocioNombre,
          ),
        ),
      );

      // Al volver, refrescamos el estado de la caja
      _cargar();
    } on CorteCajaFailure catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      if (e.sesionExpirada) {
        widget.onSesionExpirada?.call();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo realizar el corte de caja.')),
      );
    }
  }

  void _abrirHistorial() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HistorialCortesPage(
          gestion: widget.gestion,
          sucursalId: widget.sucursalId,
          sucursalNombre: widget.sucursalNombre,
          esPropietario: widget.esPropietario,
          negocioNombre: widget.negocioNombre,
          onSesionExpirada: widget.onSesionExpirada,
        ),
      ),
    );
  }

  void _abrirDetalleDia() {
    if (_corte == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DetalleMovimientosPage(
          corte: _corte!,
          esPropietario: widget.esPropietario,
          negocioNombre: widget.negocioNombre,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BarroTheme.background,
    // El empleado navega con la barra de su pantalla de inicio.
    bottomNavigationBar: widget.esPropietario
        ? SucursalNavegacion(
            seleccionada: 'Caja',
            onInicio:
                widget.onInicio ?? () => Navigator.of(context).maybePop(),
            onPedidos: widget.onPedidos,
            onInventario: widget.onInventario,
            onCaja: () {},
          )
        : null,
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _cargando
              ? const Center(
                  child: CircularProgressIndicator(color: BarroTheme.primary),
                )
              : _error != null
              ? _construirError()
              : _corte == null
              ? _construirAperturaCaja()
              : _construirCorteActivo(),
        ),
      ),
    ),
  );

  Widget _construirError() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 54, color: BarroTheme.error),
        const SizedBox(height: 16),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: BarroTheme.type(15, 22, color: BarroTheme.text),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _cargar,
          style: FilledButton.styleFrom(backgroundColor: BarroTheme.primary),
          child: const Text('Reintentar'),
        ),
      ],
    ),
  );

  /// Estado cuando la caja no está abierta (Formulario de apertura de turno).
  Widget _construirAperturaCaja() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CorteCabecera(esPropietario: widget.esPropietario),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Caja cerrada',
                    style: BarroTheme.type(30, 38, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Abre un turno para registrar movimientos',
                    style: BarroTheme.type(14, 20, color: BarroTheme.secondary),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _abrirHistorial,
              icon: const Icon(Icons.history, color: BarroTheme.primary),
              tooltip: 'Ver historial de cortes',
            ),
          ],
        ),
        const SizedBox(height: 24),
        SucursalCorteCard(
          sucursalNombre: widget.sucursalNombre,
          fecha: DateTime.now(),
          negocioNombre: widget.negocioNombre.isNotEmpty
              ? widget.negocioNombre
              : 'Cerámica La Lola',
          usuarioNombre: widget.usuarioNombre.isNotEmpty
              ? widget.usuarioNombre
              : (widget.esPropietario ? 'Propietario' : 'Empleado'),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: BarroTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fondo inicial en caja',
                style: BarroTheme.type(16, 22, weight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Ingresa la cantidad de efectivo disponible en el cajón para dar cambio e iniciar el día.',
                style: BarroTheme.type(13, 19, color: BarroTheme.secondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _aperturaCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                style: BarroTheme.type(18, 24, weight: FontWeight.w700),
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  prefixStyle: BarroTheme.type(
                    18,
                    24,
                    weight: FontWeight.w700,
                    color: BarroTheme.primary,
                  ),
                  filled: true,
                  fillColor: BarroTheme.background,
                  hintText: '0.00',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: BarroTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: BarroTheme.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: _guardando ? null : _abrirCaja,
          style: FilledButton.styleFrom(
            backgroundColor: BarroTheme.primary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _guardando
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'Abrir turno de caja',
                  style: BarroTheme.type(
                    16,
                    22,
                    weight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _abrirHistorial,
          icon: const Icon(Icons.history_rounded),
          label: const Text('Ver historial de cortes anteriores'),
          style: OutlinedButton.styleFrom(
            foregroundColor: BarroTheme.primary,
            side: const BorderSide(color: BarroTheme.border),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    ),
  );

  /// Estado principal (Screen 1 del mockup): Resumen del día, revisión de efectivo y cierre.
  Widget _construirCorteActivo() {
    final corte = _corte!;
    final fecha = corte.fechaHoraCierre ?? corte.fechaHoraApertura;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CorteCabecera(esPropietario: widget.esPropietario),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Corte de caja',
                      style: BarroTheme.type(30, 38, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Revisa los movimientos del día',
                      style: BarroTheme.type(14, 20, color: BarroTheme.secondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _abrirHistorial,
                icon: const Icon(Icons.history, color: BarroTheme.primary),
                tooltip: 'Historial de cortes',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Tarjeta de Negocio y Sucursal
          SucursalCorteCard(
            sucursalNombre: corte.sucursalNombre,
            fecha: fecha,
            negocioNombre: widget.negocioNombre.isNotEmpty
                ? widget.negocioNombre
                : 'Cerámica La Lola',
            usuarioNombre: corte.usuarioNombre,
          ),
          const SizedBox(height: 18),

          // Tabla: Resumen del día (Efectivo vs Tarjeta)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: BarroTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Resumen del día',
                  style: BarroTheme.type(16, 22, weight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        'Concepto',
                        style: BarroTheme.type(
                          12,
                          16,
                          weight: FontWeight.w700,
                          color: BarroTheme.secondary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Efectivo',
                        textAlign: TextAlign.right,
                        style: BarroTheme.type(
                          12,
                          16,
                          weight: FontWeight.w700,
                          color: BarroTheme.secondary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Tarjeta',
                        textAlign: TextAlign.right,
                        style: BarroTheme.type(
                          12,
                          16,
                          weight: FontWeight.w700,
                          color: BarroTheme.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: BarroTheme.border, height: 1),
                ),
                _filaResumen(
                  'Ventas',
                  formatDinero(corte.ventasEfectivo.totalVentas),
                  formatDinero(corte.ventasTarjeta.totalVentas),
                ),
                const SizedBox(height: 8),
                _filaResumen(
                  'Anticipos',
                  formatDinero(corte.ventasEfectivo.anticipos),
                  formatDinero(corte.ventasTarjeta.anticipos),
                ),
                const SizedBox(height: 8),
                _filaResumen(
                  'Liquidaciones',
                  formatDinero(corte.ventasEfectivo.liquidaciones),
                  formatDinero(corte.ventasTarjeta.liquidaciones),
                ),
                const SizedBox(height: 8),
                _filaResumen(
                  'Cancelaciones',
                  corte.ventasEfectivo.cancelaciones > 0
                      ? '-${formatDinero(corte.ventasEfectivo.cancelaciones)}'
                      : '\$0.00',
                  corte.ventasTarjeta.cancelaciones > 0
                      ? '-${formatDinero(corte.ventasTarjeta.cancelaciones)}'
                      : '\$0.00',
                  colorEfectivo: corte.ventasEfectivo.cancelaciones > 0
                      ? BarroTheme.error
                      : null,
                  colorTarjeta: corte.ventasTarjeta.cancelaciones > 0
                      ? BarroTheme.error
                      : null,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: BarroTheme.border, height: 1),
                ),
                _filaResumen(
                  'Neto del día',
                  formatDinero(corte.ventasEfectivo.subtotalNeto),
                  formatDinero(corte.ventasTarjeta.subtotalNeto),
                  negrita: true,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: BarroTheme.border, height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total neto',
                      style: BarroTheme.type(15, 20, weight: FontWeight.w700),
                    ),
                    Text(
                      formatDinero(corte.totalNetoDia),
                      style: BarroTheme.type(
                        17,
                        22,
                        weight: FontWeight.w700,
                        color: BarroTheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Tarjetas: Efectivo total esperado y Tarjeta total
          Row(
            children: [
              Expanded(
                child: _tarjetaTotal(
                  label: 'Total efectivo',
                  valor: corte.totalEfectivo,
                  icono: Icons.payments_outlined,
                  colorFondo: corteSuave,
                  colorBorde: BarroTheme.primary.withValues(alpha: 0.2),
                  colorTexto: BarroTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _tarjetaTotal(
                  label: 'Total tarjeta',
                  valor: corte.totalTarjeta,
                  icono: Icons.credit_card_rounded,
                  colorFondo: Colors.white,
                  colorBorde: BarroTheme.border,
                  colorTexto: BarroTheme.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Fila: Total estimado global
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: BarroTheme.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Total esperado en caja',
                    style: BarroTheme.type(
                      13,
                      18,
                      weight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatDinero(corte.totalEstimado),
                  style: BarroTheme.type(
                    16,
                    21,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Enlace a Screen 2 (Productos y movimientos)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _abrirDetalleDia,
              icon: const SizedBox.shrink(),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ver productos y movimientos',
                    style: BarroTheme.type(
                      14,
                      19,
                      weight: FontWeight.w600,
                      color: BarroTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: BarroTheme.primary,
                  ),
                ],
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Card: Revisión de efectivo (Arqueo)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: BarroTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Revisión de efectivo',
                  style: BarroTheme.type(16, 22, weight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Fondo inicial',
                      style: BarroTheme.type(
                        13,
                        18,
                        color: BarroTheme.secondary,
                      ),
                    ),
                    Text(
                      formatDinero(corte.montoInicial),
                      style: BarroTheme.type(14, 19, weight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Efectivo esperado',
                      style: BarroTheme.type(
                        13,
                        18,
                        color: BarroTheme.secondary,
                      ),
                    ),
                    Text(
                      formatDinero(corte.efectivoEsperado),
                      style: BarroTheme.type(
                        15,
                        20,
                        weight: FontWeight.w700,
                        color: BarroTheme.primary,
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: BarroTheme.border, height: 1),
                ),
                Text(
                  'Efectivo contado',
                  style: BarroTheme.type(13, 18, weight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _contadoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  style: BarroTheme.type(17, 22, weight: FontWeight.w700),
                  decoration: InputDecoration(
                    prefixText: '\$ ',
                    prefixStyle: BarroTheme.type(
                      17,
                      22,
                      weight: FontWeight.w700,
                      color: BarroTheme.primary,
                    ),
                    filled: true,
                    fillColor: BarroTheme.background,
                    hintText: '0.00',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: BarroTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: BarroTheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: BadgeDiferencia(diferencia: _diferencia),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Pie de pantalla: Responsable y sesión actual
          Text(
            'Realiza: ${corte.usuarioNombre} · Sesión actual',
            textAlign: TextAlign.center,
            style: BarroTheme.type(12, 16, color: BarroTheme.placeholder),
          ),
          const SizedBox(height: 16),

          // Botón Realizar Corte
          FilledButton(
            onPressed: _guardando ? null : _confirmarYCerrarCorte,
            style: FilledButton.styleFrom(
              backgroundColor: BarroTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _guardando
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Realizar corte',
                    style: BarroTheme.type(
                      16,
                      22,
                      weight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaTotal({
    required String label,
    required double valor,
    required IconData icono,
    required Color colorFondo,
    required Color colorBorde,
    required Color colorTexto,
  }) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorFondo,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorBorde),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, size: 15, color: colorTexto),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    label,
                    style: BarroTheme.type(
                      11,
                      15,
                      weight: FontWeight.w500,
                      color: BarroTheme.secondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              formatDinero(valor),
              style: BarroTheme.type(
                16,
                21,
                weight: FontWeight.w700,
                color: colorTexto,
              ),
            ),
          ],
        ),
      );

  Widget _filaResumen(
    String concepto,
    String efectivo,
    String tarjeta, {
    bool negrita = false,
    Color? colorEfectivo,
    Color? colorTarjeta,
  }) => Row(
    children: [
      Expanded(
        flex: 4,
        child: Text(
          concepto,
          style: BarroTheme.type(
            13,
            18,
            weight: negrita ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
      Expanded(
        flex: 3,
        child: Text(
          efectivo,
          textAlign: TextAlign.right,
          style: BarroTheme.type(
            13,
            18,
            weight: negrita ? FontWeight.w700 : FontWeight.w600,
            color: colorEfectivo ?? BarroTheme.text,
          ),
        ),
      ),
      Expanded(
        flex: 3,
        child: Text(
          tarjeta,
          textAlign: TextAlign.right,
          style: BarroTheme.type(
            13,
            18,
            weight: negrita ? FontWeight.w700 : FontWeight.w600,
            color: colorTarjeta ?? BarroTheme.text,
          ),
        ),
      ),
    ],
  );
}
