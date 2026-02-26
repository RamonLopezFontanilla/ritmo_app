import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ritmo_app/modelos/administrador.dart';
import 'package:ritmo_app/modelos/banda.dart';

/// ********************************************************
/// Clase estática responsable de todas las operaciones relacionadas con:
///
/// - Gestión de bandas
/// - Parámetros generales
/// - Administración de novedades
/// - Creación, edición y eliminación de bandas
///
/// Toda la información se almacena en la colección principal "bandas" dentro de Firestore.
/// ********************************************************
class ConsultasBandasBD {
  static FirebaseFirestore firestore = FirebaseFirestore.instance;

  /// ******************************************************************
  /// OBTENER TODAS LAS BANDAS ORDENADAS POR NOMBRE
  ///
  /// Consulta la colección "bandas" ordenando alfabéticamente por el campo "nombre".
  ///
  /// Devuelve:
  /// - Lista de objetos [Banda]
  /// ******************************************************************
  static Future<List<Banda>> obtenerBandas() async {
    final snapshot = await firestore.collection("bandas").orderBy("nombre").get();

    return snapshot.docs.map((doc) => Banda.fromMap(doc.id, doc.data())).toList();
  }

  /// ******************************************************************
  /// OBTENER BANDAS DE UN USUARIO CONCRETO
  ///
  /// Recibe una lista de IDs de bandas y obtiene los documentos correspondientes.
  ///
  /// Parámetros:
  /// - bandasId --> Lista de IDs de bandas asociadas al usuario
  ///
  /// Devuelve:
  /// - Lista de objetos [Banda] existentes
  /// ******************************************************************
  static Future<List<Banda>> obtenerBandasDelUsuario(List<String> bandasId) async {
    final snapshots = await Future.wait(bandasId.map((id) => firestore.collection('bandas').doc(id).get()));
    return snapshots.where((doc) => doc.exists).map((doc) => Banda.fromMap(doc.id, doc.data()!)).toList();
  }

  /// ******************************************************************
  /// GUARDAR PARÁMETROS GENERALES DE UNA BANDA
  ///
  /// Actualiza el objeto "parametros" dentro del documento
  /// de la banda.
  ///
  /// Parámetros:
  /// - distancia --> Distancia permitida para fichajes
  /// - retraso --> Minutos considerados como retraso
  /// - rutaPartituras --> Ruta base de partituras
  /// ******************************************************************
  static Future<void> guardarParametrosBanda({
    required String bandaId,
    required int distancia,
    required int retraso,
    required String rutaPartituras,
  }) async {
    await firestore.collection('bandas').doc(bandaId).update({
      'parametros': {'distancia': distancia, 'retraso': retraso, 'rutaPartituras': rutaPartituras},
    });
  }

  /// ******************************************************************
  /// OBTENER DATOS COMPLETOS DE UNA BANDA
  ///
  /// Devuelve el DocumentSnapshot completo del documento
  /// de la banda.
  ///
  /// Si no existe, devuelve null.
  /// ******************************************************************
  static Future<DocumentSnapshot<Map<String, dynamic>>?> obtenerDatosBanda(String bandaId) async {
    final doc = await firestore.collection('bandas').doc(bandaId).get();

    if (!doc.exists) return null;
    return doc;
  }

  /// ******************************************************************
  /// OBTENER NOMBRE DE UNA BANDA
  ///
  /// Devuelve el campo "nombre".
  /// Si no existe o ocurre un error, devuelve un texto por defecto.
  /// ******************************************************************
  static Future<String> obtenerNombreBanda(String bandaId) async {
    try {
      final doc = await firestore.collection('bandas').doc(bandaId).get();

      if (!doc.exists) {
        return "Sin nombre";
      }

      final data = doc.data() as Map<String, dynamic>;
      return data['nombre'] ?? "Sin nombre";
    } catch (e) {
      return "Error cargando nnombre";
    }
  }

  /// ******************************************************************
  /// OBTENER NOVEDADES DE UNA BANDA
  ///
  /// Devuelve el texto almacenado en el campo "novedades".
  ///
  /// Si no existe, devuelve un mensaje por defecto.
  /// ******************************************************************
  static Future<String> obtenerNovedades(String bandaId) async {
    try {
      final doc = await firestore.collection('bandas').doc(bandaId).get();

      if (!doc.exists) {
        return "Sin novedades por ahora";
      }

      final data = doc.data() as Map<String, dynamic>;
      return data['novedades'] ?? "Sin novedades por ahora";
    } catch (e) {
      return "Error cargando novedades";
    }
  }

  /// ******************************************************************
  /// ACTUALIZAR NOVEDADES DE UNA BANDA
  ///
  /// Sobrescribe el campo "novedades" del documento de la banda.
  /// ******************************************************************
  static Future<void> actualizarNovedades(String bandaId, String mensaje) async {
    await firestore.collection("bandas").doc(bandaId).update({"novedades": mensaje});
  }

  /// ******************************************************************
  /// GUARDAR DATOS GENERALES DE UNA BANDA
  ///
  /// Actualiza el documento completo usando el método
  /// toMap() del modelo [Banda].
  /// ******************************************************************
  static Future<void> guardarBanda(Banda banda) async {
    await firestore.collection('bandas').doc(banda.id).update(banda.toMap());
  }

