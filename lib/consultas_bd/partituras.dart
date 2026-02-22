import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ritmo_app/modelos/partitura.dart';

class ConsultasPartiturasBD {
  static final firestore = FirebaseFirestore.instance;

  /// ******************************************************************
  /// OBTENER STREAM DE PARTITURAS DE UNA BANDA
  ///
  /// Devuelve un Stream que emite la lista de partituras de la banda
  /// ordenadas alfabéticamente por título.
  ///
  /// Parámetros:
  /// - bandaId --> ID de la banda
  ///
  /// Devuelve:
  /// - Stream(List(Partitura))
  /// ******************************************************************
  static Stream<List<Partitura>> streamPartituras(String bandaId) {
    return firestore
        .collection('bandas')
        .doc(bandaId)
        .collection('partituras')
        .orderBy('titulo')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Partitura.fromMap(doc.id, doc.data())).toList());
  }

  /// ******************************************************************
  /// OBTENER REFERENCIA A LA COLECCIÓN DE PARTITURAS
  ///
  /// Devuelve la referencia de la colección "partituras" para la banda indicada.
  ///
  /// Parámetros:
  /// - bandaId --> ID de la banda
  ///
  /// Devuelve:
  /// - CollectionReference(Map(String, dynamic))
  /// ******************************************************************
  static CollectionReference<Map<String, dynamic>> partiturasRef(String bandaId) {
    return firestore.collection('bandas').doc(bandaId).collection('partituras');
  }

  /// ******************************************************************
  /// OBTENER PARTITURA POR ID
  ///
  /// Consulta un documento de partitura específico en la banda.
  ///
  /// Parámetros:
  /// - bandaId --> ID de la banda
  /// - partituraId --> ID de la partitura
  ///
  /// Devuelve:
  /// - Objeto Partitura si existe, o null si no se encuentra
  /// ******************************************************************
  static Future<Partitura?> obtenerPartitura(String bandaId, String partituraId) async {
    final doc = await firestore.collection('bandas').doc(bandaId).collection('partituras').doc(partituraId).get();
    if (!doc.exists) return null;

    final data = doc.data()!;
    return Partitura(id: doc.id, titulo: data['titulo'] ?? '', archivo: data['archivo'] ?? '', genero: data['genero']);
  }

  /// ******************************************************************
  /// OBTENER URI DE PARTITURA
  ///
  /// Construye la URL completa del archivo PDF de la partitura
  /// considerando instrumento, categoría y ruta base de la banda.
  ///
  /// Parámetros:
  /// - bandaId --> ID de la banda
  /// - archivo --> Nombre del archivo PDF
  /// - instrumentoCat --> String en formato "instrumentoId|categoriaId"
  ///
  /// Devuelve:
  /// - Uri de la partitura o null si no se puede construir
  /// ******************************************************************
  static Future<Uri?> obtenerUriPartitura({
    required String bandaId,
    required String archivo,
    required String instrumentoCat,
  }) async {
    final partes = instrumentoCat.split('|');
    if (partes.length != 2) return null;

    final instrumentoId = partes[0];
    final categoriaId = partes[1];

    final instrumentoDoc = await firestore
        .collection('bandas')
        .doc(bandaId)
        .collection('instrumentos')
        .doc(instrumentoId)
        .get();

    if (!instrumentoDoc.exists) return null;

    final dataInstrumento = instrumentoDoc.data()!;
    String carpeta = '';

    final categorias = dataInstrumento['categorias'] as List? ?? [];

    for (final c in categorias) {
      if (c is Map<String, dynamic> && c['categoriaId'] == categoriaId) {
        carpeta = c['carpetaPartituras'] ?? '';
        break;
      }
    }

    if (carpeta.isEmpty) {
      carpeta = dataInstrumento['carpetaPartituras'] ?? '';
    }

    if (carpeta.isEmpty) return null;

    final bandaDoc = await firestore.collection('bandas').doc(bandaId).get();

    final ruta = bandaDoc.data()?['parametros']?['rutaPartituras'];
    if (ruta == null || ruta.isEmpty) return null;

    final rutaNormalizada = ruta.endsWith('/') ? ruta : '$ruta/';
    return Uri.parse('$rutaNormalizada$carpeta/$archivo.pdf');
  }

  /// ******************************************************************
  /// VERIFICAR SI UNA PARTITURA SE PUEDE ELIMINAR
  ///
  /// Comprueba todos los eventos de la banda para determinar
  /// si la partitura está siendo utilizada en algún repertorio.
  ///
  /// Parámetros:
  /// - bandaId --> ID de la banda
  /// - partituraId --> ID de la partitura
  ///
  /// Devuelve:
  /// - true si se puede eliminar, false si está en uso
  /// ******************************************************************
  static Future<bool> partituraSePuedeEliminar({required String bandaId, required String partituraId}) async {
    try {
      // Traemos todos los eventos de la banda
      final eventosSnapshot = await firestore.collection('bandas').doc(bandaId).collection('eventos').get();

      for (var eventoDoc in eventosSnapshot.docs) {
        final eventoId = eventoDoc.id;

        // Traemos el repertorio de este evento
        final repertorioSnapshot = await firestore
            .collection('bandas')
            .doc(bandaId)
            .collection('eventos')
            .doc(eventoId)
            .collection('repertorio')
            .get();

        for (var repDoc in repertorioSnapshot.docs) {
          final repData = repDoc.data();
          final repPartituraId = repData['partituraId'] as String? ?? '';

          if (repPartituraId == partituraId) {
            // Esta partitura está en uso --> no se puede eliminar
            return false;
          }
        }
      }

      // Ningún evento tiene esta partitura en repertorio
      return true;
    } catch (e) {
      return false;
    }
  }

  /// ******************************************************************
  /// GUARDAR PARTITURA
  ///
  /// Crea o actualiza una partitura en la colección de la banda.
  ///
  /// Parámetros:
  /// - bandaId --> ID de la banda
  /// - partituraId --> ID de la partitura (opcional, si se actualiza)
  /// - datos --> Map con los campos de la partitura
  /// ******************************************************************
  static Future<void> guardarPartitura({
    required String bandaId,
    String? partituraId,
    required Map<String, dynamic> datos,
  }) async {
    final ref = firestore.collection('bandas').doc(bandaId).collection('partituras');
    if (partituraId == null) {
      await ref.add(datos);
    } else {
      await ref.doc(partituraId).set(datos, SetOptions(merge: true));
    }
  }

  /// ******************************************************************
  /// ELIMINAR PARTITURA
  ///
  /// Borra un documento de partitura de la colección de la banda.
  ///
  /// Parámetros:
  /// - bandaId --> ID de la banda
  /// - partituraId --> ID de la partitura
  /// ******************************************************************
  static Future<void> eliminarPartitura(String bandaId, String partituraId) async {
    final ref = firestore.collection('bandas').doc(bandaId).collection('partituras').doc(partituraId);
    await ref.delete();
  }
}
