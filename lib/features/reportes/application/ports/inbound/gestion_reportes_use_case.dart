import '../../../domain/reporte_contable.dart';

abstract interface class GestionReportesUseCase {
  Future<ReporteContable> consultar(ConsultaReporte consulta);
  Future<bool> exportar(ConsultaReporte consulta);
}
