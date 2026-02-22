class Ubicacion {
  final String id;
  final String nombre;
  final String direccion;
  final double latitud;
  final double longitud;

  // Constructor
  Ubicacion({
    required this.id,
    required this.nombre,
    required this.direccion,
    required this.latitud,
    required this.longitud,
  });

  /// Crear desde un Map genérico
  factory Ubicacion.fromMap(String id, Map<String, dynamic> data) {
    return Ubicacion(
      id: id,
      nombre: data['nombre'] ?? '',
      direccion: data['direccion'] ?? '',
      latitud: (data['latitud'] ?? 0.0).toDouble(),
      longitud: (data['longitud'] ?? 0.0).toDouble(),
    );
  }

  /// Convertir a Map para subir a la base de datos
  Map<String, dynamic> toMap() {
    return {'nombre': nombre, 'direccion': direccion, 'latitud': latitud, 'longitud': longitud};
  }
}
