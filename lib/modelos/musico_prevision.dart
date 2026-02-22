class PrevisionMusico {
  final String uid;
  final String nombre;
  final String instrumento;
  final String categoria;
  final bool? asistira;
  final String? motivo;
  final String? otrosDetalle;

  // Constructor
  PrevisionMusico({
    required this.uid,
    required this.nombre,
    required this.instrumento,
    required this.categoria,
    this.asistira,
    this.motivo,
    this.otrosDetalle,
  });
}
