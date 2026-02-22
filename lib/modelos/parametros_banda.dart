class ParametrosBanda {
  final int distancia;
  final int retraso;
  final String rutaPartituras;

  // Constructor
  const ParametrosBanda({this.distancia = 0, this.retraso = 0, this.rutaPartituras = ''});

  /// Crear desde un Map genérico
  factory ParametrosBanda.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ParametrosBanda();

    return ParametrosBanda(
      distancia: map['distancia'] ?? 0,
      retraso: map['retraso'] ?? 0,
      rutaPartituras: map['rutaPartituras'] ?? '',
    );
  }

  /// Convertir a Map para subir a la base de datos
  Map<String, dynamic> toMap() => {'distancia': distancia, 'retraso': retraso, 'rutaPartituras': rutaPartituras};
}
