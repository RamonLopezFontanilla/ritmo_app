import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:ritmo_app/modelos/instrumento.dart';
import 'package:ritmo_app/modelos/otros_accesos_musico.dart';

/// ********************************************************
/// Clase estática responsable de todas las operaciones relacionadas con:
///
/// - Gestión de instrumentos
/// - Gestión de categorías internas
/// - Subida y obtención de iconos
/// - Validaciones de duplicados
/// - Validaciones antes de eliminación
///
/// Toda la información se almacena en la subcolección "instrumentos" dentro del documento de cada banda.
/// ********************************************************
class ConsultasInstrumentosBD {
  static final firestore = FirebaseFirestore.instance;
  static final FirebaseStorage storage = FirebaseStorage.instance;

  /// Caché de URLs en memoria para no pedirlas repetidamente
  static final Map<String, String> cacheImagenes = {};

  /// ************************************************************
  /// STREAM DE INSTRUMENTOS
  ///
  /// Devuelve un Stream en tiempo real de todos los instrumentos de una banda, ordenados por nombre.
  ///
  /// Conversión automática a objeto [Instrumento].
  /// ************************************************************
  static Stream<List<Instrumento>> streamListaInstrumentos(String bandaId) {
    return firestore
        .collection('bandas')
        .doc(bandaId)
        .collection('instrumentos')
        .orderBy('nombre')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Instrumento.fromMap(doc.id, doc.data())).toList());
  }

  /// ************************************************************
  /// OBTENER NOMBRE DE INSTRUMENTO + CATEGORÍA
  ///
  /// Devuelve:
  /// - "Instrumento"
  /// - "Instrumento - Categoría"
  ///
  /// Si no existe o hay error devuelve:
  /// - "Instrumento desconocido"
  /// ************************************************************
  static Future<String> obtenerNombreInstrumentoCategoria(
    String? instrumentoId,
    String? categoriaId,
    String bandaId,
  ) async {
    if (instrumentoId == null || instrumentoId.isEmpty) return 'Instrumento desconocido';

    try {
      final doc = await firestore.collection('bandas').doc(bandaId).collection('instrumentos').doc(instrumentoId).get();

      if (!doc.exists) return 'Instrumento desconocido';

      final data = doc.data();
      final nombreInstrumento = data?['nombre'] ?? 'Instrumento desconocido';
      final categorias = List<Map<String, dynamic>>.from(data?['categorias'] ?? []);

      if (categoriaId != null && categoriaId.isNotEmpty) {
        final categoria = categorias.firstWhere((c) => c['categoriaId'] == categoriaId, orElse: () => {});
        final nombreCategoria = categoria['nombre'];
        if (nombreCategoria != null && nombreCategoria.isNotEmpty) {
          return '$nombreInstrumento - $nombreCategoria';
        }
      }

      return nombreInstrumento;
    } catch (e) {
      return 'Instrumento desconocido';
    }
  }

  /// ************************************************************
  /// OBTENER LISTA DE ACCESOS A INSTRUMENTOS
  ///
  /// Genera una lista plana de accesos combinando:
  /// - Instrumentos sin categorías
  /// - Instrumentos con categorías
  ///
  /// Se utiliza normalmente para:
  /// - Selectores
  /// - Permisos de músico
  ///
  /// Ordenado alfabéticamente por nombre final.
  /// ************************************************************
  static Future<List<AccesoInstrumento>> obtenerAccesosInstrumentos(String bandaId) async {
    final snap = await firestore.collection('bandas').doc(bandaId).collection('instrumentos').get();

    final List<AccesoInstrumento> lista = [];

    for (final doc in snap.docs) {
      final data = doc.data();
      final instrumentoId = doc.id;
      final instrumentoNombre = data['nombre'] ?? instrumentoId;

      final List categorias = data['categorias'] ?? [];

      if (categorias.isEmpty) {
        // Instrumento sin categorías
        lista.add(
          AccesoInstrumento(
            key: '$instrumentoId|',
            instrumentoId: instrumentoId,
            categoriaId: null,
            nombre: instrumentoNombre,
          ),
        );
      } else {
        // Instrumento con categorías
        for (final c in categorias) {
          if (c is Map<String, dynamic>) {
            final categoriaId = c['categoriaId'];
            final categoriaNombre = c['nombre'] ?? categoriaId;

            lista.add(
              AccesoInstrumento(
                key: '$instrumentoId|$categoriaId',
                instrumentoId: instrumentoId,
                categoriaId: categoriaId,
                nombre: '$instrumentoNombre - $categoriaNombre',
              ),
            );
          }
        }
      }
    }

    lista.sort((a, b) => (a.nombre).compareTo(b.nombre));
    return lista;
  }

  /// ************************************************************
  /// OBTENER MAPA DE INSTRUMENTOS Y CATEGORÍAS
  ///
  /// Devuelve:
  /// {
  ///   "instrumentos": {id: nombre},
  ///   "categorias": {
  ///       instrumentoId: {categoriaId: nombre}
  ///   }
  /// }
  ///
  /// Útil para:
  /// - Renderizado rápido
  /// - Construcción de selectores complejos
  /// ************************************************************
  static Future<Map<String, dynamic>> obtenerInstrumentosYCategorias(String bandaId) async {
    final instrumentosSnap = await firestore.collection('bandas').doc(bandaId).collection('instrumentos').get();

    // los instrumentos se guardan con (idInstrumento, nombreInstrumento)
    final Map<String, String> mapaInstrumentos = {};
    // las caretorias se guardan con (idInstrumento, (idCategoría y nombreCategoría))
    final Map<String, Map<String, String>> mapaCategorias = {};

    for (var doc in instrumentosSnap.docs) {
      final data = doc.data();
      final nombreInstrumento = (data['nombre'] as String?) ?? 'Sin instrumento';
      mapaInstrumentos[doc.id] = nombreInstrumento;

      final List categorias = (data['categorias'] as List?) ?? [];
      final Map<String, String> tempCat = {};
      for (var c in categorias) {
        if (c is Map<String, dynamic>) {
          final id = c['categoriaId']?.toString() ?? c['id']?.toString();
          final nombre = c['nombre']?.toString() ?? '';
          if (id != null) tempCat[id] = nombre;
        }
      }
      mapaCategorias[doc.id] = tempCat;
    }

    return {'instrumentos': mapaInstrumentos, 'categorias': mapaCategorias};
  }

  /// ************************************************************
  /// OBTENER INSTRUMENTO POR ID
  ///
  /// Devuelve:
  /// - [Instrumento] si existe
  /// - null si no existe
  /// ************************************************************
  static Future<Instrumento?> obtenerInstrumento({required String bandaId, required String instrumentoId}) async {
    final doc = await firestore.collection('bandas').doc(bandaId).collection('instrumentos').doc(instrumentoId).get();

    if (!doc.exists) return null;

    return Instrumento.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  /// ************************************************************
  /// OBTENER URL DE IMAGEN DESDE STORAGE
  ///
  /// Usa caché en memoria para evitar múltiples
  /// solicitudes de la misma URL.
  ///
  /// Devuelve:
  /// - URL válida
  /// - "" si hay error
  /// ************************************************************
  static Future<String> obtenerUrlImagen(String path) async {
    if (path.isEmpty) return "";
    if (cacheImagenes.containsKey(path)) return cacheImagenes[path]!;

    try {
      final ref = storage.refFromURL(path);
      final url = await ref.getDownloadURL();
      cacheImagenes[path] = url;
      return url;
    } catch (e) {
      return "";
    }
  }

  /// *********************************************************************
  ///     --- Obtener iconos almacenados de los instrumentos ---
  /// *********************************************************************
  static Future<List<String>> obtenerIconosInstrumentos(String bandaId) async {
    final snapshot = await firestore.collection('bandas').doc(bandaId).collection('instrumentos').get();

    final urls = snapshot.docs
        .map((doc) => doc.data()['iconoUrl'] as String? ?? '')
        .where((url) => url.isNotEmpty)
        .toSet() // evita duplicados
        .toList();

    return urls;
  }

  /// ************************************************************
  /// VALIDAR SI EL NOMBRE YA EXISTE
  ///
  /// Comparación case-insensitive.
  ///
  /// Se usa tanto para:
  /// - Crear instrumento
  /// - Editar instrumento
  /// ************************************************************
  static Future<bool> nombreInstrumentoExiste({
    required String bandaId,
    required String nombre,
    String? excluirInstrumentoId,
  }) async {
    // Traemos todos los instrumentos de la banda
    final snapshot = await firestore.collection('bandas').doc(bandaId).collection('instrumentos').get();

    final nombreLower = nombre.toLowerCase();

    for (var doc in snapshot.docs) {
      final nombreDoc = (doc.data()['nombre'] ?? '') as String;
      // Comparamos en minúsculas
      if (nombreDoc.toLowerCase() == nombreLower) {
        // Si es edición, ignoramos el mismo instrumento
        if (excluirInstrumentoId != null && doc.id == excluirInstrumentoId) {
          continue;
        }
        return true; // ya existe otro con ese nombre
      }
    }

    return false; // no hay duplicados
  }

  /// ************************************************************
  /// GUARDAR / ACTUALIZAR INSTRUMENTO
  ///
  /// - Sube imagen si existe.
  /// - Guarda categorías.
  /// - Guarda carpetaPartituras solo si no hay categorías.
  /// ************************************************************
  static Future<void> guardarInstrumento({
    required String bandaId,
    required Instrumento instrumento,
    File? imagen,
  }) async {
    String? urlImagen = instrumento.iconoUrl;

    // Subir imagen si hay
    if (imagen != null) {
      final fileName = "${DateTime.now().millisecondsSinceEpoch}_${imagen.path.split('/').last}";

      urlImagen = await storage
          .ref()
          .child("bandas/$bandaId/iconos/$fileName")
          .putFile(imagen)
          .then((snap) => snap.ref.getDownloadURL());
    }

    final docRef = firestore.collection('bandas').doc(bandaId).collection('instrumentos').doc(instrumento.id);

    await docRef.set({
      'nombre': instrumento.nombre,
      'iconoUrl': urlImagen,
      'carpetaPartituras': instrumento.categorias.isEmpty ? instrumento.carpetaPartituras : null,
      'categorias': instrumento.categorias.map((c) => c.toMap()).toList(),
    });
  }

  /// ************************************************************
  /// VALIDAR SI SE PUEDE ELIMINAR
  ///
  /// Comprueba si algún usuario tiene:
  /// - Instrumento principal
  /// - Instrumento en otros accesos
  ///
  /// Devuelve:
  /// - true si se puede eliminar
  /// - false si está en uso
  /// ************************************************************
  static Future<bool> instrumentoSePuedeEliminar({required String bandaId, required String instrumentoId}) async {
    try {
      final snapshot = await firestore.collection('bandas').doc(bandaId).collection('usuarios').get();

      for (var doc in snapshot.docs) {
        final data = doc.data();

        // Instrumento principal
        final instrumentoPrincipal = data['instrumento'] as String? ?? '';
        if (instrumentoPrincipal == instrumentoId) return false;

        // Otros instrumentos (lista)
        final otrosInstrumentosRaw = data['otrosAccesos']?['instrumento'];
        final otrosInstrumentos = (otrosInstrumentosRaw is List)
            ? otrosInstrumentosRaw.whereType<String>().toList()
            : <String>[];

        if (otrosInstrumentos.contains(instrumentoId)) return false;
      }

      // Ningún músico lo tiene
      return true;
    } catch (e) {
      return true;
    }
  }

  /// ************************************************************
  /// ELIMINAR INSTRUMENTO
  ///
  /// Se recomienda validar previamente con:
  /// instrumentoSePuedeEliminar()
  /// ************************************************************
  static Future<void> eliminarInstrumento({required String bandaId, required String instrumentoId}) async {
    await firestore.collection('bandas').doc(bandaId).collection('instrumentos').doc(instrumentoId).delete();
  }
}
