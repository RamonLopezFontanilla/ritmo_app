class AsistenciaMusico {
  final String id;
  final String nombre;
  final String instrumentoId;
  final String categoriaId;
  bool presente;

  // Constructor
  AsistenciaMusico({
    required this.id,
    required this.nombre,
    required this.instrumentoId,
    required this.categoriaId,
    this.presente = false,
  });

  /// Crear desde un Map genérico
  factory AsistenciaMusico.fromMap(String id, Map<String, dynamic> data, {bool presente = false}) {
    return AsistenciaMusico(
      id: id,
      nombre: data['nombre'] ?? 'Sin nombre',
      instrumentoId: data['instrumento'] ?? '',
      categoriaId: data['categoria'] ?? '',
      presente: presente,
    );
  }

  /// Convertir a Map para subir a la base de datos
  Map<String, dynamic> toMap(String eventoId, DateTime momentoFichaje) {
    return {'eventoId': eventoId, 'musicoId': id, 'momentoFichaje': momentoFichaje};
  }
}
