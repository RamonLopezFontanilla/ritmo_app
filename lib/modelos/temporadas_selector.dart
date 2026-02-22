import 'package:flutter/material.dart';
import 'package:ritmo_app/modelos/temporada.dart';

class SelectorTemporada extends StatelessWidget {
  final List<Temporada> temporadas;
  final String temporadaSeleccionadaId;
  final ValueChanged<String?> onChanged;

  // Constructor
  const SelectorTemporada({
    super.key,
    required this.temporadas,
    required this.temporadaSeleccionadaId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text("Temporada:", style: TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: temporadaSeleccionadaId.isEmpty ? null : temporadaSeleccionadaId,
          hint: const Text("Sin temporada"),
          underline: const SizedBox(),
          items: temporadas.map((t) {
            final esActual = t.id == temporadaSeleccionadaId;
            return DropdownMenuItem<String>(
              value: t.id,
              child: Text(
                t.nombre,
                style: TextStyle(
                  fontWeight: esActual ? FontWeight.bold : FontWeight.normal,
                  color: esActual ? Colors.green[700] : Colors.black87,
                  fontSize: 14,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
