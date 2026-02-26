import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ritmo_app/consultas_bd/instrumentos.dart';
import 'package:ritmo_app/modelos/edicion_datos_musico.dart';
import 'package:ritmo_app/modelos/musico.dart';
import 'package:ritmo_app/modelos/musico_en_banda.dart';
import 'package:ritmo_app/modelos/otros_accesos_musico.dart';

class ConsultasMusicosBD {
  static final firestore = FirebaseFirestore.instance;

  /// ******************************************************************
  /// STREAM DE MÚSICOS DE LA BANDA CONVERTIDOS A OBJETO MÚSICO
  ///
  /// Genera un stream de la colección usuarios de la banda y combina los datos globales y de instrumentos para crear objetos Musico.
  /// ******************************************************************
  static Stream<List<Musico>> streamMusicos(String bandaId) async* {
    // Trae los documentos de Firebase
    await for (final snap in firestore.collection('bandas').doc(bandaId).collection('usuarios').snapshots()) {
      final uids = snap.docs.map((d) => d.id).toList();
      final usuariosGlobal = await cargarDatosPersonales(uids);

      // Traer instrumentos y categorías
      final datos = await ConsultasInstrumentosBD.obtenerInstrumentosYCategorias(bandaId);
      final instrumentosMap = datos['instrumentos'] as Map<String, String>;
      final categoriasPorInstrumento = datos['categorias'] as Map<String, Map<String, String>>;

      // Convertir docs a objetos Musico
      final musicos = snap.docs.map((doc) {
        final uid = doc.id;
        final data = doc.data();
        final usuario = usuariosGlobal[uid] ?? {};
        return Musico.fromMap(
          uid: uid,
          data: data,
          usuario: usuario,
          instrumentosMap: instrumentosMap,
          categoriasPorInstrumento: categoriasPorInstrumento,
        );
      }).toList();

      yield musicos;
    }
  }

  /// ******************************************************************
  /// OBTENER TODOS LOS MÚSICOS ACTIVOS DE LA BANDA
  ///
  /// Recupera los documentos de usuarios donde el campo activo es true.
  /// ******************************************************************
  static Future<List<QueryDocumentSnapshot>> obtenerMusicosActivos(String bandaId) async {
    final snap = await firestore
        .collection('bandas')
        .doc(bandaId)
        .collection('usuarios')
        .where('activo', isEqualTo: true)
        .get();

    return snap.docs;
  }

  /// ******************************************************************
  /// CARGAR DATOS PERSONALES DE TODOS LOS MÚSICOS
  ///
  /// Obtiene los documentos de la colección global usuarios
  /// para los uids proporcionados y devuelve un mapa con la información.
  /// ******************************************************************
  static Future<Map<String, Map<String, dynamic>>> cargarDatosPersonales(List<String> uids) async {
    final Map<String, Map<String, dynamic>> datosPersonales = {};

    final snaps = await Future.wait(uids.map((uid) => firestore.collection('usuarios').doc(uid).get()));

    for (var doc in snaps) {
      datosPersonales[doc.id] = doc.data() ?? {};
    }

    return datosPersonales;
  }

