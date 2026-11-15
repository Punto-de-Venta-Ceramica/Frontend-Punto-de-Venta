import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';

import '../../../../application/ports/outbound/exportador_reportes.dart';
import '../../../../domain/reporte_contable.dart';

class ExportadorXlsx implements ExportadorReportes {
  const ExportadorXlsx();

  @override
  Future<bool> guardar(ArchivoReporte archivo) async {
    try {
      final guardar = kIsWeb
          ? FileSaver.instance.saveFile
          : FileSaver.instance.saveAs;
      final destino = await guardar(
        name: archivo.nombre,
        bytes: archivo.bytes,
        fileExtension: 'xlsx',
        mimeType: MimeType.custom,
        customMimeType: ArchivoReporte.tipoExcel,
      );
      return destino != null && destino.isNotEmpty;
    } on Exception {
      throw const ReporteFailure(
        'No se pudo guardar el reporte en este dispositivo.',
      );
    }
  }
}
