import 'package:cloud_firestore/cloud_firestore.dart';

class Usuario {
  final String id;
  final String email;
  final String nombre;
  final String rol;
  final List<String> bandasId;
  final String? idDispositivo;

  // Constructor
  Usuario({
    required this.id,
    required this.email,
    required this.nombre,
    required this.rol,
    required this.bandasId,
    this.idDispositivo,
  });

  /// Crear desde un Map genérico
  factory Usuario.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Usuario(
      id: doc.id,
      email: data['email'] ?? '',
      nombre: data['nombre'] ?? '',
      rol: data['rol'] ?? 'musico',
      bandasId: List<String>.from(data['bandasId'] ?? []),
      idDispositivo: data['deviceId'],
    );
  }
}
