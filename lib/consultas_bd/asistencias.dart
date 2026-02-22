import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ritmo_app/modelos/asistencia.dart';
import 'package:ritmo_app/modelos/musico_prevision.dart';
import 'package:ritmo_app/modelos/prevision_asistencia.dart';

/// ********************************************************
/// Clase estática responsable de todas las operaciones relacionadas con:
///
/// - Asistencias reales (fichajes)
/// - Previsión de asistencia a eventos
/// - Consulta histórica de asistencias
///
/// Toda la información se almacena en subcolecciones dentro del documento de cada banda.
/// ********************************************************
class ConsultasAsistenciasBD {
  static final firestore = FirebaseFirestore.instance;

  /// *******************************************************************
  /// STREAM DE ASISTENCIAS EN TIEMPO REAL
  ///
  /// Obtiene un Stream que escucha en tiempo real las asistencias registradas para un evento concreto.
  ///
  /// Parámetros:
  /// - bandaId --> ID de la banda
  /// - eventoId --> ID del evento
  ///
  /// Devuelve:
  /// - Map (String, DateTime)
  ///   clave   --> musicoId
  ///   valor   --> momento del fichaje
  ///
  /// Se usa típicamente para mostrar en vivo quién ha fichado.
  /// *******************************************************************
  static Stream<Map<String, DateTime>> streamAsistenciasEvento({required String bandaId, required String eventoId}) {
    return firestore
        .collection('bandas')
        .doc(bandaId)
        .collection('asistencias')
        .where('eventoId', isEqualTo: eventoId)
        .snapshots()
        .map((snap) {
          final Map<String, DateTime> mapa = {};

          for (var doc in snap.docs) {
            final musicoId = doc['musicoId'];
            final Timestamp ts = doc['momentoFichaje'];
            mapa[musicoId] = ts.toDate();
          }

          return mapa;
        });
  }

  /// *************************************************************
  /// OBTENER PREVISIÓN DE ASISTENCIA A UN EVENTO
  ///
  /// Construye una lista completa de previsión por músico, combinando información de múltiples colecciones:
  ///
  /// Músicos activos en la banda
  /// Datos globales del usuario
  /// Instrumentos y categorías
  /// Respuesta de previsión del evento
  ///
  /// Devuelve:
  /// - Lista de objetos [PrevisionMusico]
  ///
  /// Esta función centraliza toda la lógica de ensamblado de datos distribuidos en Firestore.
  /// *************************************************************
  static Future<List<PrevisionMusico>> obtenerPrevisionAsistencia({
    required String bandaId,
    required String eventoId,
  }) async {
    // Músicos activos
    final musicosActivos = await firestore
        .collection('bandas')
        .doc(bandaId)
        .collection('usuarios')
        .where('activo', isEqualTo: true)
        .get();

    final mapaMusicos = {for (var doc in musicosActivos.docs) doc.id: doc.data()};

    // Usuarios
    final usuariosGlobalSnap = await Future.wait(
      mapaMusicos.keys.map((uid) => firestore.collection('usuarios').doc(uid).get()),
    );

    final usuariosGlobal = <String, Map<String, dynamic>>{};
    for (var doc in usuariosGlobalSnap) {
      final data = doc.data();
      if (data != null && data['rol'] == 'musico') {
        usuariosGlobal[doc.id] = data;
      }
    }

    // Instrumentos
    final instSnap = await firestore.collection('bandas').doc(bandaId).collection('instrumentos').get();

    final mapaInstrumentos = <String, Map<String, dynamic>>{};
    final mapaCategorias = <String, Map<String, String>>{};

    for (var doc in instSnap.docs) {
      final data = doc.data();
      mapaInstrumentos[doc.id] = data;

      final List cats = (data['categorias'] as List?) ?? [];

      mapaCategorias[doc.id] = {
        for (var c in cats)
          if (c is Map<String, dynamic>) c['categoriaId'] ?? '': c['nombre'] ?? 'Sin categoría',
      };
    }

    // Previsión
    final previsionSnap = await firestore
        .collection('bandas')
        .doc(bandaId)
        .collection('eventos')
        .doc(eventoId)
        .collection('prevision_asistencia')
        .get();

    final previsionMap = {for (var doc in previsionSnap.docs) doc.id: doc.data()};

    // Construir lista final
    final List<PrevisionMusico> lista = [];

    usuariosGlobal.forEach((uid, data) {
      final bandaInfo = mapaMusicos[uid];
      if (bandaInfo == null) return;

      final prevision = previsionMap[uid];

      final instId = bandaInfo['instrumento'];
      final catId = bandaInfo['categoria'];

      final instrumentoNombre = mapaInstrumentos[instId]?['nombre'] ?? 'Sin instrumento';

      final categoriaNombre = mapaCategorias[instId]?[catId] ?? '';

      lista.add(
        PrevisionMusico(
          uid: uid,
          nombre: data['nombre'] ?? 'Sin nombre',
          instrumento: instrumentoNombre,
          categoria: categoriaNombre,
          asistira: prevision?['asistira'],
          motivo: prevision?['motivo'],
          otrosDetalle: prevision?['otros_detalle'],
        ),
      );
    });

    return lista;
  }

