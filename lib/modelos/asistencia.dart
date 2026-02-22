class Asistencia {
  final String temporadaId;
  final String eventoId;
  final DateTime momentoFichaje;

  // Constructor
  Asistencia({required this.temporadaId, required this.eventoId, required this.momentoFichaje});

  /// Crear desde un Map genérico
  factory Asistencia.fromMap(Map<String, dynamic> data) {
    return Asistencia(
      temporadaId: data['temporadaId'] ?? '',
      eventoId: data['eventoId'] ?? '',
      momentoFichaje: data['momentoFichaje'] as DateTime,
    );
  }

  /// Convertir a Map para subir a la base de datos
  Map<String, dynamic> toMap() {
    return {'temporadaId': temporadaId, 'eventoId': eventoId, 'momentoFichaje': momentoFichaje};
  }
}
