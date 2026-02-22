class LiquidacionMusico {
  final String id;
  final String nombre;
  final bool incluidoEnLiquidacion;
  final int puntosAntiguedad;
  final int numEnsayosPuntual;
  final int numEnsayosRetraso;
  final int numActuacionPuntual;
  final int numActuacionRetraso;
  final int numSemanaStaPuntual;
  final int numSemanaStaRetraso;
  final int puntosTotales;
  final double importeFinal;

  LiquidacionMusico({
    required this.id,
    required this.nombre,
    required this.incluidoEnLiquidacion,
    required this.puntosAntiguedad,
    required this.numEnsayosPuntual,
    required this.numEnsayosRetraso,
    required this.numActuacionPuntual,
    required this.numActuacionRetraso,
    required this.numSemanaStaPuntual,
    required this.numSemanaStaRetraso,
    required this.puntosTotales,
    required this.importeFinal,
  });

  /// Convertir a Map(String, dynamic) para Firestore
  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'incluidoEnLiquidacion': incluidoEnLiquidacion,
      'puntosAntiguedad': puntosAntiguedad,
      'numEnsayosPuntual': numEnsayosPuntual,
      'numEnsayosRetraso': numEnsayosRetraso,
      'numActuacionPuntual': numActuacionPuntual,
      'numActuacionRetraso': numActuacionRetraso,
      'numSemanaStaPuntual': numSemanaStaPuntual,
      'numSemanaStaRetraso': numSemanaStaRetraso,
      'puntosTotales': puntosTotales,
      'importeFinal': importeFinal,
    };
  }

  /// Crear instancia desde Map String, dynamic de Firestore
  factory LiquidacionMusico.fromMap(String id, Map<String, dynamic> map) {
    return LiquidacionMusico(
      id: id,
      nombre: map['nombre'] ?? '',
      incluidoEnLiquidacion: map['incluidoEnLiquidacion'] ?? false,
      puntosAntiguedad: map['puntosAntiguedad'] ?? 0,
      numEnsayosPuntual: map['numEnsayosPuntual'] ?? 0,
      numEnsayosRetraso: map['numEnsayosRetraso'] ?? 0,
      numActuacionPuntual: map['numActuacionPuntual'] ?? 0,
      numActuacionRetraso: map['numActuacionRetraso'] ?? 0,
      numSemanaStaPuntual: map['numSemanaStaPuntual'] ?? 0,
      numSemanaStaRetraso: map['numSemanaStaRetraso'] ?? 0,
      puntosTotales: map['puntosTotales'] ?? 0,
      importeFinal: (map['importeFinal'] ?? 0).toDouble(),
    );
  }

  /// Crear copia modificando algunos campos
  LiquidacionMusico copyWith({
    String? nombre,
    bool? incluidoEnLiquidacion,
    int? puntosAntiguedad,
    int? numEnsayosPuntual,
    int? numEnsayosRetraso,
    int? numActuacionPuntual,
    int? numActuacionRetraso,
    int? numSemanaStaPuntual,
    int? numSemanaStaRetraso,
    int? puntosTotales,
    double? importeFinal,
  }) {
    return LiquidacionMusico(
      id: id,
      nombre: nombre ?? this.nombre,
      incluidoEnLiquidacion: incluidoEnLiquidacion ?? this.incluidoEnLiquidacion,
      puntosAntiguedad: puntosAntiguedad ?? this.puntosAntiguedad,
      numEnsayosPuntual: numEnsayosPuntual ?? this.numEnsayosPuntual,
      numEnsayosRetraso: numEnsayosRetraso ?? this.numEnsayosRetraso,
      numActuacionPuntual: numActuacionPuntual ?? this.numActuacionPuntual,
      numActuacionRetraso: numActuacionRetraso ?? this.numActuacionRetraso,
      numSemanaStaPuntual: numSemanaStaPuntual ?? this.numSemanaStaPuntual,
      numSemanaStaRetraso: numSemanaStaRetraso ?? this.numSemanaStaRetraso,
      puntosTotales: puntosTotales ?? this.puntosTotales,
      importeFinal: importeFinal ?? this.importeFinal,
    );
  }
}
