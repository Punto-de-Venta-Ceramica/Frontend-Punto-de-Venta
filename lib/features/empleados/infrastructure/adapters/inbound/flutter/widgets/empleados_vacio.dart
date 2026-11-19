import 'package:flutter/material.dart';
import 'package:punto_de_venta/core/infrastructure/theme/barro_theme.dart';

const empleadoSuave = Color(0xFFF7E7DF);

/// Estado vacío cuando no hay empleados que mostrar.
class EmpleadosVacio extends StatelessWidget {
  const EmpleadosVacio({
    required this.mensaje,
    this.titulo = 'Aún no tienes empleados registrados.',
    super.key,
  });
  final String titulo;
  final String mensaje;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('empleados-vacio'),
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: BarroTheme.border),
      borderRadius: BorderRadius.circular(21),
    ),
    child: Column(
      children: [
        SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  color: empleadoSuave,
                  shape: BoxShape.circle,
                ),
              ),
              const Icon(
                Icons.groups_2_outlined,
                size: 46,
                color: BarroTheme.primary,
              ),
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: BarroTheme.border),
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1_rounded,
                    size: 16,
                    color: BarroTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: BarroTheme.type(16, 23, weight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          mensaje,
          textAlign: TextAlign.center,
          style: BarroTheme.type(13, 20, color: BarroTheme.secondary),
        ),
      ],
    ),
  );
}

/// Avatar con la inicial del empleado.
class EmpleadoAvatar extends StatelessWidget {
  const EmpleadoAvatar(this.inicial, {this.tamano = 52, super.key});
  final String inicial;
  final double tamano;

  @override
  Widget build(BuildContext context) => Container(
    width: tamano,
    height: tamano,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFD0694F), BarroTheme.primary],
      ),
      borderRadius: BorderRadius.circular(tamano * 0.32),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33B84D34),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Text(
      inicial,
      style: BarroTheme.type(
        tamano * 0.4,
        tamano * 0.5,
        weight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
  );
}