  /// ******************************************************************
  /// ELIMINAR DOCUMENTO RECURSIVAMENTE
  ///
  /// Borra un documento y todas sus subcolecciones conocidas.
  ///
  /// Se usa en la eliminación completa de una banda.
  /// ******************************************************************v
  static Future<void> eliminarDocumentoRecursivo(DocumentReference docRef) async {
    final docSnap = await docRef.get();
    if (!docSnap.exists) return;

    // Intentar borrar todas las subcolecciones conocidas del documento
    final posiblesSubColecciones = [
      'usuarios',
      'liquidacion',
      'eventos',
      'repertorio',
      'prevision_asistencia',
      'temporadas',
    ];

    for (final subCol in posiblesSubColecciones) {
      final colRef = docRef.collection(subCol);
      final snap = await colRef.get();
      for (final subDoc in snap.docs) {
        await eliminarDocumentoRecursivo(subDoc.reference);
      }
    }

    // Finalmente, borrar el documento
    await docRef.delete();
  }

  /// ******************************************************************
  /// ELIMINAR UNA BANDA COMPLETAMENTE
  ///
  /// Proceso:
  /// - Elimina todas las colecciones internas conocidas.
  /// - Elimina el documento principal de la banda.
  /// - Elimina la referencia de la banda en todos los usuarios globales.
  ///
  /// Se utiliza un batch para actualizar usuarios.
  /// ******************************************************************
  static Future<void> eliminarBanda(Banda banda) async {
    final bandaRef = firestore.collection('bandas').doc(banda.id);

    // ---------- BORRAR COLECCIONES DIRECTAS Y SUS DOCUMENTOS ----------
    final coleccionesDirectas = [
      'asistencias',
      'generos',
      'instrumentos',
      'usuarios',
      'parametros',
      'partituras',
      'ubicaciones',
      'eventos',
      'temporadas',
    ];

    for (final colName in coleccionesDirectas) {
      final colRef = bandaRef.collection(colName);
      final snap = await colRef.get();
      for (final doc in snap.docs) {
        await eliminarDocumentoRecursivo(doc.reference);
      }
    }

    // ---------- BORRAR DOCUMENTO DE LA BANDA ----------
    await bandaRef.delete();

    // ---------- ACTUALIZAR USUARIOS GLOBALES ----------
    final usuariosGlobalSnap = await firestore.collection('usuarios').where('bandasId', arrayContains: banda.id).get();

    final batch = firestore.batch();
    for (final doc in usuariosGlobalSnap.docs) {
      batch.update(doc.reference, {
        'bandasId': FieldValue.arrayRemove([banda.id]),
      });
    }
    await batch.commit();
  }

  /// ******************************************************************
  /// CREAR UNA NUEVA BANDA
  ///
  /// Proceso:
  /// 1. Genera un nuevo documento en "bandas".
  /// 2. Asigna administrador y datos básicos.
  /// 3. Añade la banda al array "bandasId" del administrador.
  ///
  /// Se utiliza un WriteBatch para mantener consistencia.
  /// ******************************************************************v
  static Future<void> crearBanda(String nombre, Administrador admin) async {
    final docBanda = firestore.collection('bandas').doc();

    final batch = firestore.batch();
    batch.set(docBanda, {
      'nombre': nombre,
      'administrador': admin.uid,
      'administradorEmail': admin.email,
      'novedades': '',
    });

    final docAdmin = firestore.collection('usuarios').doc(admin.uid);
    batch.update(docAdmin, {
      'bandasId': FieldValue.arrayUnion([docBanda.id]),
    });

    await batch.commit();
  }

  /// ******************************************************************
  /// EDITAR UNA BANDA EXISTENTE
  ///
  /// Permite:
  /// - Cambiar nombre
  /// - Cambiar administrador
  ///
  /// Lógica:
  /// - Actualiza datos del documento banda
  /// - Elimina la banda del admin anterior (si cambia)
  /// - Garantiza que el nuevo admin tenga la banda en su lista
  /// ******************************************************************
  static Future<void> editarBanda(
    String bandaId,
    String nombre,
    Administrador nuevoAdmin,
    String? adminAnteriorId,
  ) async {
    final batch = firestore.batch();
    final bandaRef = firestore.collection('bandas').doc(bandaId);

    // Actualizar banda
    batch.update(bandaRef, {'nombre': nombre, 'administrador': nuevoAdmin.uid, 'administradorEmail': nuevoAdmin.email});

    // Quitar banda del admin anterior
    if (adminAnteriorId != null && adminAnteriorId != nuevoAdmin.uid) {
      final adminAnteriorRef = firestore.collection('usuarios').doc(adminAnteriorId);
      batch.update(adminAnteriorRef, {
        'bandasId': FieldValue.arrayRemove([bandaId]),
      });
    }

    // Asegurar que el nuevo admin tenga la banda
    final docNuevoAdmin = await firestore.collection('usuarios').doc(nuevoAdmin.uid).get();
    final bandasId = List<String>.from(docNuevoAdmin['bandasId'] ?? []);
    if (!bandasId.contains(bandaId)) {
      final nuevoAdminRef = firestore.collection('usuarios').doc(nuevoAdmin.uid);
      batch.update(nuevoAdminRef, {
        'bandasId': FieldValue.arrayUnion([bandaId]),
      });
    }

    await batch.commit();
  }
}
