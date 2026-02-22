import 'package:flutter/material.dart';
import 'package:ritmo_app/modelos/tutorial.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class TutorialMenuMusico {
  final BuildContext context;

  final GlobalKey keyMenu;
  final GlobalKey keyTemporada;
  final GlobalKey keyNovedades;
  final GlobalKey keyBotonFichaje;
  final GlobalKey keyEventos;
  final GlobalKey keyAsistencias;
  final GlobalKey keyPartituras;
  final GlobalKey keyLiquidacion;

  TutorialMenuMusico({
    required this.context,

    required this.keyMenu,
    required this.keyTemporada,
    required this.keyNovedades,
    required this.keyEventos,
    required this.keyAsistencias,
    required this.keyLiquidacion,
    required this.keyBotonFichaje,
    required this.keyPartituras,
  });

  void mostrar() {
    TutorialCoachMark(
      targets: buildTargets(),
      textSkip: "Saltar",
      colorShadow: Colors.black,
      paddingFocus: 10,
      opacityShadow: 0.8,
    ).show(context: context);
  }

  List<TargetFocus> buildTargets() {
    return [
      target(keyMenu, "Usa este menú para completar tus datos...", align: ContentAlign.bottom),
      target(keyTemporada, "Selecciona aquí la temporada activa...", align: ContentAlign.bottom),
      target(keyNovedades, "Aquí verás mensajes importantes...", align: ContentAlign.bottom),
      target(
        keyBotonFichaje,
        "Cuando un evento esté activo se pondrá de color verde y podrás fichar si estás dentro de la distancia permitida a la ubicación del evento...",
        align: ContentAlign.top,
      ),
      target(
        keyEventos,
        "Usa este menú para consultar los eventos de la temporada y comunicar asistencias/ausencias previstas...",
        align: ContentAlign.top,
      ),
      target(
        keyAsistencias,
        "Usa este menú para consultar tus asistencias y ausencias en la temporada...",
        align: ContentAlign.top,
      ),
      target(
        keyPartituras,
        "Usa este menú para consultar las partituras disponibles para tus instrumentos...",
        align: ContentAlign.top,
      ),
      target(keyLiquidacion, "Usa este menú para consultar la liquidación de la temporada...", align: ContentAlign.top),
    ];
  }

  TargetFocus target(GlobalKey key, String texto, {required ContentAlign align}) {
    return TargetFocus(
      keyTarget: key,
      contents: [
        TargetContent(
          align: align,
          child: Padding(
            padding: EdgeInsets.only(
              top: align == ContentAlign.bottom ? UtilesTutorial.obtenerDesplazamientoObjeto(context, key) : 0,
              bottom: align == ContentAlign.top ? UtilesTutorial.obtenerDesplazamientoObjeto(context, key) : 0,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color.fromARGB(221, 255, 238, 82),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                texto,
                style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
