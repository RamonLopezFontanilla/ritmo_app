class EventoAFichar {
  final String id;
  final String descripcion;
  final DateTime inicio;
  final DateTime? fin;
  final String? ubicacionNombre;

  // Constructor
  EventoAFichar({required this.id, required this.descripcion, required this.inicio, this.fin, this.ubicacionNombre});

  // Obtener si el evento está activo para fichar
  bool get estaActivo =>
      fin == null ? DateTime.now().isAfter(inicio) : DateTime.now().isAfter(inicio) && DateTime.now().isBefore(fin!);

  // Obtener la hora de inicio del evento
  String get horaInicioTexto => "${inicio.hour.toString().padLeft(2, '0')}:${inicio.minute.toString().padLeft(2, '0')}";

  // Obtener la hora de fin del evento
  String get horaFinTexto {
    if (fin == null) return "--:--";
    return "${fin!.hour.toString().padLeft(2, '0')}:${fin!.minute.toString().padLeft(2, '0')}";
  }
}
