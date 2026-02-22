import 'package:cloud_firestore/cloud_firestore.dart';

class MusicoEnBanda {
  final String id;
  final DateTime fechaAlta;
  final int? anioPrimeraSemanaSanta;
  final String? instrumento;
  final String? categoria;
  final bool activo;

  // Constructor
  MusicoEnBanda({
    required this.id,
    required this.fechaAlta,
    this.anioPrimeraSemanaSanta,
    this.instrumento,
    this.categoria,
    required this.activo,
  });

  /// Crear desde un Map genérico
  factory MusicoEnBanda.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final fechaAltaTimestamp = data['fechaAlta'] as Timestamp?;
    return MusicoEnBanda(
      id: doc.id,
      fechaAlta: fechaAltaTimestamp?.toDate() ?? DateTime.now(),
      anioPrimeraSemanaSanta: data['anioPrimeraSemanaSanta'] as int?,
      instrumento: data['instrumento'] as String?,
      categoria: data['categoria'] as String?,
      activo: data['activo'] ?? true,
    );
  }

  /// Convertir a Map para subir a la base de datos
  Map<String, dynamic> toFirestore() {
    return {
      'fechaAlta': Timestamp.fromDate(fechaAlta),
      'anioPrimeraSemanaSanta': anioPrimeraSemanaSanta,
      'instrumento': instrumento,
      'categoria': categoria,
      'activo': activo,
    };
  }
}
