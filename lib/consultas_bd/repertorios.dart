import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ritmo_app/modelos/partitura.dart';
import 'package:ritmo_app/modelos/partitura_repertorio.dart';

class ConsultasRepertoriosBD {
  static final firestore = FirebaseFirestore.instance;

  /// ******************************************************************
  /// OBTENER STREAM DEL REPERTORIO DE UN EVENTO
  ///
  /// Devuelve un Stream que emite la lista de partituras
  /// asociadas a un evento, ordenadas por el campo "orden".
  ///
  /// Parámetros:
  /// - bandaId --> ID de la banda
  /// - eventoId --> ID del evento
  ///
  /// Devuelve:
  /// - Stream(List(PartituraRepertorio))
  /// ******************************************************************
  static Stream<List<PartituraRepertorio>> streamRepertorio(String bandaId, String eventoId) {
    return firestore
        .collection('bandas')
        .doc(bandaId)
        .collection('eventos')
        .doc(eventoId)
        .collection('repertorio')
        .orderBy('orden')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => PartituraRepertorio.fromMap(doc.id, doc.data())).toList());
  }

  /// ******************************************************************
  /// AGREGAR PARTITURA AL REPERTORIO
  ///
  /// Inserta una nueva partitura dentro del repertorio del evento con el orden especificado.
  ///
  /// Parámetros:
  /// - bandaId --> ID de la banda
  /// - eventoId --> ID del evento
  /// - partitura --> Objeto Partitura a agregar
  /// - orden --> Posición dentro del repertorio
  /// ******************************************************************
  static Future<void> agregarPartituraAlRepertorio({
    required String bandaId,
    required String eventoId,
    required Partitura partitura,
    required int orden,
  }) async {
    await firestore.collection('bandas').doc(bandaId).collection('eventos').doc(eventoId).collection('repertorio').add({
      'titulo': partitura.titulo,
      'partituraId': partitura.id,
      'orden': orden,
      'accesoKey': '',
    });
  }

  /// ******************************************************************
  /// MOVER PARTITURA DENTRO DEL REPERTORIO
  ///
  /// Intercambia el orden de dos partituras dentro del repertorio.
  ///
  /// Parámetros:
  /// - bandaId --> ID de la banda
  /// - eventoId --> ID del evento
  /// - docIdA --> ID de la primera partitura
  /// - ordenA --> Nuevo orden de la primera partitura
  /// - docIdB --> ID de la segunda partitura
  /// - ordenB --> Nuevo orden de la segunda partitura
  /// ******************************************************************
  static Future<void> moverRepertorio({
    required String bandaId,
    required String eventoId,
    required String docIdA,
    required int ordenA,
    required String docIdB,
    required int ordenB,
  }) async {
    final refA = firestore
        .collection('bandas')
        .doc(bandaId)
        .collection('eventos')
        .doc(eventoId)
        .collection('repertorio')
        .doc(docIdA);

    final refB = firestore
        .collection('bandas')
        .doc(bandaId)
        .collection('eventos')
        .doc(eventoId)
        .collection('repertorio')
        .doc(docIdB);

    final batch = firestore.batch();
    batch.update(refA, {'orden': ordenB});
    batch.update(refB, {'orden': ordenA});

    await batch.commit();
  }

  /// ******************************************************************
  /// OBTENER SIGUIENTE ORDEN DEL REPERTORIO
  ///
  /// Calcula el siguiente valor de "orden" disponible para agregar una nueva partitura al final del repertorio.
  ///
  /// Parámetros:
  /// - bandaId --> ID de la banda
  /// - eventoId --> ID del evento
  ///
  /// Devuelve:
  /// - Entero con el siguiente orden disponible
  /// ******************************************************************
  static Future<int> obtenerSiguienteOrden(String bandaId, String eventoId) async {
    final snap = await firestore
        .collection('bandas')
        .doc(bandaId)
        .collection('eventos')
        .doc(eventoId)
        .collection('repertorio')
        .orderBy('orden', descending: true)
        .limit(1)
        .get();

    return snap.docs.isEmpty ? 1 : (snap.docs.first['orden'] as int) + 1;
  }

  /// ******************************************************************
  /// ELIMINAR PARTITURA DEL REPERTORIO
  ///
  /// Borra una partitura específica del repertorio de un evento.
  ///
  /// Parámetros:
  /// - bandaId --> ID de la banda
  /// - eventoId --> ID del evento
  /// - docId --> ID del documento de la partitura en el repertorio
  /// ******************************************************************
  static Future<void> eliminarPartituraDelRepertorio({
    required String bandaId,
    required String eventoId,
    required String docId,
  }) async {
    await firestore
        .collection('bandas')
        .doc(bandaId)
        .collection('eventos')
        .doc(eventoId)
        .collection('repertorio')
        .doc(docId)
        .delete();
  }
}
