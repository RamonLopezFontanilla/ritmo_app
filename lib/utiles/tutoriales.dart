import 'package:flutter/material.dart';

class TutorialUtils {
  /// Obtiene dimensiones y posición del widget en pantalla
  static Rect dimensionesPantalla(GlobalKey key) {
    final RenderBox box = key.currentContext!.findRenderObject() as RenderBox;
    final position = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(position.dx, position.dy, box.size.width, box.size.height);
  }

  /// Calcula padding dinámico para que el tooltip no se salga de pantalla
  static double obtenerDesplazamientoObjeto(
    BuildContext context,
    GlobalKey key, {
    double margin = 12,
    double alturaCuadroTutorial = 90,
  }) {
    final dimensionesObjeto = dimensionesPantalla(key);
    final alturaPantalla = MediaQuery.of(context).size.height;
    final posicionInferiorObjeto = dimensionesObjeto.bottom;

    double padding = dimensionesObjeto.height + margin;

    if (posicionInferiorObjeto + padding + alturaCuadroTutorial > alturaPantalla) {
      padding = alturaPantalla - posicionInferiorObjeto - alturaCuadroTutorial - 10;
      if (padding < 0) padding = 0;
    }

    return padding;
  }
}
