class PartituraRepertorio {
  final String docId;
  final String titulo;
  final String partituraId;
  final int orden;
  final String accesoKey;

  // Constructor
  PartituraRepertorio({
    required this.docId,
    required this.titulo,
    required this.partituraId,
    required this.orden,
    required this.accesoKey,
  });

  /// Crear desde un Map genérico
  factory PartituraRepertorio.fromMap(String id, Map<String, dynamic> data) {
    return PartituraRepertorio(
      docId: id,
      titulo: (data['titulo'] ?? '').toString().trim(),
      partituraId: (data['partituraId'] ?? '').toString().trim(),
      orden: data['orden'] is int ? data['orden'] : int.tryParse(data['orden']?.toString() ?? '0') ?? 0,
      accesoKey: (data['accesoKey'] ?? '').toString(),
    );
  }
}
