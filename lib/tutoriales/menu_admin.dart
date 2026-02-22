import 'package:flutter/material.dart';
import 'package:ritmo_app/modelos/tutorial.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class TutorialMenuAdministrador {
  final BuildContext context;

  final GlobalKey keyMenu;
  final GlobalKey keyTemporada;
  final GlobalKey keyNovedades;
  final GlobalKey keyPlantilla;
  final GlobalKey keyEventos;
  final GlobalKey keyLiquidacion;
  final GlobalKey keyInstrumentos;
  final GlobalKey keyPartituras;
  final GlobalKey keyUbicaciones;

  TutorialMenuAdministrador({
    required this.context,
    required this.keyMenu,
    required this.keyTemporada,
    required this.keyNovedades,
    required this.keyPlantilla,
    required this.keyEventos,
    required this.keyLiquidacion,
    required this.keyInstrumentos,
    required this.keyPartituras,
    required this.keyUbicaciones,
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
      target(keyMenu, "Usa este menú para configurar la Banda...", align: ContentAlign.bottom),
      target(keyTemporada, "Selecciona aquí la temporada activa...", align: ContentAlign.bottom),
      target(keyNovedades, "Publica mensajes importantes para los músicos...", align: ContentAlign.bottom),
      target(keyPlantilla, "Usa este menú para gestionar la plantilla...", align: ContentAlign.bottom),
      target(keyEventos, "Usa este menú para gestionar los eventos de la temporada...", align: ContentAlign.bottom),
      target(keyLiquidacion, "Usa este menú para calcular la liquidación de la temporada...", align: ContentAlign.top),
      target(
        keyInstrumentos,
        "Usa este menú para gestionar los instrumentos y categorías disponibles...",
        align: ContentAlign.top,
      ),
      target(
        keyPartituras,
        "Usa este menú para gestionar el banco de partituras disponibles...",
        align: ContentAlign.top,
      ),
      target(keyUbicaciones, "Usa este menú para gestionar las ubicaciones de los eventos...", align: ContentAlign.top),
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
