import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ritmo_app/modelos/evento.dart';
import 'package:ritmo_app/modelos/evento_a_fichar.dart';

/// ********************************************************
/// Clase estática responsable de todas las operaciones
/// relacionadas con:
///
/// - Gestión de eventos
/// - Consulta por temporada
/// - Control de fichajes
/// - Validación por distancia
/// - Eliminación en cascada
///
/// Toda la información se almacena en la subcolección
/// "eventos" dentro del documento de cada banda.
/// ********************************************************
class ConsultasEventosBD {
  static final firestore = FirebaseFirestore.instance;

  /// ******************************************************************
  /// OBTENER EVENTOS DE UNA TEMPORADA
  ///
  /// Consulta todos los eventos pertenecientes a una temporada
  /// concreta dentro de una banda.
  ///
  /// Características:
  /// - Filtra por campo "temporada"
  /// - Ordena por fecha de inicio
  /// - Convierte correctamente Timestamp → DateTime
  ///
  /// Devuelve:
  /// - Lista de objetos [Evento]
  /// ******************************************************************
  static Future<List<Evento>> obtenerEventosDeTemporada(String bandaId, String temporadaId) async {
    final snap = await firestore
        .collection('bandas')
        .doc(bandaId)
        .collection('eventos')
        .where('temporada', isEqualTo: temporadaId)
        .orderBy('inicio')
        .get();

    return snap.docs.map((doc) {
      final data = doc.data(); // Map<String, dynamic>

      // Convertir Timestamp de Firebase a DateTime
      DateTime parseFecha(dynamic value, [String? fallback]) {
        if (value is Timestamp) return value.toDate(); // Firebase → DateTime
        if (value is DateTime) return value;
        if (value is String && value.isNotEmpty) {
          final parsed = DateTime.tryParse(value);
          if (parsed != null) return parsed;
        }
        if (fallback != null) {
          final parsed = DateTime.tryParse(fallback);
          if (parsed != null) return parsed;
        }
        return DateTime.now();
      }

      final inicio = parseFecha(data['inicio'], data['horaInicioTexto']);
      final fin = parseFecha(data['fin'], data['horaFinTexto']);

      return Evento(
        id: doc.id,
        tipo: data['tipo'] ?? '',
        descripcion: data['descripcion'] ?? '',
        ubicacionEventoId: data['ubicacionEventoId'] ?? '',
        ubicacionCitaId: data['ubicacionCitaId'] ?? '',
        inicio: inicio,
        fin: fin,
        horaInicioTexto: data['horaInicioTexto'] ?? '',
        horaFinTexto: data['horaFinTexto'] ?? '',
        temporada: data['temporada'] ?? '',
      );
    }).toList();
  }

  /// ******************************************************************
  /// OBTENER EVENTO POR ID
  ///
  /// Recupera un único evento a partir de su identificador.
  ///
  /// Devuelve:
  /// - Objeto [Evento] si existe
  /// - null si el documento no existe
  /// ******************************************************************
  static Future<Evento?> obtenerEventoPorId(String bandaId, String eventoId) async {
    final doc = await firestore.collection('bandas').doc(bandaId).collection('eventos').doc(eventoId).get();

    if (!doc.exists) return null;

    final data = doc.data();
    if (data == null) return null;

    return Evento.fromMap(doc.id, data);
  }

  /// ******************************************************************
  /// OBTENER EVENTO PARA FICHAR
  ///
  /// Determina qué evento debe mostrarse para fichaje
  /// según el momento actual.
  ///
  /// Prioridad:
  /// 1. Evento activo (ya iniciado y no finalizado)
  /// 2. Próximo evento futuro
  /// 3. Último evento finalizado
  ///
  /// También obtiene el nombre de la ubicación asociada.
  ///
  /// Devuelve:
  /// - Objeto [EventoAFichar]
  /// - null si no existen eventos
  /// ******************************************************************
  static Future<EventoAFichar?> obtenerEventoAFichar(String bandaId, String temporada) async {
    final eventosSnap = await firestore
        .collection('bandas')
        .doc(bandaId)
        .collection('eventos')
        .where('temporada', isEqualTo: temporada)
        .orderBy('inicio')
        .get();

    final ahora = DateTime.now();

    Map<String, dynamic>? activo;
    Map<String, dynamic>? proximo;
    Map<String, dynamic>? ultimoFinalizado;

    for (final doc in eventosSnap.docs) {
      final data = doc.data();
      data['id'] = doc.id;

      final inicio = (data['inicio'] as Timestamp).toDate();
      final fin = (data['fin'] != null ? (data['fin'] as Timestamp).toDate() : null);

      if (inicio.isBefore(ahora) && (fin == null || fin.isAfter(ahora))) {
        activo = data;
        break;
      }

      if (inicio.isAfter(ahora) && proximo == null) {
        proximo = data;
      }

      if (fin != null && fin.isBefore(ahora)) {
        ultimoFinalizado = data;
      }
    }

    final eventoData = activo ?? proximo ?? ultimoFinalizado;

    if (eventoData == null) return null;

    // Obtener nombre de la ubicación si existe
    String? nombreUbicacion;
    final ubicacionId = eventoData['ubicacionEventoId'];
    if (ubicacionId != null) {
      final ubicacionDoc = await firestore
          .collection('bandas')
          .doc(bandaId)
          .collection('ubicaciones')
          .doc(ubicacionId)
          .get();

      if (ubicacionDoc.exists) {
        nombreUbicacion = ubicacionDoc.data()?['nombre'];
      }
    }

    return EventoAFichar(
      id: eventoData['id'],
      descripcion: eventoData['descripcion'] ?? '',
      inicio: (eventoData['inicio'] as Timestamp).toDate(),
      fin: eventoData['fin'] != null ? (eventoData['fin'] as Timestamp).toDate() : null,
      ubicacionNombre: nombreUbicacion,
    );
  }

