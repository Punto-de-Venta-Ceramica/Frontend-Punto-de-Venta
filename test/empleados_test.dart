import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punto_de_venta/features/empleados/application/ports/inbound/gestion_empleados_use_case.dart';
import 'package:punto_de_venta/features/empleados/domain/empleado.dart';
import 'package:punto_de_venta/features/empleados/infrastructure/adapters/inbound/flutter/empleados_page.dart';
import 'package:punto_de_venta/features/empleados/infrastructure/adapters/inbound/flutter/nuevo_empleado_page.dart';
import 'package:punto_de_venta/features/empleados/infrastructure/adapters/inbound/flutter/widgets/credenciales_empleado_dialog.dart';
import 'package:punto_de_venta/features/empleados/infrastructure/adapters/inbound/flutter/widgets/eliminar_empleado_dialog.dart';

class GestionEmpleadosFake implements GestionEmpleadosUseCase {
  List<Empleado> empleados = [
    const Empleado(
      id: 1,
      negocioId: 10,
      nombre: 'María',
      apellidoP: 'López',
      correoElectronico: 'maria.lopez@correo.com',
      sucursalId: 100,
      sucursalNombre: 'Sucursal Centro',
      asignado: true,
    ),
    const Empleado(
      id: 2,
      negocioId: 10,
      nombre: 'Jorge',
      apellidoP: 'Ramírez',
      correoElectronico: 'jorge.ramirez@correo.com',
      asignado: false,
    ),
  ];

  List<NegocioEmpleado> listaNegocios = [
    const NegocioEmpleado(id: 10, nombre: 'Cerámica del Centro'),
  ];

  List<SucursalEmpleado> listaSucursales = [
    const SucursalEmpleado(id: 100, nombre: 'Sucursal Centro'),
    const SucursalEmpleado(id: 101, nombre: 'Sucursal Norte'),
  ];

  int eliminados = 0;
  int registrados = 0;

  @override
  Future<List<NegocioEmpleado>> negocios() async => listaNegocios;

  @override
  Future<List<SucursalEmpleado>> sucursales(int negocioId) async =>
      listaSucursales;

  @override
  Future<List<Empleado>> listar(
    int negocioId, {
    bool incluirAsignacion = true,
  }) async => empleados;

  @override
  Future<EmpleadoCreado> registrar(NuevoEmpleado datos) async {
    registrados++;
    final creado = EmpleadoCreado(
      id: 3,
      negocioId: datos.negocioId,
      nombre: datos.nombre,
      correoElectronico: datos.correoElectronico,
      passwordGenerada: 'ClaveSegura123!',
      sucursalNombre: datos.sucursalId != null ? 'Sucursal Centro' : null,
    );
    empleados.add(
      Empleado(
        id: 3,
        negocioId: datos.negocioId,
        nombre: datos.nombre,
        apellidoP: datos.apellidoP,
        apellidoM: datos.apellidoM,
        correoElectronico: datos.correoElectronico,
        sucursalId: datos.sucursalId,
        sucursalNombre: creado.sucursalNombre,
        asignado: datos.sucursalId != null,
      ),
    );
    return creado;
  }

  @override
  Future<Empleado> asignarSucursal({
    required int negocioId,
    required int empleadoId,
    required int? sucursalId,
  }) async {
    final sucursal = sucursalId == null
        ? null
        : listaSucursales.firstWhere((s) => s.id == sucursalId);
    final index = empleados.indexWhere((e) => e.id == empleadoId);
    final actualizado = empleados[index].copyWith(
      sucursalId: sucursalId,
      sucursalNombre: sucursal?.nombre,
      asignado: sucursalId != null,
      limpiarSucursal: sucursalId == null,
    );
    empleados[index] = actualizado;
    return actualizado;
  }

  @override
  Future<void> eliminar(int negocioId, int empleadoId) async {
    eliminados++;
    empleados.removeWhere((e) => e.id == empleadoId);
  }
}

