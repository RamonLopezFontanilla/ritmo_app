import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ritmo_app/consultas_bd/musicos.dart';
import 'package:ritmo_app/modelos/musico_liquidacion.dart';
import 'package:ritmo_app/modelos/parametros_liquidacion.dart';

/// ********************************************************
/// Clase estática responsable de:
///
/// - Gestión de parámetros de liquidación
/// - Gestión de músicos incluidos en liquidación
/// - Sincronización con músicos activos
/// - Recalculo automático de importes
///
/// Estructura en Firestore:
/// bandas/{bandaId}/temporadas/{temporadaId}/liquidacion/
///
/// - datos
/// - usuarios/usuarios/{musicoId}
/// ********************************************************
class ConsultasLiquidacionesBD {
  static final FirebaseFirestore firestore = FirebaseFirestore.instance;

  /// ************************************************************
  /// OBTENER PARÁMETROS DE LIQUIDACIÓN
  ///
  /// Devuelve objeto [ParametrosLiquidacion].
  /// Si no existe documento, devuelve objeto vacío.
  /// ************************************************************
  static Future<ParametrosLiquidacion> obtenerParametros(String bandaId, String temporadaId) async {
    final doc = await firestore
        .collection('bandas')
        .doc(bandaId)
        .collection('temporadas')
        .doc(temporadaId)
        .collection('liquidacion')
        .doc('datos')
        .get();

    return ParametrosLiquidacion.fromMap(doc.data() ?? {});
  }

  /// ************************************************************
  /// REFERENCIA A COLECCIÓN DE MÚSICOS EN LIQUIDACIÓN
  ///
  /// Usa withConverter para trabajar directamente con objetos [LiquidacionMusico].
  /// ************************************************************
  static CollectionReference<LiquidacionMusico> musicosIncluidosLiquidacion(String bandaId, String temporadaId) {
    return firestore
        .collection('bandas')
        .doc(bandaId)
        .collection('temporadas')
        .doc(temporadaId)
        .collection('liquidacion')
        .doc('usuarios')
        .collection('usuarios')
        .withConverter<LiquidacionMusico>(
          fromFirestore: (snapshot, _) => LiquidacionMusico.fromMap(snapshot.id, snapshot.data() ?? {}),
          toFirestore: (musico, _) => musico.toMap(),
        );
  }

  /// ************************************************************
  /// STREAM DE MÚSICOS EN LIQUIDACIÓN
  /// ************************************************************
  static Stream<List<LiquidacionMusico>> streamMusicosLiquidacion(String bandaId, String temporadaId) {
    return musicosIncluidosLiquidacion(
      bandaId,
      temporadaId,
    ).snapshots().map((snap) => snap.docs.map((doc) => doc.data()).toList());
  }

  /// ************************************************************
  /// OBTENER LIQUIDACIÓN DE UN MÚSICO
  /// ************************************************************
  static Future<LiquidacionMusico> obtenerLiquidacionMusico(String bandaId, String temporadaId, String musicoId) async {
    final doc = await musicosIncluidosLiquidacion(bandaId, temporadaId).doc(musicoId).get();

    return doc.data()!;
  }

  /// ************************************************************
  /// SINCRONIZAR MÚSICOS ACTIVOS
  ///
  /// - Agrega músicos activos que falten
  /// - Elimina músicos que ya no estén activos
  ///
  /// Mantiene la liquidación coherente con el estado actual de la banda.
  /// ************************************************************
  static Future<void> sincronizarUsuariosActivos(String bandaId, String temporadaId) async {
    // Obtener todos los músicos activos de la banda
    final activos = await ConsultasMusicosBD.obtenerMusicosActivos(bandaId);
    // activos: lista de DocumentSnapshot con 'uid', 'activo' y 'rol'

    final musicosLiq = firestore
        .collection('bandas')
        .doc(bandaId)
        .collection('temporadas')
        .doc(temporadaId)
        .collection('liquidacion')
        .doc('usuarios')
        .collection('usuarios');

    // Obtener todos los músicos actualmente en liquidación
    final snap = await musicosLiq.get();
    final existentes = snap.docs.map((d) => d.id).toSet();

    // Crear sets de uid de activos e inactivos
    final activosUid = activos.map((d) => d.id).toSet(); // solo músicos activos
    final inactivosUid = existentes.difference(activosUid); // los que están pero ya no activos

    final batch = firestore.batch();

    // Agregar los músicos activos que faltan
    for (final doc in activos) {
      if (!existentes.contains(doc.id)) {
        batch.set(musicosLiq.doc(doc.id), {
          'incluidoEnLiquidacion': true,
          'puntosAntiguedad': 0,
          'numEnsayosPuntual': 0,
          'numEnsayosRetraso': 0,
          'numActuacionPuntual': 0,
          'numActuacionRetraso': 0,
          'numSemanaStaPuntual': 0,
          'numSemanaStaRetraso': 0,
          'puntosTotales': 0,
          'importeFinal': 0,
          'activo': true, // opcional: guardar el estado activo
        }, SetOptions(merge: true));
      }
    }

    // Eliminar músicos que ya no están activos
    for (final uid in inactivosUid) {
      batch.delete(musicosLiq.doc(uid));
    }

    await batch.commit();
  }

