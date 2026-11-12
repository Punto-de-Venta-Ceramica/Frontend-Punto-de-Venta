/// Sucursal en la que trabaja un empleado, con el negocio al que pertenece.
class SucursalAsignada {
  const SucursalAsignada({
    required this.sucursalId,
    required this.sucursal,
    required this.negocioId,
    required this.negocio,
  });

  factory SucursalAsignada.fromJson(Map<String, dynamic> json) {
    final sucursalId = json['sucursalId'];
    final negocioId = json['negocioId'];
    if (sucursalId is! int || negocioId is! int) throw const FormatException();
    return SucursalAsignada(
      sucursalId: sucursalId,
      sucursal: json['sucursal'] as String? ?? 'Sucursal',
      negocioId: negocioId,
      negocio: json['negocio'] as String? ?? 'Negocio',
    );
  }

  final int sucursalId;
  final String sucursal;
  final int negocioId;
  final String negocio;
}
