class PrevisionAsistencia {
  final String uid;
  final bool asistira;
  final String? motivo;
  final String? otrosDetalle;
  final DateTime? timestamp;

  // Constructor
  const PrevisionAsistencia({
    required this.uid,
    required this.asistira,
    this.motivo,
    this.otrosDetalle,
    this.timestamp,
  });

  /// Crear desde un Map genérico
  factory PrevisionAsistencia.fromMap(String uid, Map<String, dynamic> data) {
    return PrevisionAsistencia(
      uid: uid,
      asistira: data['asistira'] ?? false,
      motivo: data['motivo'],
      otrosDetalle: data['otros_detalle'],
      timestamp: data['timestamp'] != null ? (data['timestamp'] as dynamic).toDate() : null,
    );
  }

  /// Convertir a Map para subir a la base de datos
  Map<String, dynamic> toMap() {
    return {'asistira': asistira, 'motivo': motivo, 'otros_detalle': otrosDetalle, 'timestamp': timestamp};
  }
}
