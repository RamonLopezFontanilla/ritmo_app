class Musico {
  final String uid;
  final String nombre;
  final bool activo;
  final String? instrumentoId;
  final String instrumentoNombre;
  final String? categoriaId;
  final String categoriaNombre;

  // Constructor
  Musico({
    required this.uid,
    required this.nombre,
    required this.activo,
    required this.instrumentoId,
    required this.instrumentoNombre,
    this.categoriaId,
    required this.categoriaNombre,
  });

  /// Crear desde un Map genérico
  factory Musico.fromMap({
    required String uid,
    required Map<String, dynamic> data,
    required Map<String, dynamic> usuario,
    required Map<String, String> instrumentosMap,
    required Map<String, Map<String, String>> categoriasPorInstrumento,
  }) {
    final instrumentoId = data['instrumento']?.toString();
    final categoriaId = data['categoria']?.toString();

    return Musico(
      uid: uid,
      nombre: (usuario['nombre'] ?? 'Sin nombre').toString(),
      activo: data['activo'] ?? true,
      instrumentoId: instrumentoId,
      instrumentoNombre: instrumentoId != null
          ? instrumentosMap[instrumentoId] ?? 'Sin instrumento'
          : 'Sin instrumento',
      categoriaId: categoriaId,
      categoriaNombre: categoriasPorInstrumento[instrumentoId]?[categoriaId] ?? '',
    );
  }

  /// Convertir a Map para subir a la base de datos
  Map<String, dynamic> toMap() {
    return {'nombre': nombre, 'activo': activo, 'instrumento': instrumentoId, 'categoria': categoriaId};
  }

  String get instrumento => instrumentoNombre;
}
