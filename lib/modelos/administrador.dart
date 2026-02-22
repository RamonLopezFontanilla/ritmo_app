class Administrador {
  final String uid;
  final String email;
  final List<String> bandasId;
  final String nombre;

  // Constructor
  Administrador({required this.uid, required this.email, this.bandasId = const [], this.nombre = "Administrador"});

  /// Crear desde un Map genérico
  factory Administrador.fromMap(String id, Map<String, dynamic> data) {
    return Administrador(
      uid: id,
      email: data['email'] ?? '',
      bandasId: List<String>.from(data['bandasId'] ?? []),
      nombre: data['nombre'] ?? 'Administrador',
    );
  }

  /// Convertir a Map para subir a la base de datos
  Map<String, dynamic> toMap() {
    return {'email': email, 'bandasId': bandasId, 'nombre': nombre};
  }
}
