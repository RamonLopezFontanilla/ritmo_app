class Evento {
  final String id;
  final String tipo;
  final String descripcion;
  final String ubicacionEventoId;
  final String ubicacionCitaId;
  final DateTime inicio;
  final DateTime fin;
  final String horaInicioTexto;
  final String horaFinTexto;
  final String temporada;
  String? nombreUbicacionEvento;
  String? nombreUbicacionCita;

  // Constructor
  Evento({
    required this.id,
    required this.tipo,
    required this.descripcion,
    required this.ubicacionEventoId,
    required this.ubicacionCitaId,
    required this.inicio,
    required this.fin,
    required this.horaInicioTexto,
    required this.horaFinTexto,
    required this.temporada,
    this.nombreUbicacionEvento,
    this.nombreUbicacionCita,
  });

  /// Crear desde un Map genérico
  factory Evento.fromMap(String id, Map<String, dynamic> data) {
    // Convertimos strings de fecha/hora si existen
    DateTime parseDate(dynamic value, [String? fallback]) {
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
      if (fallback != null && fallback.isNotEmpty) {
        final parsed = DateTime.tryParse(fallback);
        if (parsed != null) return parsed;
      }
      return DateTime.now(); // valor por defecto
    }

    return Evento(
      id: id,
      tipo: data['tipo'] ?? '',
      descripcion: data['descripcion'] ?? '',
      ubicacionEventoId: data['ubicacionEventoId'] ?? '',
      ubicacionCitaId: data['ubicacionCitaId'] ?? '',
      inicio: parseDate(data['inicio'], data['inicioTexto']),
      fin: parseDate(data['fin'], data['finTexto']),
      horaInicioTexto: data['horaInicioTexto'] ?? '',
      horaFinTexto: data['horaFinTexto'] ?? '',
      temporada: data['temporada'] ?? '',
    );
  }
}