void main() {
  group('Dominio Empleado', () {
    test('valida campos obligatorios y formato de correo', () {
      final invalido = const NuevoEmpleado(
        negocioId: 1,
        nombre: '',
        correoElectronico: 'correo-invalido',
      ).validar();
      expect(invalido.containsKey('nombre'), isTrue);
      expect(invalido.containsKey('correoElectronico'), isTrue);

      final valido = const NuevoEmpleado(
        negocioId: 1,
        nombre: 'Carlos',
        apellidoP: 'Méndez',
        correoElectronico: 'carlos@ejemplo.com',
      ).validar();
      expect(valido.isEmpty, isTrue);
    });

    test('genera nombre completo e inicial correctamente', () {
      const emp = Empleado(
        id: 1,
        negocioId: 1,
        nombre: 'María',
        apellidoP: 'López',
        apellidoM: 'García',
        correoElectronico: 'maria@test.com',
      );
      expect(emp.nombreCompleto, 'María López García');
      expect(emp.inicial, 'M');
    });
  });

  group('Pantallas de Empleados', () {
    testWidgets('lista empleados con sucursal asignada e iniciales', (
      tester,
    ) async {
      final fake = GestionEmpleadosFake();
      await tester.pumpWidget(
        MaterialApp(
          home: EmpleadosPage(
            gestion: fake,
            negocioInicial: const NegocioEmpleado(
              id: 10,
              nombre: 'Cerámica del Centro',
            ),
            onSesionExpirada: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Empleados'), findsOneWidget);
      expect(find.text('2 empleados en tu negocio'), findsOneWidget);
      expect(find.text('María López'), findsOneWidget);
      expect(find.text('maria.lopez@correo.com'), findsOneWidget);
      expect(find.text('Sucursal Centro'), findsOneWidget);
      expect(find.text('Jorge Ramírez'), findsOneWidget);
      expect(find.text('Sin sucursal asignada'), findsOneWidget);
    });

    testWidgets('diálogo de confirmación de eliminación ejecuta delete', (
      tester,
    ) async {
      final fake = GestionEmpleadosFake();
      await tester.pumpWidget(
        MaterialApp(
          home: EmpleadosPage(
            gestion: fake,
            negocioInicial: const NegocioEmpleado(
              id: 10,
              nombre: 'Cerámica del Centro',
            ),
            onSesionExpirada: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap en el primer botón Eliminar
      await tester.tap(find.text('Eliminar').first);
      await tester.pumpAndSettle();

      expect(find.text('¿Eliminar empleado?'), findsOneWidget);
      expect(find.byType(EliminarEmpleadoDialog), findsOneWidget);

      // Confirmar eliminación
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar empleado'));
      await tester.pumpAndSettle();

      expect(fake.eliminados, 1);
      expect(find.text('1 empleado en tu negocio'), findsOneWidget);
    });

    testWidgets(
      'diálogo de credenciales muestra correo y contraseña generada',
      (tester) async {
        const creado = EmpleadoCreado(
          id: 5,
          negocioId: 10,
          nombre: 'Ana Torres',
          correoElectronico: 'ana.torres@correo.com',
          passwordGenerada: 'ClaveTemp987!',
          sucursalNombre: 'Sucursal Centro',
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CredencialesEmpleadoDialog(empleadoCreado: creado),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('¡Empleado registrado!'), findsOneWidget);
        expect(find.text('ana.torres@correo.com'), findsOneWidget);
        expect(find.text('ClaveTemp987!'), findsOneWidget);
        expect(find.text('Sucursal Centro'), findsOneWidget);
        expect(find.text('Copiar credenciales'), findsOneWidget);
        expect(find.text('Entendido y continuar'), findsOneWidget);
      },
    );

    testWidgets(
      'formulario nuevo empleado valida y registra mostrando credenciales',
      (tester) async {
        final fake = GestionEmpleadosFake();
        await tester.pumpWidget(
          MaterialApp(
            home: NuevoEmpleadoPage(
              gestion: fake,
              negocio: const NegocioEmpleado(
                id: 10,
                nombre: 'Cerámica del Centro',
              ),
              onSesionExpirada: () {},
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Nuevo empleado'), findsOneWidget);

        final boton = find.widgetWithText(FilledButton, 'Registrar empleado');

        // Intentar enviar vacío
        await tester.ensureVisible(boton);
        await tester.tap(boton);
        await tester.pumpAndSettle();

        expect(find.text('El nombre es obligatorio.'), findsOneWidget);
        expect(
          find.text('El correo electrónico es obligatorio.'),
          findsOneWidget,
        );

        // Llenar datos válidos
        await tester.enterText(
          find.widgetWithText(TextField, 'Escribe el nombre'),
          'Laura',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Escribe el apellido paterno'),
          'Soto',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'nombre@correo.com'),
          'laura.soto@correo.com',
        );

        await tester.ensureVisible(boton);
        await tester.tap(boton);
        await tester.pumpAndSettle();

        expect(fake.registrados, 1);
        expect(find.byType(CredencialesEmpleadoDialog), findsOneWidget);
        expect(find.text('ClaveSegura123!'), findsOneWidget);
      },
    );
  });
}
