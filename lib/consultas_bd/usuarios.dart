import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConsultasUsuariosBD {
  static final firestore = FirebaseFirestore.instance;
  static final storage = FirebaseAuth.instance;

  /// ********************************************************************
  /// OBTENER NOMBRE DE USUARIO
  ///
  /// Recupera el nombre de un usuario por su UID.
  ///
  /// Parámetros:
  /// - musicoId --> UID del usuario
  ///
  /// Devuelve:
  /// - String con el nombre o "Nombre desconocido" si no existe
  /// ********************************************************************
  static Future<String> obtenerNombreMusico(String musicoId) async {
    final usuarioDoc = await firestore.collection('usuarios').doc(musicoId).get();
    if (!usuarioDoc.exists) {
      return "Nombre desconocido";
    }

    final usuarioData = usuarioDoc.data();
    if (usuarioData == null) return "Nombre desconocido";

    return usuarioData['nombre'] ?? "Nombre desconocido";
  }

  /// ********************************************************************
  /// CREAR NUEVO USUARIO Y ASOCIARLO A UNA BANDA
  ///
  /// Crea un usuario en Firebase Auth y Firestore, y lo agrega a la banda.
  ///
  /// Parámetros:
  /// - bandaId --> ID de la banda
  /// - nombre --> Nombre del usuario
  /// - email --> Email del usuario
  /// - password --> Contraseña
  /// - telefono --> Teléfono (opcional)
  /// - rol --> Rol del usuario (opcional, default "musico")
  /// - fechaNacimiento --> Fecha de nacimiento (opcional)
  /// - activo --> Si el usuario está activo (default true)
  /// - instrumento --> Instrumento del músico (opcional)
  /// - categoria --> Categoría del instrumento (opcional)
  /// - anioPrimeraSemanaSanta --> Año primera Semana Santa (opcional)
  /// - fechaAlta --> Fecha de alta en la banda (opcional)
  /// - otrosAccesos --> Lista de otros accesos (opcional)
  /// ********************************************************************
  static Future<void> crearUsuarioYMusico({
    required String bandaId,
    required String nombre,
    required String email,
    required String password,
    String? telefono,
    String? rol,
    DateTime? fechaNacimiento,
    bool activo = true,
    String? instrumento,
    String? categoria,
    int? anioPrimeraSemanaSanta,
    DateTime? fechaAlta,
    List<Map<String, String>>? otrosAccesos,
  }) async {
    String uid;

    try {
      // Intentar crear usuario en Auth
      final cred = await storage.createUserWithEmailAndPassword(email: email, password: password);

      uid = cred.user!.uid;

      // Crear documento nuevo en usuarios
      await firestore.collection('usuarios').doc(uid).set({
        'nombre': nombre,
        'email': email,
        'telefono': telefono ?? '',
        'fechaNacimiento': fechaNacimiento,
        'bandasId': [bandaId],
        'activo': activo,
        'rol': rol ?? "musico",
      });
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // Buscar usuario existente por email
        final query = await firestore.collection('usuarios').where('email', isEqualTo: email).limit(1).get();

        if (query.docs.isEmpty) {
          throw Exception("El usuario existe en Auth pero no en Firestore.");
        }

        final doc = query.docs.first;
        uid = doc.id;

        // Añadir bandaId al array bandasId
        await firestore.collection('usuarios').doc(uid).update({
          'bandasId': FieldValue.arrayUnion([bandaId]),
        });
      } else {
        rethrow;
      }
    }

    // Guardar datos del músico en la subcolección de la banda
    await firestore.collection('bandas').doc(bandaId).collection('usuarios').doc(uid).set({
      'instrumento': instrumento ?? '',
      'categoria': categoria ?? '',
      'anioPrimeraSemanaSanta': anioPrimeraSemanaSanta,
      'fechaAlta': fechaAlta,
      'otrosAccesos': otrosAccesos ?? [],
      'activo': activo,
    });
  }

  /// ********************************************************************
  /// ACTUALIZAR DATOS PERSONALES DEL USUARIO
  ///
  /// Modifica los campos del documento en "usuarios/uid".
  ///
  /// Parámetros:
  /// - uid --> UID del usuario
  /// - nombre --> Nombre (opcional)
  /// - email --> Email (opcional)
  /// - telefono --> Teléfono (opcional)
  /// - fechaNacimiento --> Fecha de nacimiento (opcional)
  /// - rol --> Rol del usuario (opcional)
  /// ********************************************************************
  static Future<void> actualizarUsuario({
    required String uid,
    String? nombre,
    String? email,
    String? telefono,
    DateTime? fechaNacimiento,
    String? rol,
  }) async {
    final data = <String, dynamic>{};
    if (nombre != null) data['nombre'] = nombre;
    if (email != null) data['email'] = email;
    if (telefono != null) data['telefono'] = telefono;
    if (fechaNacimiento != null) data['fechaNacimiento'] = fechaNacimiento;
    if (rol != null) data['rol'] = rol;
    if (data.isNotEmpty) {
      await firestore.collection('usuarios').doc(uid).update(data);
    }
  }
}