  /// ******************************************************************
  /// COMPROBAR SI UN MÚSICO YA HA FICHADO
  ///
  /// Consulta la colección "asistencias" filtrando por:
  /// - eventoId
  /// - musicoId
  ///
  /// Devuelve:
  /// - true si existe registro
  /// - false en caso contrario
  /// ******************************************************************
  static Future<bool> yaFichado(String bandaId, String musicoId, String eventoId) async {
    final doc = await firestore
        .collection('bandas')
        .doc(bandaId)
        .collection('asistencias')
        .where('eventoId', isEqualTo: eventoId)
        .where('musicoId', isEqualTo: musicoId)
        .get();

    return doc.docs.isNotEmpty;
  }

  /// ******************************************************************
  /// VALIDAR FICHAJE POR DISTANCIA
  ///
  /// Comprueba si el usuario se encuentra dentro del radio permitido definido en los parámetros de la banda.
  ///
  /// Proceso:
  /// 1. Obtiene la ubicación del evento.
  /// 2. Obtiene la distancia máxima permitida.
  /// 3. Obtiene la posición actual del dispositivo.
  /// 4. Calcula distancia real usando Geolocator.
  ///
  /// Devuelve:
  /// - true si está dentro del rango permitido.
  /// ******************************************************************
  static Future<bool> puedeFicharPorDistancia({required String bandaId, required String eventoId}) async {
    // Obtener evento
    final eventoDoc = await firestore.collection('bandas').doc(bandaId).collection('eventos').doc(eventoId).get();

    if (!eventoDoc.exists) {
      throw Exception("Evento no encontrado");
    }

    final dataEvento = eventoDoc.data()!;
    final ubicacionId = dataEvento['ubicacionEventoId'];

    if (ubicacionId == null) {
      throw Exception("El evento no tiene ubicación asignada");
    }

    // Obtener ubicación
    final ubicacionDoc = await firestore
        .collection('bandas')
        .doc(bandaId)
        .collection('ubicaciones')
        .doc(ubicacionId)
        .get();

    if (!ubicacionDoc.exists) {
      throw Exception("Ubicación del evento no encontrada");
    }

    final double latEvento = (ubicacionDoc['latitud'] as num).toDouble();
    final double lonEvento = (ubicacionDoc['longitud'] as num).toDouble();

    // Obtener parámetros banda
    final bandaDoc = await firestore.collection('bandas').doc(bandaId).get();

    final int distanciaPermitida = (bandaDoc['parametros']?['distancia'] as num?)?.toInt() ?? 0;

    // Obtener posición actual
    final posicion = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

    final distanciaReal = Geolocator.distanceBetween(posicion.latitude, posicion.longitude, latEvento, lonEvento);

    return distanciaReal <= distanciaPermitida;
  }

  /// ******************************************************************
  /// GUARDAR O ACTUALIZAR EVENTO
  ///
  /// Si el evento tiene ID:
  /// - Se actualiza el documento existente.
  ///
  /// Si no tiene ID:
  /// - Se crea un nuevo documento.
  /// ******************************************************************
  static Future<void> guardarEvento(Evento evento, {required String bandaId}) async {
    final ref = firestore.collection('bandas').doc(bandaId).collection('eventos');

    final data = {
      'tipo': evento.tipo,
      'descripcion': evento.descripcion,
      'temporada': evento.temporada,
      'inicio': evento.inicio,
      'fin': evento.fin,
      'horaInicioTexto': evento.horaInicioTexto,
      'horaFinTexto': evento.horaFinTexto,
      'ubicacionEventoId': evento.ubicacionEventoId,
      'ubicacionCitaId': evento.ubicacionCitaId,
    };

    if (evento.id.isNotEmpty) {
      // Actualizar evento existente
      await ref.doc(evento.id).update(data);
    } else {
      // Crear nuevo evento
      await ref.add(data);
    }
  }

  /// ******************************************************************
  /// ELIMINAR EVENTO Y SUS ASISTENCIAS
  ///
  /// Proceso:
  /// 1. Obtiene todas las asistencias asociadas al evento.
  /// 2. Elimina asistencias mediante WriteBatch.
  /// 3. Elimina el evento.
  ///
  /// Se ejecuta en una única operación batch para
  /// mantener consistencia.
  /// ******************************************************************
  static Future<void> eliminarEventoYAsistencias({required String bandaId, required String eventoId}) async {
    try {
      final batch = firestore.batch();

      // Referencia al evento
      final eventoRef = firestore.collection('bandas').doc(bandaId).collection('eventos').doc(eventoId);

      // Obtener todas las asistencias asociadas a este evento
      final asistenciasSnap = await firestore
          .collection('bandas')
          .doc(bandaId)
          .collection('asistencias')
          .where('eventoId', isEqualTo: eventoId)
          .get();

      // Agregar la eliminación de cada asistencia al batch
      for (var docA in asistenciasSnap.docs) {
        batch.delete(docA.reference);
      }

      // Agregar la eliminación del evento al batch
      batch.delete(eventoRef);

      // Ejecutar batch
      await batch.commit();
    } catch (e) {
      throw Exception("Error eliminando evento y asistencias: $e");
    }
  }
}
