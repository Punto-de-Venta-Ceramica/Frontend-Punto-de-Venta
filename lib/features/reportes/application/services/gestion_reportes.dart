import '../../domain/reporte_contable.dart';
import '../ports/inbound/gestion_reportes_use_case.dart';
import '../ports/outbound/exportador_reportes.dart';
import '../ports/outbound/reportes_gateway.dart';

class GestionReportes implements GestionReportesUseCase {
  const GestionReportes(this._gateway, this._exportador);

  final ReportesGateway _gateway;
  final ExportadorReportes _exportador;

  @override
  Future<ReporteContable> consultar(ConsultaReporte consulta) =>
      _gateway.consultar(consulta);

  @override
  Future<bool> exportar(ConsultaReporte consulta) async {
    if (!consulta.periodo.permiteExportar) {
      throw const ReporteFailure('Selecciona el periodo semanal o mensual.');
    }
    return _exportador.guardar(await _gateway.descargar(consulta));
  }
}
