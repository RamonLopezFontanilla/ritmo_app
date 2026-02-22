import 'package:cloud_firestore/cloud_firestore.dart';

class ConsultasParametrosBD {
  static final firestore = FirebaseFirestore.instance;

  /// ******************************************************************
  /// OBTENER PERMISOS DE EDICIÓN PARA LOS MÚSICOS
  ///
  /// Consulta el documento "permisos" dentro de la subcolección "parametros" de la banda y devuelve un mapa con los permisos de edición.
  ///
  /// Devuelve:
  /// - Mapa [String, bool] con los campos editables y su estado.
  /// ******************************************************************
  static Future<Map<String, bool>> obtenerPermisosEdicion(String bandaId) async {
    final doc = await firestore.collection('bandas').doc(bandaId).collection('parametros').doc('permisos').get();

    final permisos = {
      'nombre': false,
      'telefono': false,
      'fechaNacimiento': false,
      'fechaAlta': false,
      'primerAnoSemanaSanta': false,
      'instrumento': false,
      'categoria': false,
      'otrosAccesos': false,
    };

    if (doc.exists && doc.data() != null) {
      doc.data()!.forEach((k, v) {
        if (v is bool && permisos.containsKey(k)) {
          permisos[k] = v;
        }
      });
    }

    return permisos;
  }

  /// ******************************************************************
  /// GUARDAR PERMISOS DE EDICIÓN
  ///
  /// Sobrescribe el documento "permisos" dentro de la subcolección
  /// "parametros" de la banda con los permisos proporcionados.
  /// ******************************************************************
  static Future<void> guardarPermisosEdicion(String bandaId, Map<String, bool> permisos) async {
    await firestore.collection('bandas').doc(bandaId).collection('parametros').doc('permisos').set(permisos);
  }

  /// ******************************************************************
  /// OBTENER PARÁMETROS DE UNA BANDA
  ///
  /// Consulta el documento principal de la banda y devuelve el campo "parametros" si existe.
  ///
  /// Devuelve:
  /// - Mapa [String, dynamic] con los parámetros generales de la banda o null si no existe.
  /// ******************************************************************
  static Future<Map<String, dynamic>?> obtenerParametrosBanda(String bandaId) async {
    final doc = await firestore.collection('bandas').doc(bandaId).get();
    if (!doc.exists || doc.data() == null) return null;

    final data = doc.data()!;
    return data['parametros'] as Map<String, dynamic>?;
  }

  /// ******************************************************************
  /// OBTENER PARÁMETRO UMBRAL DE RETRASO
  ///
  /// Consulta el documento "retraso" dentro de la subcolección "parametros" de la banda y devuelve los minutos configurados como umbral.
  ///
  /// Devuelve:
  /// - Entero con los minutos de retraso (por defecto 30 si no existe)
  /// ******************************************************************
  static Future<int> obtenerUmbralRetraso(String bandaId) async {
    final doc = await firestore.collection('bandas').doc(bandaId).collection('parametros').doc('retraso').get();

    if (!doc.exists) return 30;
    return doc.data()?['minutos'] ?? 30;
  }
}
