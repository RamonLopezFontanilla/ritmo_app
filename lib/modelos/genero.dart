class Genero {
  final String id;
  final String nombre;

  // Constructor
  Genero({required this.id, required this.nombre});

  /// Crear desde un Map genérico
  factory Genero.fromMap(String id, Map<String, dynamic> map) {
    return Genero(id: id, nombre: map['nombre'] ?? '');
  }

  /// Convertir a Map para subir a la base de datos
  Map<String, dynamic> toMap() {
    return {'nombre': nombre};
  }
}
