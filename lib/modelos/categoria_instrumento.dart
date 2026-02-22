class CategoriaInstrumento {
  final String categoriaId;
  final String nombre;
  final String carpetaPartituras;

  // Constructor
  CategoriaInstrumento({required this.categoriaId, required this.nombre, required this.carpetaPartituras});

  /// Crear desde un Map genérico
  factory CategoriaInstrumento.fromMap(Map<String, dynamic> map) {
    return CategoriaInstrumento(
      categoriaId: map['categoriaId'] ?? '',
      nombre: map['nombre'] ?? '',
      carpetaPartituras: map['carpetaPartituras'] ?? '',
    );
  }

  /// Convertir a Map para subir a la base de datos
  Map<String, dynamic> toMap() {
    return {'categoriaId': categoriaId, 'nombre': nombre, 'carpetaPartituras': carpetaPartituras};
  }
}
