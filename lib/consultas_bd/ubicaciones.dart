import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ritmo_app/modelos/ubicacion.dart';

class ConsultasUbicacionesBD {
  static final firestore = FirebaseFirestore.instance;

  /// ********************************************************************
  /// OBTENER STREAM DE UBICACIONES
  ///
  /// Devuelve un Stream con todas las ubicaciones de una banda,
  /// ordenadas alfabéticamente por nombre.
  ///
  /// Parámetros:
  /// - bandaId --> ID de la banda
  ///
  /// Devuelve:
  /// - Stream(List(Ubicacion))
  /// ********************************************************************
  static Stream<List<Ubicacion>> streamUbicaciones(String bandaId) {
    return firestore
        .collection('bandas')
        .doc(bandaId)
        .collection('ubicaciones')
        .orderBy('nombre')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Ubicacion.fromMap(doc.id, doc.data())).toList());
  }

  /// ********************************************************************
  /// GUARDAR O ACTUALIZAR UBICACIÓN
  ///
  /// Crea una nueva ubicación o actualiza una existente.
  ///
  /// Parámetros:
  /// - bandaId --> ID de la banda
  /// - ubicacionId --> ID de la ubicación (null para crear)
  /// - ubicacion --> Objeto Ubicacion con los datos
  /// ********************************************************************
  static Future<void> guardarUbicacion({
    required String bandaId,
    String? ubicacionId,
    required Ubicacion ubicacion,
  }) async {
    final ref = firestore.collection('bandas').doc(bandaId).collection('ubicaciones');

    final data = ubicacion.toMap();
    data['updatedAt'] = FieldValue.serverTimestamp();

    if (ubicacionId != null) {
      await ref.doc(ubicacionId).update(data);
    } else {
      data['createdAt'] = FieldValue.serverTimestamp();
      await ref.add(data);
    }
  }

  /// ********************************************************************
  /// OBTENER NOMBRE DE UBICACIÓN
  ///
  /// Recupera el nombre de una ubicación dado su ID.
  ///
  /// Parámetros:
  /// - bandaId --> ID de la banda
  /// - ubicacionId --> ID de la ubicación
  ///
  /// Devuelve:
  /// - String con el nombre o 'No definido' si no existe
  /// ********************************************************************
  static Future<String> obtenerNombreUbicacion(String bandaId, String ubicacionId) async {
    if (ubicacionId.isEmpty) return 'No definido';

    final doc = await firestore.collection('bandas').doc(bandaId).collection('ubicaciones').doc(ubicacionId).get();

    if (!doc.exists) return 'No definido';

    final data = doc.data() as Map<String, dynamic>;
    return data['nombre'] ?? 'No definido';
  }

  /// ********************************************************************
  /// OBTENER UBICACIÓN COMPLETA
  ///
  /// Recupera toda la información de una ubicación por su ID.
  ///
  /// Parámetros:
  /// - bandaId --> ID de la banda
  /// - ubicacionId --> ID de la ubicación
  ///
  /// Devuelve:
  /// - Objeto Ubicacion? (null si no existe)
  /// ********************************************************************
  static Future<Ubicacion?> obtenerUbicacion(String bandaId, String ubicacionId) async {
    final doc = await firestore.collection('bandas').doc(bandaId).collection('ubicaciones').doc(ubicacionId).get();

    if (!doc.exists) return null;

    return Ubicacion.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  /// ********************************************************************
  /// COMPROBAR SI SE PUEDE ELIMINAR UBICACIÓN
  ///
  /// Verifica si la ubicación está siendo usada en algún evento.
  ///
  /// Parámetros:
  /// - bandaId --> ID de la banda
  /// - ubicacionId --> ID de la ubicación a verificar
  ///
  /// Devuelve:
  /// - bool (true si se puede eliminar)
  /// ********************************************************************
  static Future<bool> ubicacionSePuedeEliminar({required String bandaId, required String ubicacionId}) async {
    try {
      // Traemos todos los eventos de la banda
      final eventosSnapshot = await firestore.collection('bandas').doc(bandaId).collection('eventos').get();

      for (var eventoDoc in eventosSnapshot.docs) {
        final data = eventoDoc.data();

        // Comprobamos ambos campos
        final ubicacionCita = data['ubicacionCitaId'] as String?;
        final ubicacionEvento = data['ubicacionEventoId'] as String?;

        if (ubicacionCita == ubicacionId || ubicacionEvento == ubicacionId) {
          // La ubicación está en uso → no se puede eliminar
          return false;
        }
      }

      // Ningún evento usa esta ubicación
      return true;
    } catch (e) {
      debugPrint('Error comprobando si se puede eliminar ubicación: $e');
      // Por seguridad, no permitir eliminar si hay error
      return false;
    }
  }

  /// ********************************************************************
  /// ELIMINAR UBICACIÓN
  ///
  /// Borra un documento de ubicación de Firestore.
  ///
  /// Parámetros:
  /// - bandaId --> ID de la banda
  /// - ubicacionId --> ID de la ubicación a eliminar
  /// ********************************************************************
  static Future<void> eliminarUbicacion(String bandaId, String ubicacionId) async {
    await firestore.collection('bandas').doc(bandaId).collection('ubicaciones').doc(ubicacionId).delete();
  }
}
