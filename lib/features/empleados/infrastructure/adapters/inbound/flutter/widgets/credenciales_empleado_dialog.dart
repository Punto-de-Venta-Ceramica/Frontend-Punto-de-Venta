import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';
import 'package:punto_de_venta/features/empleados/domain/empleado.dart';

class CredencialesEmpleadoDialog extends StatefulWidget {
  const CredencialesEmpleadoDialog({
    required this.empleadoCreado,
    super.key,
  });

  final EmpleadoCreado empleadoCreado;

  @override
  State<CredencialesEmpleadoDialog> createState() =>
      _CredencialesEmpleadoDialogState();
}

class _CredencialesEmpleadoDialogState
    extends State<CredencialesEmpleadoDialog> {
  bool _copiado = false;

  Future<void> _copiarCredenciales() async {
    final texto =
        'Credenciales de acceso a BarroControl:\n'
        'Usuario: ${widget.empleadoCreado.correoElectronico}\n'
        'Contraseña: ${widget.empleadoCreado.passwordGenerada}';
    await Clipboard.setData(ClipboardData(text: texto));
    if (!mounted) return;
    setState(() => _copiado = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Credenciales copiadas al portapapeles.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    backgroundColor: Colors.white,
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFECF7F0),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: BarroTheme.success,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '¡Empleado registrado!',
              textAlign: TextAlign.center,
              style: BarroTheme.type(22, 28, weight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'El empleado ${widget.empleadoCreado.nombre} fue dado de alta. Comparte sus credenciales de acceso:',
              textAlign: TextAlign.center,
              style: BarroTheme.type(14, 20, color: BarroTheme.secondary),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF6F3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: BarroTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CORREO / USUARIO',
                    style: BarroTheme.type(
                      11,
                      15,
                      weight: FontWeight.w700,
                      color: BarroTheme.secondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    widget.empleadoCreado.correoElectronico,
                    style: BarroTheme.type(
                      15,
                      21,
                      weight: FontWeight.w600,
                      color: BarroTheme.text,
                    ),
                  ),
                  const Divider(height: 24, color: BarroTheme.border),
                  Text(
                    'CONTRASEÑA GENERADA',
                    style: BarroTheme.type(
                      11,
                      15,
                      weight: FontWeight.w700,
                      color: BarroTheme.secondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: BarroTheme.border),
                          ),
                          child: SelectableText(
                            widget.empleadoCreado.passwordGenerada,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: BarroTheme.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Copiar contraseña',
                        icon: Icon(
                          _copiado ? Icons.check : Icons.copy_rounded,
                          color: _copiado
                              ? BarroTheme.success
                              : BarroTheme.primary,
                        ),
                        onPressed: _copiarCredenciales,
                      ),
                    ],
                  ),
                  if (widget.empleadoCreado.sucursalNombre != null &&
                      widget.empleadoCreado.sucursalNombre!.isNotEmpty) ...[
                    const Divider(height: 24, color: BarroTheme.border),
                    Text(
                      'SUCURSAL ASIGNADA',
                      style: BarroTheme.type(
                        11,
                        15,
                        weight: FontWeight.w700,
                        color: BarroTheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.empleadoCreado.sucursalNombre!,
                      style: BarroTheme.type(
                        14,
                        20,
                        weight: FontWeight.w600,
                        color: BarroTheme.text,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: BarroTheme.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                minimumSize: const Size.fromHeight(44),
                foregroundColor: BarroTheme.primary,
              ),
              icon: Icon(
                _copiado ? Icons.check_rounded : Icons.copy_rounded,
                size: 18,
              ),
              label: Text(
                _copiado ? 'Credenciales copiadas' : 'Copiar credenciales',
                style: BarroTheme.type(13, 18, weight: FontWeight.w600),
              ),
              onPressed: _copiarCredenciales,
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: BarroTheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Entendido y continuar',
                style: BarroTheme.type(
                  14,
                  20,
                  weight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
