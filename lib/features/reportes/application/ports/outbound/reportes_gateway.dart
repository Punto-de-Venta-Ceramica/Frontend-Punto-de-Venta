import '../../../domain/reporte_contable.dart';

abstract interface class ReportesGateway {
  Future<ReporteContable> consultar(ConsultaReporte consulta);
  Future<ArchivoReporte> descargar(ConsultaReporte consulta);
}
