import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ritmo_app/modelos/musico_en_banda.dart';
import 'package:ritmo_app/modelos/usuario.dart';

class ConsultasLoginBD {
  static final FirebaseAuth auth = FirebaseAuth.instance;
  static final FirebaseFirestore firestore = FirebaseFirestore.instance;

  /// ******************************************************************
  /// ENVIAR EMAIL PARA RESETEAR CONTRASEÑA
  ///
  /// Envía un correo de recuperación de contraseña al usuario.
  /// Maneja errores específicos de FirebaseAuth y los transforma
  /// en mensajes más claros para mostrar en la interfaz.
  /// ******************************************************************
  static Future<void> enviarResetPassword(String email) async {
    try {
      await auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      // Transforma el error específico de Firebase en un mensaje claro
      switch (e.code) {
        case 'invalid-email':
          throw Exception("El formato del correo electrónico no es válido.");
        case 'user-not-found':
          throw Exception("Si el correo está registrado, recibirás un email con instrucciones.");
        case 'network-request-failed':
          throw Exception("Error de conexión. Revisa tu internet.");
        case 'too-many-requests':
          throw Exception("Has solicitado demasiados intentos. Inténtalo más tarde.");
        default:
          throw Exception("Ocurrió un error inesperado: ${e.message}");
      }
    } catch (e) {
      // Cualquier otro error inesperado
      throw Exception("Error desconocido: $e");
    }
  }

  /// ******************************************************************
  /// LOGIN CON EMAIL Y CONTRASEÑA
  ///
  /// Autentica al usuario usando FirebaseAuth.
  /// Una vez autenticado, obtiene sus datos desde Firestore
  /// y devuelve el modelo Usuario correspondiente.
  /// ******************************************************************
  static Future<Usuario> login({required String email, required String password}) async {
    try {
      final credenciales = await auth.signInWithEmailAndPassword(email: email, password: password);
      final uid = credenciales.user!.uid;

      final docUsuario = await firestore.collection('usuarios').doc(uid).get();
      if (!docUsuario.exists) throw Exception("Usuario no encontrado");

      return Usuario.fromFirestore(docUsuario);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw Exception("Correo o contraseña incorrectos.");
        case 'wrong-password':
          throw Exception("Correo o contraseña incorrectos.");
        case 'invalid-email':
          throw Exception("El correo electrónico no es válido.");
        case 'network-request-failed':
          throw Exception("Error de conexión. Revisa tu internet.");
        default:
          throw Exception("Error de autenticación: ${e.message}");
      }
    } catch (e) {
      throw Exception("Error al iniciar sesión: $e");
    }
  }

  /// ******************************************************************
  /// ASEGURAR QUE UN MÚSICO EXISTA EN LA BANDA
  ///
  /// Comprueba si el músico ya está registrado dentro de la banda.
  /// Si no existe, lo crea automáticamente con fecha de alta y estado activo.
  /// ******************************************************************
  static Future<void> asegurarMusicoEnBanda({required String bandaId, required String musicoId}) async {
    final docMusico = firestore.collection('bandas').doc(bandaId).collection('usuarios').doc(musicoId);
    final doc = await docMusico.get();
    if (!doc.exists) {
      final musico = MusicoEnBanda(id: musicoId, fechaAlta: DateTime.now(), activo: true);
      await docMusico.set(musico.toFirestore());
    }
  }

  /// ******************************************************************
  /// COMPROBAR LOGIN AUTOMÁTICO
  ///
  /// Verifica si existe un usuario autenticado en el dispositivo.
  /// Si existe, obtiene sus datos desde Firestore y devuelve
  /// el modelo Usuario. Si no, devuelve null.
  /// ******************************************************************
  static Future<Usuario?> loginAutomatico() async {
    final usuario = auth.currentUser;
    if (usuario == null) return null;

    final doc = await firestore.collection('usuarios').doc(usuario.uid).get();
    if (!doc.exists) return null;

    return Usuario.fromFirestore(doc);
  }

  /// ******************************************************************
  /// VALIDAR DISPOSITIVO SEGÚN EMAIL
  ///
  /// Comprueba si el dispositivo está autorizado para el usuario.
  /// Los administradores pueden acceder sin restricción.
  /// Si el dispositivo ya está vinculado a otro usuario, se bloquea el acceso.
  /// ******************************************************************
  static Future<void> validarDispositivo(String deviceId, String email) async {
    // Obtener el usuario por email
    final queryUsuario = await firestore.collection('usuarios').where('email', isEqualTo: email).get();

    if (queryUsuario.docs.isEmpty) {
      throw Exception("Usuario no encontrado");
    }

    final datosUsuario = queryUsuario.docs.first.data();
    final rolUsuario = datosUsuario['rol'] ?? '';

    // Si es admin, puede entrar sin restricción
    if (rolUsuario == 'admin') return;

    // Si no es admin, verificar si el deviceId ya está vinculado
    final queryDevice = await firestore.collection('usuarios').where('deviceId', isEqualTo: deviceId).get();

    if (queryDevice.docs.isEmpty) {
      // DeviceId no existe, todo bien
      return;
    }

    final datosDevice = queryDevice.docs.first.data();
    final emailDevice = datosDevice['email'] ?? '';
    final nombreDevice = datosDevice['nombre'] ?? '';

    if (emailDevice == email) {
      // El dispositivo ya está vinculado a este usuario, todo bien
      return;
    }

    // El dispositivo está vinculado a otro usuario
    throw Exception("Este dispositivo ya está vinculado a $nombreDevice.");
  }

  /// ******************************************************************
  /// VINCULAR DISPOSITIVO AL USUARIO (PARA EVITAR AUTOFICHAR A UN EVENTO CON DISTINTAS CREDENCIALES)
  ///
  /// Asocia el dispositivo al usuario si aún no tiene uno asignado.
  /// Los administradores no tienen restricción.
  /// Si ya está vinculado a otro dispositivo, se bloquea.
  /// ******************************************************************
  static Future<void> vincularDispositivo(String uid, String deviceId, {required String rol}) async {
    final docUsuario = await firestore.collection('usuarios').doc(uid).get();
    if (!docUsuario.exists) throw Exception("Usuario no encontrado");

    final usuario = Usuario.fromFirestore(docUsuario);

    // Si es admin, siempre puede iniciar sesión, no bloqueamos
    if (rol == 'admin') return;

    // Para músicos, validamos dispositivo
    if (usuario.idDispositivo == null) {
      await firestore.collection('usuarios').doc(uid).update({'deviceId': deviceId});
    } else if (usuario.idDispositivo != deviceId) {
      throw Exception("Este usuario ya está vinculado a otro dispositivo.");
    }
  }

  /// ******************************************************************
  /// VALIDAR CONTRASEÑA DE SUPERADMIN
  ///
  /// Comprueba si la contraseña introducida coincide con la
  /// almacenada en la colección "password".
  /// Devuelve true si coincide, false en caso contrario.
  /// ******************************************************************
  static Future<bool> validarSuperAdmin(String passIntroducida) async {
    final doc = await firestore.collection("password").doc("password").get();
    final passCorrecta = doc.data()?["password"] ?? "";
    return passIntroducida == passCorrecta;
  }

  /// ******************************************************************
  /// CERRAR SESIÓN DE USUARIO
  ///
  /// Cierra la sesión actual del usuario autenticado
  /// en FirebaseAuth.
  /// ******************************************************************
  static Future<void> cerrarSesion() async {
    await FirebaseAuth.instance.signOut();
  }
}
