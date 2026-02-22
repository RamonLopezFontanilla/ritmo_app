class Temporada {
  final String id;
  final String nombre;
  final DateTime fechaInicio;
  final DateTime fechaFin;

  // Constructor
  const Temporada({required this.id, required this.nombre, required this.fechaInicio, required this.fechaFin});

  bool estaActiva(DateTime fecha) {
    return (fecha.isAfter(fechaInicio) || fecha.isAtSameMomentAs(fechaInicio)) &&
        (fecha.isBefore(fechaFin) || fecha.isAtSameMomentAs(fechaFin));
  }

  /// Crear temporada
  factory Temporada.crear({required String id, required DateTime inicio, required DateTime fin}) {
    final nombre = "${inicio.year}/${fin.year.toString().substring(2)}";
    return Temporada(id: id, nombre: nombre, fechaInicio: inicio, fechaFin: fin);
  }

  /// Crear desde un Map genérico
  factory Temporada.fromMap(String id, Map<String, dynamic> map) {
    // El mapa ya debe contener DateTime puros
    return Temporada(
      id: id,
      nombre: map['nombre'] ?? '',
      fechaInicio: map['fechaInicio'] as DateTime,
      fechaFin: map['fechaFin'] as DateTime,
    );
  }

  /// Convertir a Map para subir a la base de datos
  Map<String, dynamic> toMap() {
    return {'nombre': nombre, 'fechaInicio': fechaInicio, 'fechaFin': fechaFin};
  }

  /// Obtener si el rango de fechas de una temporada es válido
  bool get esRangoValido => !fechaFin.isBefore(fechaInicio);

  /// Comprobar si se solapan temporadas
  bool solapaCon(Temporada otra) {
    return !(fechaFin.isBefore(otra.fechaInicio) || fechaInicio.isAfter(otra.fechaFin));
  }
}
