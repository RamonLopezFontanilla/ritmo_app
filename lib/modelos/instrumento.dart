import 'package:ritmo_app/modelos/categoria_instrumento.dart';

class Instrumento {
  final String id;
  final String nombre;
  final String carpetaPartituras;
  final String iconoUrl;
  final List<CategoriaInstrumento> categorias;

  // Constructor
  Instrumento({
    required this.id,
    required this.nombre,
    required this.carpetaPartituras,
    required this.iconoUrl,
    required this.categorias,
  });

  /// Crear desde un Map genérico
  factory Instrumento.fromMap(String id, Map<String, dynamic> data) {
    final List categoriasRaw = data['categorias'] as List? ?? [];

    return Instrumento(
      id: id,
      nombre: data['nombre'] ?? '',
      carpetaPartituras: data['carpetaPartituras'] ?? '',
      iconoUrl: data['iconoUrl'] ?? '',
      categorias: categoriasRaw.map((e) => CategoriaInstrumento.fromMap(e as Map<String, dynamic>)).toList(),
    );
  }

  /// Convertir a Map para subir a la base de datos
  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'carpetaPartituras': carpetaPartituras,
      'iconoUrl': iconoUrl,
      'categorias': categorias.map((c) => c.toMap()).toList(),
    };
  }
}
