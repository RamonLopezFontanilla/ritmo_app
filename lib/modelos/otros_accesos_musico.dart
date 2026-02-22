class AccesoInstrumento {
  final String key;
  final String instrumentoId;
  final String? categoriaId;
  final String nombre;

  // Constructor
  AccesoInstrumento({required this.key, required this.instrumentoId, this.categoriaId, required this.nombre});

  /// Crear desde un Map genérico
  factory AccesoInstrumento.fromMap(Map<String, dynamic> map) {
    return AccesoInstrumento(
      key: map['key'],
      instrumentoId: map['instrumentoId'],
      categoriaId: map['categoriaId'],
      nombre: map['nombre'],
    );
  }
}