  /// ************************************************************
  /// RECALCULAR LIQUIDACIÓN COMPLETA
  ///
  /// - Calcula puntos totales
  /// - Calcula valor por punto
  /// - Actualiza importe final por músico
  /// - Guarda datos agregados en "datos"
  /// ************************************************************
  static Future<void> recalcularLiquidacion(String bandaId, String temporadaId) async {
    final collection = musicosIncluidosLiquidacion(bandaId, temporadaId);
    final snap = await collection.get();

    if (snap.docs.isEmpty) return;

    final parametros = await obtenerParametros(bandaId, temporadaId);
    final double cantidadRepartir = parametros.cantidadRepartir.toDouble();

    int totalPuntos = 0;
    final Map<String, int> puntosPorMusico = {};

    // Calcular puntos y acumular total
    for (final doc in snap.docs) {
      final musico = doc.data();

      if (!musico.incluidoEnLiquidacion) {
        puntosPorMusico[doc.id] = 0;
        continue;
      }

      final puntos = calcularPuntosMusico(musico, parametros);
      puntosPorMusico[doc.id] = puntos;
      totalPuntos += puntos;
    }
    final double valorPunto;
    if (totalPuntos == 0) {
      valorPunto = 0;
    } else {
      valorPunto = cantidadRepartir / totalPuntos;
    }

    final batch = firestore.batch();

    // Aplicar importes
    for (final doc in snap.docs) {
      final musico = doc.data();
      final puntos = puntosPorMusico[doc.id] ?? 0;

      if (!musico.incluidoEnLiquidacion) {
        batch.update(doc.reference, {'puntosTotales': 0, 'importeFinal': 0});
        continue;
      }

      final double importe = double.parse((puntos * valorPunto).toStringAsFixed(2));

      batch.update(doc.reference, {'puntosTotales': puntos, 'importeFinal': importe});
    }

    // Actualizar datos generales
    final datosRef = firestore
        .collection('bandas')
        .doc(bandaId)
        .collection('temporadas')
        .doc(temporadaId)
        .collection('liquidacion')
        .doc('datos');

    batch.set(datosRef, {'totalPuntosLiquidacion': totalPuntos, 'valorPunto': valorPunto}, SetOptions(merge: true));

    await batch.commit();
  }

  /// ************************************************************
  /// CALCULAR PUNTOS DE UN MÚSICO
  ///
  /// Fórmula:
  /// cantidad × (base + (multiplicador × antigüedad))
  /// ************************************************************
  static int calcularPuntosMusico(LiquidacionMusico u, ParametrosLiquidacion p) {
    int total = 0;
    void suma(int cantidad, int base, int mult) {
      total += cantidad * (base + (mult * u.puntosAntiguedad));
    }

    suma(u.numEnsayosPuntual, p.puntosEnsayoPuntual, p.puntosAntigEP);
    suma(u.numEnsayosRetraso, p.puntosEnsayoRetraso, p.puntosAntigER);
    suma(u.numActuacionPuntual, p.puntosActuacionPuntual, p.puntosAntigAP);
    suma(u.numActuacionRetraso, p.puntosActuacionRetrasada, p.puntosAntigAR);
    suma(u.numSemanaStaPuntual, p.puntosSSPuntual, p.puntosAntigSSP);
    suma(u.numSemanaStaRetraso, p.puntosSSRetraso, p.puntosAntigSSR);

    return total;
  }

  /// ************************************************************
  /// GUARDAR PARÁMETROS DE LIQUIDACIÓN
  ///
  /// Añade fechaActualizacion automática.
  /// ************************************************************
  static Future<void> guardarParametros(String bandaId, String temporadaId, ParametrosLiquidacion parametros) async {
    await firestore
        .collection("bandas")
        .doc(bandaId)
        .collection("temporadas")
        .doc(temporadaId)
        .collection("liquidacion")
        .doc("datos")
        .set({...parametros.toMap(), "fechaActualizacion": FieldValue.serverTimestamp()});
  }
}
