import '../../../domain/reporte_contable.dart';

abstract interface class ExportadorReportes {
  Future<bool> guardar(ArchivoReporte archivo);
}
