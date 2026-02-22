class Partitura {
  final String id;
  final String titulo;
  final String archivo;
  final String genero;

  // Constructor
  Partitura({required this.id, required this.titulo, required this.archivo, required this.genero});

  /// Crear desde un Map genérico
  factory Partitura.fromMap(String id, Map<String, dynamic> map) =>
      Partitura(id: id, titulo: map['titulo'] ?? '', archivo: map['archivo'] ?? '', genero: map['genero'] ?? '');

  /// Convertir a Map para subir a la base de datos
  Map<String, dynamic> toMap() => {'titulo': titulo, 'archivo': archivo, 'genero': genero};
}
