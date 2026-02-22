import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ritmo_app/consultas_bd/partituras.dart';
import 'package:ritmo_app/modelos/genero.dart';

/// ********************************************************
/// Clase estática responsable de todas las operaciones relacionadas con:
///
/// - Gestión de géneros musicales
/// - Consulta en tiempo real
/// - Creación y actualización
/// - Validación de uso en partituras
///
/// Toda la información se almacena en la subcolección "generos" dentro del documento de cada banda.
/// ********************************************************
class ConsultasGenerosBD {
  static final firestore = FirebaseFirestore.instance;

  /// ******************************************************************
  /// STREAM DE GÉNEROS DE UNA BANDA
  ///
  /// Obtiene un Stream en tiempo real de todos los géneros
  /// pertenecientes a una banda.
  ///
  /// Características:
  /// - Ordenados alfabéticamente por nombre.
  /// - Conversión automática a objetos [Genero].
  ///
  /// Devuelve:
  /// - Stream(List(Genero))
  /// ******************************************************************
  static Stream<List<Genero>> streamGeneros(String bandaId) {
    return firestore
        .collection('bandas')
        .doc(bandaId)
        .collection('generos')
        .orderBy('nombre')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Genero.fromMap(doc.id, doc.data())).toList());
  }

  /// ******************************************************************
  /// OBTENER MAPA DE GÉNEROS
  ///
  /// Recupera todos los géneros de una banda en formato
  /// clave-valor.
  ///
  /// Clave   --> generoId
  /// Valor   --> nombre del género
  ///
  /// Uso:
  /// - Mostrar nombre a partir de un ID.
  /// - Construir dropdowns.
  ///
  /// Devuelve:
  /// - Map(String, String)
  /// ******************************************************************
  static Future<Map<String, String>> obtenerGeneros(String bandaId) async {
    final snapshot = await firestore.collection('bandas').doc(bandaId).collection('generos').get();

    return {for (var d in snapshot.docs) d.id: d['nombre'].toString()};
  }

  /// ******************************************************************
  /// REFERENCIA DIRECTA A LA COLECCIÓN DE GÉNEROS
  ///
  /// Devuelve el CollectionReference de la subcolección "generos" de una banda.
  ///
  /// Se utiliza para reutilización desde otros métodos.
  /// ******************************************************************
  static CollectionReference<Map<String, dynamic>> generosRef(String bandaId) {
    return firestore.collection('bandas').doc(bandaId).collection('generos');
  }

  /// ******************************************************************
  /// REFERENCIA DIRECTA A LA COLECCIÓN DE GÉNEROS
  ///
  /// Devuelve el CollectionReference de la subcolección "generos" de una banda.
  ///
  /// Se utiliza para consultas avanzadas o reutilización desde otras clases.
  /// ******************************************************************
  static Future<Genero?> obtenerGeneroPorId(String bandaId, String generoId) async {
    final doc = await firestore.collection('bandas').doc(bandaId).collection('generos').doc(generoId).get();

    if (!doc.exists) return null;

    return Genero.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  /// ******************************************************************
  /// BUSCAR GÉNERO POR NOMBRE NORMALIZADO
  ///
  /// Permite evitar duplicados comparando el campo "nombreLower" (versión en minúsculas).
  ///
  /// Parámetros:
  /// - nombreLower --> Nombre ya normalizado en minúsculas
  ///
  /// Devuelve:
  /// - QuerySnapshot con posibles coincidencias
  /// ******************************************************************
  static Future<QuerySnapshot<Map<String, dynamic>>> buscarGeneroPorNombreNormalizado(
    String bandaId,
    String nombreLower,
  ) {
    return generosRef(bandaId).where('nombreLower', isEqualTo: nombreLower).get();
  }

  /// ******************************************************************
  /// BUSCAR GÉNERO POR NOMBRE NORMALIZADO
  ///
  /// Permite evitar duplicados comparando el campo "nombreLower" (versión en minúsculas).
  ///
  /// Parámetros:
  /// - nombreLower --> Nombre ya normalizado en minúsculas
  ///
  /// Devuelve:
  /// - QuerySnapshot con posibles coincidencias
  /// ******************************************************************
  static Future<DocumentReference<Map<String, dynamic>>> crearGenero(
    String bandaId,
    String nombre,
    String nombreLower,
  ) {
    return generosRef(bandaId).add({'nombre': nombre, 'nombreLower': nombreLower});
  }

  /// ******************************************************************
  /// BUSCAR GÉNERO POR NOMBRE NORMALIZADO
  ///
  /// Permite evitar duplicados comparando el campo "nombreLower" (versión en minúsculas).
  ///
  /// Parámetros:
  /// - nombreLower --> Nombre ya normalizado en minúsculas
  ///
  /// Devuelve:
  /// - QuerySnapshot con posibles coincidencias
  /// ******************************************************************
  static Future<void> actualizarGenero(String bandaId, String generoId, String nombre, String nombreLower) {
    return generosRef(bandaId).doc(generoId).update({'nombre': nombre, 'nombreLower': nombreLower});
  }

  /// ******************************************************************
  /// COMPROBAR SI UN GÉNERO TIENE PARTITURAS ASOCIADAS
  ///
  /// Consulta la colección de partituras filtrando por el ID del género.
  ///
  /// Se limita a 1 resultado para optimizar rendimiento.
  ///
  /// Devuelve:
  /// - true si existe al menos una partitura asociada.
  /// - false si no está en uso.
  ///
  /// Se utiliza para evitar eliminar géneros en uso.
  /// ******************************************************************
  static Future<bool> generoTienePartituras(String bandaId, String generoId) async {
    final usadas = await ConsultasPartiturasBD.partiturasRef(
      bandaId,
    ).where('genero', isEqualTo: generoId).limit(1).get();

    return usadas.docs.isNotEmpty;
  }

  /// ******************************************************************
  /// ELIMINAR GÉNERO
  ///
  /// Elimina el documento correspondiente al género.
  ///
  /// Recomendación:
  /// - Validar previamente que no tenga partituras asociadas.
  /// ******************************************************************
  static Future<void> eliminarGenero(String bandaId, String generoId) {
    return generosRef(bandaId).doc(generoId).delete();
  }
}
