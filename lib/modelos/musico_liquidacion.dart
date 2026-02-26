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

  static int _toInt(dynamic v) => (v as num?)?.toInt() ?? 0;
  static double _toDouble(dynamic v) => (v as num?)?.toDouble() ?? 0.0;

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

  factory LiquidacionMusico.fromMap(String id, Map<String, dynamic> map) {
    return LiquidacionMusico(
      id: id,
      nombre: map['nombre'] ?? '',
      incluidoEnLiquidacion: map['incluidoEnLiquidacion'] ?? false,
      puntosAntiguedad: _toInt(map['puntosAntiguedad']),
      numEnsayosPuntual: _toInt(map['numEnsayosPuntual']),
      numEnsayosRetraso: _toInt(map['numEnsayosRetraso']),
      numActuacionPuntual: _toInt(map['numActuacionPuntual']),
      numActuacionRetraso: _toInt(map['numActuacionRetraso']),
      numSemanaStaPuntual: _toInt(map['numSemanaStaPuntual']),
      numSemanaStaRetraso: _toInt(map['numSemanaStaRetraso']),
      puntosTotales: _toInt(map['puntosTotales']),
      importeFinal: _toDouble(map['importeFinal']),
    );
  }

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
