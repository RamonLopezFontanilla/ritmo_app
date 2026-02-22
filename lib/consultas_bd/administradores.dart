import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ritmo_app/modelos/administrador.dart';

/// ********************************************************
/// Clase estática encargada de gestionar todas las operaciones relacionadas con los administradores en Firebase.
///
/// RESPONSABILIDADES:
/// - Obtener lista completa de administradores
/// - Obtener un administrador por UID
/// - Crear un nuevo administrador en Auth y Firestore
///
/// Utiliza:
/// - FirebaseFirestore --> Base de datos
/// - FirebaseAuth --> Autenticación
/// ********************************************************
class ConsultasAdministradoresBD {
  static final firestore = FirebaseFirestore.instance;
  static final FirebaseAuth auth = FirebaseAuth.instance;

  /// ******************************************************************
  /// OBTENER TODOS LOS ADMINISTRADORES
  ///
  /// Realiza una consulta a la colección 'usuarios' filtrando únicamente los documentos cuyo rol sea 'admin'.
  ///
  /// Devuelve:
  /// - Lista de objetos [Administrador]
  ///
  /// Funcionamiento:
  /// - Se obtiene el snapshot de la consulta
  /// - Se transforma cada documento en un objeto Administrador
  /// ******************************************************************
  static Future<List<Administrador>> obtenerAdministradores() async {
    final snapshot = await firestore.collection('usuarios').where('rol', isEqualTo: 'admin').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return Administrador(
        uid: doc.id,
        email: data['email'] ?? '',
        bandasId: List<String>.from(data['bandasId'] ?? []),
      );
    }).toList();
  }

  /// ******************************************************************
  /// OBTENER UN ADMINISTRADOR POR UID
  ///
  /// Parámetros:
  /// - uid → Identificador único del administrador
  ///
  /// Devuelve:
  /// - Administrador si existe
  /// - null si el documento no existe o está vacío
  ///
  /// Utiliza el método fromMap del modelo para construir el objeto de forma centralizada.
  /// ******************************************************************
  static Future<Administrador?> obtenerAdministrador(String uid) async {
    final doc = await firestore.collection('usuarios').doc(uid).get();

    if (!doc.exists || doc.data() == null) return null;

    return Administrador.fromMap(doc.id, doc.data()!);
  }

  /// ******************************************************************
  /// CREAR NUEVO ADMINISTRADOR
  ///
  /// Parámetros:
  /// - email --> Correo del administrador
  /// - password --> Contraseña de acceso
  /// - bandaId (opcional) --> Banda inicial asociada
  ///
  /// Pasos:
  /// - Se crea el usuario en FirebaseAuth
  /// - Se obtiene el UID generado
  /// - Se crea el documento correspondiente en Firestore
  /// - Se asigna rol 'admin'
  /// - Se inicializa la lista de bandas (si existe)
  ///
  /// Devuelve:
  /// - Objeto Administrador si la creación fue exitosa
  /// - null si ocurre un error de autenticación
  ///
  /// Nota:
  /// El bloque try-catch captura únicamente errores de FirebaseAuth (ej: email ya registrado).
  /// ******************************************************************
  static Future<Administrador?> crearAdministrador(String email, String password, {String? bandaId}) async {
    try {
      final cred = await auth.createUserWithEmailAndPassword(email: email, password: password);
      final uid = cred.user!.uid;

      final docRef = firestore.collection('usuarios').doc(uid);
      await docRef.set({
        'nombre': 'Administrador',
        'rol': 'admin',
        'email': email,
        'bandasId': bandaId != null ? [bandaId] : [],
      });

      return Administrador(uid: uid, email: email, bandasId: bandaId != null ? [bandaId] : []);
    } on FirebaseAuthException {
      return null;
    }
  }
}