  /// ***************************************************************
  /// GUARDAR PREVISIÓN DE ASISTENCIA
  ///
  /// Guarda o sobrescribe la previsión de un músico dentro del evento correspondiente.
  ///
  /// La clave del documento es el UID del músico, garantizando una única respuesta por evento.
  /// ***************************************************************
  static Future<void> guardarPrevision({
    required String bandaId,
    required String eventoId,
    required PrevisionAsistencia prevision,
  }) async {
    await firestore
        .collection('bandas')
        .doc(bandaId)
        .collection('eventos')
        .doc(eventoId)
        .collection('prevision_asistencia')
        .doc(prevision.uid)
        .set(prevision.toMap());
  }

  /// ********************************************************
  /// OBTENER HISTÓRICO DE ASISTENCIAS DE UN MÚSICO
  ///
  /// Devuelve todas las asistencias registradas para un músico dentro de una banda.
  ///
  /// Se transforma cada documento en un objeto [Asistencia].
  /// ********************************************************
  static Future<List<Asistencia>> obtenerAsistenciasMusico(String bandaId, String musicoId) async {
    final snap = await firestore
        .collection('bandas')
        .doc(bandaId)
        .collection('asistencias')
        .where('musicoId', isEqualTo: musicoId)
        .get();

    return snap.docs.map((doc) {
      final data = doc.data();

      return Asistencia.fromMap({
        'eventoId': data['eventoId'],
        'momentoFichaje': (data['momentoFichaje'] as Timestamp).toDate(),
      });
    }).toList();
  }

  /// *********************************************************************
  /// REGISTRAR FICHAJE DE UN MÚSICO (AUTO-REGISTRO)
  ///
  /// El músico registra su asistencia en tiempo real.
  ///
  /// Se crea un nuevo documento con:
  /// - temporadaId
  /// - eventoId
  /// - musicoId
  /// - momentoFichaje (Timestamp.now)
  /// *********************************************************************
  static Future<void> registrarFichaje({
    required String temporadaSeleccionadaId,
    required String bandaId,
    required String eventoId,
    required String musicoId,
  }) async {
    await firestore.collection('bandas').doc(bandaId).collection('asistencias').add({
      'temporadaId': temporadaSeleccionadaId,
      'eventoId': eventoId,
      'musicoId': musicoId,
      'momentoFichaje': Timestamp.now(),
    });
  }

  /// **********************************************************************************
  /// GUARDAR ASISTENCIA POR EL ADMINISTRADOR (PASAR LISTA)
  ///
  /// Permite al administrador marcar manualmente la asistencia de un músico.
  ///
  /// Características:
  /// - Genera un ID único por evento y músico
  /// - Si presente = true --> crea o sobrescribe
  /// - Si presente = false --> elimina el documento
  ///
  /// Lógica especial:
  /// Si el evento ya finalizó, se asigna como hora de fichaje el inicio del evento + 9 minutos (para mantener coherencia temporal).
  /// **********************************************************************************
  static Future<void> guardarAsistenciaEvento({
    required String temporadaSeleccionadaId,
    required String bandaId,
    required String eventoId,
    required String musicoId,
    required DateTime? fichaje,
    required bool presente,
    required DateTime fechaInicioEvento,
    required DateTime fechaFinEvento,
  }) async {
    final refAsistencias = firestore.collection('bandas').doc(bandaId).collection('asistencias');

    final fechaAhora = DateTime.now();
    final eventoFinalizado = fechaFinEvento.isBefore(fechaAhora);
    final momentoFichaje = eventoFinalizado ? fechaInicioEvento.add(const Duration(minutes: 9)) : fechaAhora;

    // Crear un docId único por evento y músico
    final docId = '${eventoId}_$musicoId';
    final docRef = refAsistencias.doc(docId);

    if (presente) {
      // Sobrescribe o crea si no existe
      await docRef.set({
        'temporadaId': temporadaSeleccionadaId,
        'eventoId': eventoId,
        'musicoId': musicoId,
        'momentoFichaje': momentoFichaje,
      });
    } else {
      // Borrar asistencia si existe
      await docRef.delete();
    }
  }
}
