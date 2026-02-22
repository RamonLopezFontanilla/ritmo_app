import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ritmo_app/modelos/temporada.dart';

class ConsultasTemporadasBD {
  static final FirebaseFirestore firestore = FirebaseFirestore.instance;

  /// ********************************************************************
  /// OBTENER TEMPORADAS CON LA ACTUAL
  ///
  /// Devuelve todas las temporadas de la banda y, si existe, La temporada que actualmente está activa según la fecha actual.
  ///
  /// Parámetros:
  /// - bandaId --> ID de la banda
  ///
  /// Devuelve:
  /// - Tuple con lista de temporadas y la temporada actual (si hay)
  /// ********************************************************************
  static Future<({List<Temporada> lista, Temporada? actual})> obtenerTemporadasConActual(String bandaId) async {
    final lista = await obtenerTemporadas(bandaId);
    final ahora = DateTime.now();

    Temporada? actual;

    for (final temp in lista) {
      if (temp.estaActiva(ahora)) {
        actual = temp;
        break;
      }
    }

    return (lista: lista, actual: actual);
  }

  /// ******************************************************************
  /// OBTENER STREAM DE TEMPORADAS
  ///
  /// Devuelve un Stream que emite la lista de temporadas de una banda
  /// ordenadas por fecha de inicio ascendente.
  ///
  /// Parámetros:
  /// - bandaId --> ID de la banda
  ///
  /// Devuelve:
  /// - Stream(List(Temporada))
  /// ******************************************************************
  static Stream<List<Temporada>> streamTemporadas(String bandaId) {
    return firestore
        .collection('bandas')
        .doc(bandaId)
        .collection('temporadas')
        .orderBy('fechaInicio', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();

            return Temporada.fromMap(doc.id, {
              ...data,
              'fechaInicio': (data['fechaInicio'] as Timestamp).toDate(),
              'fechaFin': (data['fechaFin'] as Timestamp).toDate(),
            });
          }).toList();
        });
  }

  /// ******************************************************************
  /// OBTENER TODAS LAS TEMPORADAS
  ///
  /// Recupera todas las temporadas de una banda en forma de lista.
  ///
  /// Parámetros:
  /// - bandaId --> ID de la banda
  ///
  /// Devuelve:
  /// - List(Temporada)
  /// ******************************************************************
  static Future<List<Temporada>> obtenerTemporadas(String bandaId) async {
    final snapshot = await firestore
        .collection("bandas")
        .doc(bandaId)
        .collection("temporadas")
        .orderBy('fechaInicio', descending: false)
        .get();

    return snapshot.docs.map(docToTemporada).toList();
  }

  /// ******************************************************************
  /// OBTENER TEMPORADA POR ID
  ///
  /// Recupera un documento de temporada específica por su ID.
  ///
  /// Parámetros:
  /// - bandaId --> ID de la banda
  /// - temporadaId --> ID de la temporada
  ///
  /// Devuelve:
  /// - Temporada? (null si no existe)
  /// ******************************************************************
  static Future<Temporada?> obtenerTemporadaPorId(String bandaId, String temporadaId) async {
    final doc = await firestore.collection("bandas").doc(bandaId).collection("temporadas").doc(temporadaId).get();

    if (!doc.exists) return null;
    return docToTemporada(doc);
  }

  /// ******************************************************************
  /// OBTENER NOMBRE DE UNA TEMPORADA
  ///
  /// Recupera solo el nombre de una temporada por su ID.
  ///
  /// Parámetros:
  /// - bandaId --> ID de la banda
  /// - temporadaId --> ID de la temporada
  ///
  /// Devuelve:
  /// - String? con el nombre o null si no existe
  /// ******************************************************************
  static Future<String?> obtenerNombreTemporada(String bandaId, String temporadaId) async {
    final temporada = await ConsultasTemporadasBD.obtenerTemporadaPorId(bandaId, temporadaId);
    return temporada?.nombre;
  }

  /// ******************************************************************
  /// GUARDAR O ACTUALIZAR TEMPORADA
  ///
  /// Inserta o actualiza un documento de temporada en Firestore.
  ///
  /// Parámetros:
  /// - bandaId --> ID de la banda
  /// - temporada --> Objeto Temporada a guardar
  /// ******************************************************************
  static Future<void> guardarTemporada(String bandaId, Temporada temporada) async {
    final collectionRef = firestore.collection('bandas').doc(bandaId).collection('temporadas');
    final docRef = temporada.id.isNotEmpty ? collectionRef.doc(temporada.id) : collectionRef.doc();
    await docRef.set({
      'nombre': temporada.nombre,
      'fechaInicio': Timestamp.fromDate(temporada.fechaInicio),
      'fechaFin': Timestamp.fromDate(temporada.fechaFin),
    });
  }

  /// ******************************************************************
  /// COMPROBAR SI UNA TEMPORADA SE PUEDE ELIMINAR
  ///
  /// Una temporada no se puede eliminar si tiene liquidaciones o eventos asociados.
  ///
  /// Parámetros:
  /// - bandaId --> ID de la banda
  /// - temp --> Objeto Temporada a verificar
  ///
  /// Devuelve:
  /// - bool (true si se puede eliminar)
  /// ******************************************************************
  static Future<bool> temporadaSePuedeEliminar(String bandaId, Temporada temp) async {
    // Revisar liquidaciones
    final liquidaciones = await firestore
        .collection("bandas")
        .doc(bandaId)
        .collection("temporadas")
        .doc(temp.id)
        .collection("liquidacion")
        .limit(1)
        .get();

    if (liquidaciones.docs.isNotEmpty) return false;

    // Revisar eventos dentro del rango de fechas
    final eventos = await firestore
        .collection("bandas")
        .doc(bandaId)
        .collection("eventos")
        .where("inicio", isGreaterThanOrEqualTo: Timestamp.fromDate(temp.fechaInicio))
        .where("inicio", isLessThanOrEqualTo: Timestamp.fromDate(temp.fechaFin))
        .limit(1)
        .get();

    return eventos.docs.isEmpty;
  }

  /// ******************************************************************
  /// ELIMINAR TEMPORADA
  ///
  /// Borra un documento de temporada de Firestore.
  ///
  /// Parámetros:
  /// - bandaId --> ID de la banda
  /// - temp --> Objeto Temporada a eliminar
  /// ******************************************************************
  static Future<void> eliminarTemporada(String bandaId, Temporada temp) async {
    await firestore.collection("bandas").doc(bandaId).collection("temporadas").doc(temp.id).delete();
  }

  /// ******************************************************************
  /// CONVERTIR DOCUMENT SNAPSHOT A TEMPORADA
  ///
  /// Convierte un DocumentSnapshot en un objeto Temporada.
  ///
  /// Parámetros:
  /// - doc --> DocumentSnapshot de Firestore
  ///
  /// Devuelve:
  /// - Temporada
  /// ******************************************************************
  static Temporada docToTemporada(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Temporada.fromMap(doc.id, {
      'nombre': data['nombre'] ?? '',
      'fechaInicio': (data['fechaInicio'] as Timestamp).toDate(),
      'fechaFin': (data['fechaFin'] as Timestamp).toDate(),
    });
  }
}
