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
import 'package:punto_de_venta/core/infrastructure/services/notificacion_servicio.dart';

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
    this.onRegistrarVenta,
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
  final Future<bool> Function(BuildContext context)? onRegistrarVenta;

  @override
  State<CorteCajaPage> createState() => _CorteCajaPageState();
}

class _CorteCajaPageState extends State<CorteCajaPage> {
  bool _cargando = true;
  String? _error;
  CorteCaja? _corte;

  // Controladores para apertura y cierre
  final TextEditingController _contadoCtrl = TextEditingController();
  final TextEditingController _aperturaCtrl = TextEditingController(
    text: '0.00',
  );
  double _diferencia = 0.0;
  bool _guardando = false;
  bool _abriendoVenta = false;

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
      NotificacionServicio.advertencia(
        context,
        'Ingresa un monto inicial válido mayor o igual a 0.',
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
      NotificacionServicio.exito(context, 'Caja abierta correctamente.');
    } on CorteCajaFailure catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      if (e.sesionExpirada) {
        widget.onSesionExpirada?.call();
        return;
      }
      NotificacionServicio.error(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardando = false);
      NotificacionServicio.error(context, 'No se pudo abrir la caja.');
    }
  }

  Future<void> _confirmarYCerrarCorte() async {
    if (_corte == null) return;
    final contadoStr = _contadoCtrl.text.trim().replaceAll(',', '');
    final contado = double.tryParse(contadoStr);
    if (contado == null || contado < 0) {
      NotificacionServicio.advertencia(
        context,
        'Ingresa una cantidad de efectivo contado válida.',
      );
      return;
    }

    final dif = contado - _corte!.efectivoEsperado;
    if (dif.abs() > 0.009) {
      final confirmacion = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => _DiferenciaDialog(
          diferencia: dif,
          esperado: _corte!.efectivoEsperado,
          contado: contado,
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
      NotificacionServicio.error(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardando = false);
      NotificacionServicio.error(
        context,
        'No se pudo realizar el corte de caja.',
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

  Future<void> _registrarVenta() async {
    final abrirVenta = widget.onRegistrarVenta;
    if (abrirVenta == null || _abriendoVenta || _guardando || _corte == null) {
      return;
    }
    setState(() => _abriendoVenta = true);
    try {
      final registrada = await abrirVenta(context);
      if (mounted && registrada) await _cargar();
    } finally {
      if (mounted) setState(() => _abriendoVenta = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BarroTheme.background,
    // El empleado navega con la barra de su pantalla de inicio.
    bottomNavigationBar: widget.esPropietario
        ? SucursalNavegacion(
            seleccionada: 'Caja',
            onInicio: widget.onInicio ?? () => Navigator.of(context).maybePop(),
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

  /// Botón de historial (solo propietario, HU-05).
  Widget _botonHistorial(String tooltip) => IconButton(
    onPressed: _abrirHistorial,
    tooltip: tooltip,
    style: IconButton.styleFrom(
      backgroundColor: Colors.white,
      side: const BorderSide(color: BarroTheme.border),
      minimumSize: const Size(46, 46),
    ),
    icon: const Icon(Icons.history, color: BarroTheme.primary),
  );

  /// Botón principal grande con icono y estado de carga.
  Widget _botonPrincipal({
    required String texto,
    required IconData icono,
    required VoidCallback? onPressed,
    bool cargando = false,
  }) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: BarroTheme.primary,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(54),
      elevation: 2,
      shadowColor: BarroTheme.primary.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    child: cargando
        ? const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 21),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  texto,
                  style: BarroTheme.type(
                    16,
                    22,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
  );

  InputDecoration _decoracionMonto({required IconData icono}) =>
      InputDecoration(
        prefixIcon: Icon(icono, color: BarroTheme.primary),
        prefixText: '\$ ',
        prefixStyle: BarroTheme.type(
          20,
          26,
          weight: FontWeight.w700,
          color: BarroTheme.primary,
        ),
        filled: true,
        fillColor: BarroTheme.background,
        hintText: '0.00',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: BarroTheme.border),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: BarroTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: BarroTheme.primary, width: 2),
        ),
      );

  Widget _construirError() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: const Color(0xFFFDECEA),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFF6C9C4), width: 7),
          ),
          child: const Icon(
            Icons.cloud_off_rounded,
            size: 36,
            color: BarroTheme.error,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'No pudimos cargar la caja',
          textAlign: TextAlign.center,
          style: BarroTheme.type(18, 24, weight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: BarroTheme.type(14, 21, color: BarroTheme.secondary),
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: _cargar,
          style: FilledButton.styleFrom(
            backgroundColor: BarroTheme.primary,
            minimumSize: const Size(180, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reintentar'),
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
        const SizedBox(height: 22),
        CorteTitulo(
          icono: Icons.lock_outline_rounded,
          titulo: 'Caja cerrada',
          subtitulo: widget.onRegistrarVenta == null
              ? 'Abre un turno para registrar movimientos'
              : 'Abre un corte de caja para registrar ventas.',
          // El historial es información financiera: solo el propietario (HU-05).
          accion: widget.esPropietario
              ? _botonHistorial('Ver historial de cortes')
              : null,
        ),
        const SizedBox(height: 20),
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
        const SizedBox(height: 16),
        // Estado visual de la caja.
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF6E5),
            border: Border.all(color: const Color(0xFFF2D59B)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const CorteIcono(
                Icons.point_of_sale_outlined,
                color: Color(0xFF9A6200),
                fondo: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No hay un turno activo. Cuenta el efectivo del cajón y abre la caja para empezar.',
                  style: BarroTheme.type(
                    13,
                    19,
                    color: const Color(0xFF6B4500),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CorteSeccion(
          icono: Icons.savings_outlined,
          titulo: 'Fondo inicial en caja',
          subtitulo: 'Efectivo para dar cambio',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ingresa la cantidad de efectivo disponible en el cajón para dar cambio e iniciar el día.',
                style: BarroTheme.type(13, 19, color: BarroTheme.secondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _aperturaCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                style: BarroTheme.type(20, 26, weight: FontWeight.w700),
                decoration: _decoracionMonto(icono: Icons.payments_outlined),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _botonPrincipal(
          texto: 'Abrir turno de caja',
          icono: Icons.lock_open_rounded,
          onPressed: _guardando ? null : _abrirCaja,
          cargando: _guardando,
        ),
        if (widget.esPropietario) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _abrirHistorial,
            icon: const Icon(Icons.history_rounded),
            label: const Text('Ver historial de cortes anteriores'),
            style: OutlinedButton.styleFrom(
              foregroundColor: BarroTheme.primary,
              backgroundColor: Colors.white,
              side: const BorderSide(color: BarroTheme.border),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
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
          const SizedBox(height: 22),
          CorteTitulo(
            icono: Icons.point_of_sale_rounded,
            titulo: 'Corte de caja',
            subtitulo: 'Revisa los movimientos del día',
            accion: widget.esPropietario
                ? _botonHistorial('Historial de cortes')
                : null,
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
          const SizedBox(height: 16),

          if (widget.onRegistrarVenta != null && !corte.cerrado) ...[
            _botonPrincipal(
              texto: 'Registrar venta',
              icono: Icons.add_shopping_cart_rounded,
              onPressed: _guardando || _abriendoVenta ? null : _registrarVenta,
            ),
            const SizedBox(height: 16),
          ],

          // Tarjeta destacada: total esperado y desglose por método.
          _tarjetaTotales(corte),
          const SizedBox(height: 16),

          // Tabla: Resumen del día (Efectivo vs Tarjeta)
          CorteSeccion(
            icono: Icons.receipt_long_outlined,
            titulo: 'Resumen del día',
            subtitulo: 'Movimientos por método de pago',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _encabezadoTabla(),
                const SizedBox(height: 6),
                _filaResumen(
                  'Ventas',
                  Icons.shopping_bag_outlined,
                  formatDinero(corte.ventasEfectivo.totalVentas),
                  formatDinero(corte.ventasTarjeta.totalVentas),
                ),
                _filaResumen(
                  'Anticipos',
                  Icons.schedule_rounded,
                  formatDinero(corte.ventasEfectivo.anticipos),
                  formatDinero(corte.ventasTarjeta.anticipos),
                ),
                _filaResumen(
                  'Liquidaciones',
                  Icons.task_alt_rounded,
                  formatDinero(corte.ventasEfectivo.liquidaciones),
                  formatDinero(corte.ventasTarjeta.liquidaciones),
                ),
                _filaResumen(
                  'Cancelaciones',
                  Icons.cancel_outlined,
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
                const SizedBox(height: 6),
                _filaResumen(
                  'Neto del día',
                  Icons.calculate_outlined,
                  formatDinero(corte.ventasEfectivo.subtotalNeto),
                  formatDinero(corte.ventasTarjeta.subtotalNeto),
                  destacada: true,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: corteSuave,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.trending_up_rounded,
                        size: 20,
                        color: BarroTheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Total neto',
                          style: BarroTheme.type(
                            15,
                            20,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        formatDinero(corte.totalNetoDia),
                        style: BarroTheme.type(
                          18,
                          24,
                          weight: FontWeight.w800,
                          color: BarroTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Enlace a Screen 2 (Productos y movimientos)
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: _abrirDetalleDia,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: BarroTheme.border),
                ),
                child: Row(
                  children: [
                    const CorteIcono(Icons.inventory_2_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ver productos y movimientos',
                            style: BarroTheme.type(
                              14,
                              19,
                              weight: FontWeight.w700,
                              color: BarroTheme.primary,
                            ),
                          ),
                          Text(
                            '${corte.productos.length} ${corte.productos.length == 1 ? 'producto vendido' : 'productos vendidos'} · pagos y cancelaciones',
                            style: BarroTheme.type(
                              12,
                              17,
                              color: BarroTheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: BarroTheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Card: Revisión de efectivo (Arqueo)
          CorteSeccion(
            icono: Icons.fact_check_outlined,
            titulo: 'Revisión de efectivo',
            subtitulo: 'Cuenta el efectivo del cajón',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _datoArqueo(
                        etiqueta: 'Fondo inicial',
                        valor: corte.montoInicial,
                        icono: Icons.savings_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: _datoArqueo(
                        etiqueta: 'Efectivo esperado',
                        valor: corte.efectivoEsperado,
                        icono: Icons.account_balance_wallet_outlined,
                        destacado: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Efectivo contado',
                  style: BarroTheme.type(13, 18, weight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _contadoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  style: BarroTheme.type(20, 26, weight: FontWeight.w700),
                  decoration: _decoracionMonto(icono: Icons.payments_outlined),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: BadgeDiferencia(diferencia: _diferencia),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Pie de pantalla: Responsable y sesión actual
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.verified_user_outlined,
                size: 15,
                color: BarroTheme.placeholder,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Realiza: ${corte.usuarioNombre} · Sesión actual',
                  textAlign: TextAlign.center,
                  style: BarroTheme.type(12, 16, color: BarroTheme.placeholder),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Botón Realizar Corte
          _botonPrincipal(
            texto: 'Realizar corte',
            icono: Icons.content_cut_rounded,
            onPressed: _guardando ? null : _confirmarYCerrarCorte,
            cargando: _guardando,
          ),
        ],
      ),
    );
  }

  /// Tarjeta blanca: total esperado en caja y desglose por método de pago
  /// (efectivo en verde, tarjeta en azul).
  Widget _tarjetaTotales(CorteCaja corte) {
    final efectivo = corte.totalEfectivo > 0 ? corte.totalEfectivo : 0.0;
    final tarjeta = corte.totalTarjeta > 0 ? corte.totalTarjeta : 0.0;
    final suma = efectivo + tarjeta;
    double? parte(double v) => suma <= 0 ? null : v / suma;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BarroTheme.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CorteIcono(
                Icons.account_balance_wallet_outlined,
                tamano: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Total esperado en caja',
                  style: BarroTheme.type(17, 24, weight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatDinero(corte.totalEstimado),
              style: BarroTheme.type(32, 40, weight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _totalMetodo(
                    'Efectivo',
                    corte.totalEfectivo,
                    Icons.payments_outlined,
                    color: const Color(0xFF1F6B45),
                    fondo: const Color(0xFFE6F2EA),
                    proporcion: parte(efectivo),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _totalMetodo(
                    'Tarjeta',
                    corte.totalTarjeta,
                    Icons.credit_card_rounded,
                    color: corteAzul,
                    fondo: const Color(0xFFE7EEF8),
                    proporcion: parte(tarjeta),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalMetodo(
    String label,
    double valor,
    IconData icono, {
    required Color color,
    required Color fondo,
    double? proporcion,
  }) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: fondo,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CorteIcono(icono, color: color, fondo: Colors.white, tamano: 32),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: BarroTheme.type(15, 21, weight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatDinero(valor),
            style: BarroTheme.type(20, 26, weight: FontWeight.w800),
          ),
        ),
        if (proporcion != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: proporcion.clamp(0, 1).toDouble(),
              minHeight: 7,
              color: color,
              backgroundColor: Colors.white,
              semanticsLabel: 'Proporción de $label',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(proporcion * 100).round()} % del total',
            style: BarroTheme.type(11, 16, color: BarroTheme.secondary),
          ),
        ],
      ],
    ),
  );

  Widget _datoArqueo({
    required String etiqueta,
    required double valor,
    required IconData icono,
    bool destacado = false,
  }) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: destacado ? corteSuave : BarroTheme.background,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: destacado
            ? BarroTheme.primary.withValues(alpha: 0.25)
            : BarroTheme.border,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icono,
              size: 16,
              color: destacado ? BarroTheme.primary : BarroTheme.secondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                etiqueta,
                maxLines: 2,
                softWrap: true,
                style: BarroTheme.type(12, 16, color: BarroTheme.secondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatDinero(valor),
            style: BarroTheme.type(
              17,
              22,
              weight: FontWeight.w700,
              color: destacado ? BarroTheme.primary : BarroTheme.text,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _encabezadoTabla() {
    Widget columna(String texto, IconData icono, Color color) => Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Icon(icono, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            texto,
            overflow: TextOverflow.ellipsis,
            style: BarroTheme.type(
              12,
              16,
              weight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: BarroTheme.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
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
            child: columna('Efectivo', Icons.payments_outlined, corteVerde),
          ),
          Expanded(
            flex: 3,
            child: columna('Tarjeta', Icons.credit_card_rounded, corteAzul),
          ),
        ],
      ),
    );
  }

  Widget _filaResumen(
    String concepto,
    IconData icono,
    String efectivo,
    String tarjeta, {
    bool destacada = false,
    Color? colorEfectivo,
    Color? colorTarjeta,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: BoxDecoration(
      color: destacada ? BarroTheme.background : null,
      border: destacada
          ? Border.all(color: BarroTheme.border)
          : const Border(bottom: BorderSide(color: Color(0xFFF0E6E1))),
      borderRadius: destacada ? BorderRadius.circular(10) : null,
    ),
    child: Row(
      children: [
        Expanded(
          flex: 4,
          child: Row(
            children: [
              Icon(
                icono,
                size: 16,
                color: destacada ? BarroTheme.primary : BarroTheme.placeholder,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  concepto,
                  style: BarroTheme.type(
                    13,
                    18,
                    weight: destacada ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
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
              weight: destacada ? FontWeight.w700 : FontWeight.w600,
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
              weight: destacada ? FontWeight.w700 : FontWeight.w600,
              color: colorTarjeta ?? BarroTheme.text,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Confirmación cuando el efectivo contado no coincide con el esperado.
/// Devuelve `true` para confirmar el corte y `false` para revisar.
class _DiferenciaDialog extends StatelessWidget {
  const _DiferenciaDialog({
    required this.diferencia,
    required this.esperado,
    required this.contado,
  });

  final double diferencia;
  final double esperado;
  final double contado;

  Widget _fila(String etiqueta, String valor, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            etiqueta,
            style: BarroTheme.type(13, 19, color: BarroTheme.secondary),
          ),
        ),
        Text(
          valor,
          style: BarroTheme.type(
            14,
            19,
            weight: FontWeight.w700,
            color: color ?? BarroTheme.text,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final sobrante = diferencia > 0;
    final color = sobrante ? const Color(0xFF1B65A4) : BarroTheme.error;
    return Dialog(
      backgroundColor: BarroTheme.background,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF6E5),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFF2D59B),
                      width: 6,
                    ),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    size: 32,
                    color: Color(0xFF9A6200),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Diferencia detectada',
                textAlign: TextAlign.center,
                style: BarroTheme.type(21, 27, weight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Hay una diferencia de ${formatDinero(diferencia)} entre el efectivo contado y el esperado. ¿Estás seguro de que deseas realizar el corte de caja con este monto?',
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
                child: Column(
                  children: [
                    _fila('Efectivo esperado', formatDinero(esperado)),
                    _fila('Efectivo contado', formatDinero(contado)),
                    const Divider(color: BarroTheme.border),
                    _fila(
                      sobrante ? 'Sobrante' : 'Faltante',
                      '${sobrante ? '+' : ''}${formatDinero(diferencia)}',
                      color: color,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: BarroTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.check_rounded, size: 20),
                label: const Text('Confirmar corte'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: BarroTheme.secondary,
                  side: const BorderSide(color: BarroTheme.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(false),
                icon: const Icon(Icons.edit_outlined, size: 20),
                label: const Text('Revisar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