  /// ******************************************************************
  /// OBTENER DATOS COMPLETOS DE UN MÚSICO EN UNA BANDA
  ///
  /// Combina datos globales y datos específicos de la banda
  /// para devolver un objeto EdicionDatosMusico completo.
  /// ******************************************************************
  static Future<EdicionDatosMusico> obtenerDatosMusico(String bandaId, String musicoId) async {
    final usuarioDoc = await firestore.collection('usuarios').doc(musicoId).get();
    final bandaDoc = await firestore.collection('bandas').doc(bandaId).collection('usuarios').doc(musicoId).get();

    final usuarioData = usuarioDoc.data()!;
    final bandaData = bandaDoc.data()!;

    final otrosAccesosList = (bandaData['otrosAccesos'] ?? []).asMap().entries.map<AccesoInstrumento>((entry) {
      final index = entry.key;
      final e = entry.value;
      return AccesoInstrumento(
        key: 'otros_$index', // clave única
        instrumentoId: e['instrumento'] ?? '',
        categoriaId: e['categoria'] ?? '',
        nombre: '',
      );
    }).toList();

    final banda = MusicoEnBanda(
      id: musicoId,
      fechaAlta: (bandaData['fechaAlta'] as Timestamp).toDate(),
      anioPrimeraSemanaSanta: bandaData['anioPrimeraSemanaSanta'],
      instrumento: bandaData['instrumento'],
      categoria: bandaData['categoria'],
      activo: bandaData['activo'] ?? true,
    );

    return EdicionDatosMusico(
      uid: musicoId,
      nombre: usuarioData['nombre'] ?? '',
      email: usuarioData['email'] ?? '',
      telefono: usuarioData['telefono'] ?? '',
      fechaNacimiento: (usuarioData['fechaNacimiento'] as Timestamp?)?.toDate(),
      banda: banda,
      otrosAccesos: otrosAccesosList,
    );
  }

  /// ******************************************************************
  /// OBTIENE NOMBRE DEL MÚSICO, INSTRUMENTO, CATEGORÍA E ICONO
  ///
  /// Devuelve un mapa con los nombres e icono para mostrar en menús.
  /// ******************************************************************
  static Future<Map<String, String?>> obtenerDatosMusicoParaMenu({
    required String bandaId,
    required String musicoId,
  }) async {
    // Datos del músico
    final usuarioDoc = await firestore.collection('usuarios').doc(musicoId).get();
    final usuarioData = usuarioDoc.data();
    final nombreMusico = usuarioData != null ? usuarioData['nombre'] as String? : null;

    // Datos del músico en la banda
    final usuarioBandaDoc = await firestore
        .collection('bandas')
        .doc(bandaId)
        .collection('usuarios')
        .doc(musicoId)
        .get();

    String? instrumentoId;
    String? categoriaId;

    if (usuarioBandaDoc.exists) {
      final data = usuarioBandaDoc.data()!;
      instrumentoId = data['instrumento'] as String?;
      categoriaId = data['categoria'] as String?;
    }

    String? nombreInstrumento;
    String? nombreCategoria;
    String? iconoInstrumento;

    // Obtener nombre del instrumento y categoría
    if (instrumentoId != null && instrumentoId.isNotEmpty) {
      final docInstrumento = await firestore
          .collection('bandas')
          .doc(bandaId)
          .collection('instrumentos')
          .doc(instrumentoId)
          .get();

      if (docInstrumento.exists) {
        final dataInst = docInstrumento.data()!;
        nombreInstrumento = dataInst['nombre'] as String? ?? instrumentoId;
        iconoInstrumento = dataInst['iconoUrl'] as String?;

        final categorias = List<Map<String, dynamic>>.from(dataInst['categorias'] ?? []);
        final categoria = categorias.firstWhere((c) => c['categoriaId'] == categoriaId, orElse: () => {});
        nombreCategoria = categoria.isNotEmpty ? categoria['nombre'] as String? : null;
      } else {
        nombreInstrumento = instrumentoId;
      }
    }

    return {
      'nombreMusico': nombreMusico,
      'nombreInstrumento': nombreInstrumento,
      'nombreCategoria': nombreCategoria,
      'iconoInstrumento': iconoInstrumento,
    };
  }

  /// ******************************************************************
  /// OBTENER DOCUMENTO DE UN MÚSICO
  ///
  /// Devuelve el documento del músico en la colección usuarios de la banda.
  /// Retorna null si no existe.
  /// ******************************************************************
  static Future<Map<String, dynamic>?> obtenerDocumentoMusico({
    required String bandaId,
    required String musicoId,
  }) async {
    final doc = await firestore.collection('bandas').doc(bandaId).collection('usuarios').doc(musicoId).get();
    return doc.exists ? doc.data() : null;
  }

