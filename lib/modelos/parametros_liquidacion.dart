class ParametrosLiquidacion {
  final bool visibleMusico;
  final int cantidadRepartir;
  final int totalPuntosLiquidacion;
  final double valorPunto;
  final int puntosEnsayoPuntual;
  final int puntosAntigEP;
  final int puntosEnsayoRetraso;
  final int puntosAntigER;
  final int puntosActuacionPuntual;
  final int puntosAntigAP;
  final int puntosActuacionRetrasada;
  final int puntosAntigAR;
  final int puntosSSPuntual;
  final int puntosAntigSSP;
  final int puntosSSRetraso;
  final int puntosAntigSSR;

  ParametrosLiquidacion({
    this.visibleMusico = true,
    this.cantidadRepartir = 0,
    this.totalPuntosLiquidacion = 0,
    this.valorPunto = 0,
    this.puntosEnsayoPuntual = 0,
    this.puntosAntigEP = 0,
    this.puntosEnsayoRetraso = 0,
    this.puntosAntigER = 0,
    this.puntosActuacionPuntual = 0,
    this.puntosAntigAP = 0,
    this.puntosActuacionRetrasada = 0,
    this.puntosAntigAR = 0,
    this.puntosSSPuntual = 0,
    this.puntosAntigSSP = 0,
    this.puntosSSRetraso = 0,
    this.puntosAntigSSR = 0,
  });

  factory ParametrosLiquidacion.fromMap(Map<String, dynamic> map) {
    return ParametrosLiquidacion(
      visibleMusico: map['visibleMusico'] ?? true,
      cantidadRepartir: map['cantidadRepartir'] ?? 0,
      totalPuntosLiquidacion: map['totalPuntosLiquidacion'] ?? 0,
      puntosEnsayoPuntual: map['puntosEnsayoPuntual'] ?? 0,
      valorPunto: map['valorPunto'] ?? 0,
      puntosAntigEP: map['puntosAntigEP'] ?? 0,
      puntosEnsayoRetraso: map['puntosEnsayoRetraso'] ?? 0,
      puntosAntigER: map['puntosAntigER'] ?? 0,
      puntosActuacionPuntual: map['puntosActuacionPuntual'] ?? 0,
      puntosAntigAP: map['puntosAntigAP'] ?? 0,
      puntosActuacionRetrasada: map['puntosActuacionRetrasada'] ?? 0,
      puntosAntigAR: map['puntosAntigAR'] ?? 0,
      puntosSSPuntual: map['puntosSSPuntual'] ?? 0,
      puntosAntigSSP: map['puntosAntigSSP'] ?? 0,
      puntosSSRetraso: map['puntosSSRetraso'] ?? 0,
      puntosAntigSSR: map['puntosAntigSSR'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'visibleMusico': visibleMusico,
      'cantidadRepartir': cantidadRepartir,
      'totalPuntosLiquidacion': totalPuntosLiquidacion,
      'valorPunto': valorPunto,
      'puntosEnsayoPuntual': puntosEnsayoPuntual,
      'puntosAntigEP': puntosAntigEP,
      'puntosEnsayoRetraso': puntosEnsayoRetraso,
      'puntosAntigER': puntosAntigER,
      'puntosActuacionPuntual': puntosActuacionPuntual,
      'puntosAntigAP': puntosAntigAP,
      'puntosActuacionRetrasada': puntosActuacionRetrasada,
      'puntosAntigAR': puntosAntigAR,
      'puntosSSPuntual': puntosSSPuntual,
      'puntosAntigSSP': puntosAntigSSP,
      'puntosSSRetraso': puntosSSRetraso,
      'puntosAntigSSR': puntosAntigSSR,
    };
  }

  ParametrosLiquidacion copyWith({bool? visibleMusico, int? cantidadRepartir}) {
    return ParametrosLiquidacion(
      visibleMusico: visibleMusico ?? this.visibleMusico,
      cantidadRepartir: cantidadRepartir ?? this.cantidadRepartir,
      totalPuntosLiquidacion: totalPuntosLiquidacion,
      valorPunto: valorPunto,
      puntosEnsayoPuntual: puntosEnsayoPuntual,
      puntosAntigEP: puntosAntigEP,
      puntosEnsayoRetraso: puntosEnsayoRetraso,
      puntosAntigER: puntosAntigER,
      puntosActuacionPuntual: puntosActuacionPuntual,
      puntosAntigAP: puntosAntigAP,
      puntosActuacionRetrasada: puntosActuacionRetrasada,
      puntosAntigAR: puntosAntigAR,
      puntosSSPuntual: puntosSSPuntual,
      puntosAntigSSP: puntosAntigSSP,
      puntosSSRetraso: puntosSSRetraso,
      puntosAntigSSR: puntosAntigSSR,
    );
  }
}