  /// ******************************************************************
  /// GUARDAR DATOS DE UN MÚSICO EN LA BANDA (REFERIDOS A ESA BANDA) Y GLOBALES (DATOS PERSONALES)
  ///
  /// Actualiza los campos proporcionados en la colección usuarios global y en la subcolección de la banda correspondiente.
  /// ******************************************************************
  static Future<void> guardarDatosMusico({
    required String bandaId,
    required String musicoId,

    // Datos globales
    String? nombre,
    String? email,
    String? telefono,
    DateTime? fechaNacimiento,

    // Datos banda
    bool? activo,
    String? instrumento,
    String? categoria,
    int? anioPrimeraSemanaSanta,
    DateTime? fechaAlta,
    List<Map<String, String>>? otrosAccesos,
  }) async {
    final batch = firestore.batch();

    /// ACTUALIZAR USUARIO GLOBAL
    final userRef = firestore.collection('usuarios').doc(musicoId);

    final dataUsuario = <String, dynamic>{};

    if (nombre != null) dataUsuario['nombre'] = nombre;
    if (email != null) dataUsuario['email'] = email;
    if (telefono != null) dataUsuario['telefono'] = telefono;
    if (fechaNacimiento != null) {
      dataUsuario['fechaNacimiento'] = fechaNacimiento;
    }

    // Siempre aseguramos rol musico
    dataUsuario['rol'] = "musico";

    // Añadir bandaId al array bandasId sin duplicar
    dataUsuario['bandasId'] = FieldValue.arrayUnion([bandaId]);

    if (dataUsuario.isNotEmpty) {
      batch.set(userRef, dataUsuario, SetOptions(merge: true));
    }

    /// ACTUALIZAR DATOS DE BANDA
    final bandaUserRef = firestore.collection('bandas').doc(bandaId).collection('usuarios').doc(musicoId);

    final dataBanda = <String, dynamic>{};

    if (activo != null) dataBanda['activo'] = activo;
    if (instrumento != null) dataBanda['instrumento'] = instrumento;
    if (categoria != null) dataBanda['categoria'] = categoria;
    if (anioPrimeraSemanaSanta != null) {
      dataBanda['anioPrimeraSemanaSanta'] = anioPrimeraSemanaSanta;
    }
    if (fechaAlta != null) dataBanda['fechaAlta'] = fechaAlta;
    if (otrosAccesos != null) dataBanda['otrosAccesos'] = otrosAccesos;

    if (dataBanda.isNotEmpty) {
      batch.set(bandaUserRef, dataBanda, SetOptions(merge: true));
    }

    await batch.commit();
  }

  /// ******************************************************************
  /// DESVINCULAR DISPOSITIVO DE UN MÚSICO
  ///
  /// Elimina el deviceId del usuario para permitir otro login desde
  /// un dispositivo distinto.
  /// ******************************************************************
  static Future<void> desvincularDispositivo(String musicoId) async {
    await firestore.collection('usuarios').doc(musicoId).update({'deviceId': FieldValue.delete()});
  }

  /// ******************************************************************
  /// ELIMINAR MÚSICO DE LA BANDA
  ///
  /// Elimina el documento del músico en la banda, todas sus asistencias
  /// y actualiza la colección global de usuarios quitando la banda.
  /// ******************************************************************
  static Future<void> eliminarMusicoDeBanda({required String bandaId, required String musicoId}) async {
    final batch = firestore.batch();

    // Eliminar el documento del músico en la banda
    final musicoBandaRef = firestore.collection('bandas').doc(bandaId).collection('usuarios').doc(musicoId);
    batch.delete(musicoBandaRef);

    // Eliminar todas las asistencias del músico en esa banda
    final asistenciasSnap = await firestore
        .collection('bandas')
        .doc(bandaId)
        .collection('asistencias')
        .where('musicoId', isEqualTo: musicoId)
        .get();

    for (final doc in asistenciasSnap.docs) {
      batch.delete(doc.reference);
    }

    // Quitar la banda de la lista de bandas del usuario
    final usuarioRef = firestore.collection('usuarios').doc(musicoId);
    batch.update(usuarioRef, {
      'bandasId': FieldValue.arrayRemove([bandaId]),
    });

    await batch.commit();
  }
}
