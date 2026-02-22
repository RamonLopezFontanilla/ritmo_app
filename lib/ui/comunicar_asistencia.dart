import 'package:flutter/material.dart';
import 'package:ritmo_app/consultas_bd/asistencias.dart';
import 'package:ritmo_app/modelos/prevision_asistencia.dart';
import 'package:ritmo_app/utiles/widgets.dart';

/// ****************************************************************
/// Página para comunicar previsión de asistencia a un evento.
///
/// Permite:
/// - Indicar si el usuario asistirá o no al evento.
/// - Seleccionar un motivo en caso de no asistencia.
/// - Especificar un detalle adicional si el motivo es "Otros".
/// - Guardar la previsión en base de datos.
///
/// Es un [StatefulWidget] porque:
/// - Mantiene estado de selección (sí/no).
/// - Gestiona selección dinámica de motivos.
/// - Controla un TextEditingController.
/// - Gestiona estado de carga durante el guardado.
/// ****************************************************************
class PaginaPrevisionAsistencia extends StatefulWidget {
  final String bandaId;
  final String eventoId;
  final String uid;

  const PaginaPrevisionAsistencia({super.key, required this.bandaId, required this.eventoId, required this.uid});

  @override
  State<PaginaPrevisionAsistencia> createState() => EstadoPaginaPrevisionAsistencia();
}

/// ****************************************************************
/// Estado de la página de previsión de asistencia.
///
/// Responsabilidades:
/// - Gestionar selección de asistencia.
/// - Gestionar selección de motivo.
/// - Validar datos antes de guardar.
/// - Construir objeto [PrevisionAsistencia].
/// - Persistir la previsión en base de datos.
/// - Controlar estado visual de guardado.
/// ****************************************************************
class EstadoPaginaPrevisionAsistencia extends State<PaginaPrevisionAsistencia> {
  bool? asistira;
  String? motivoSeleccionado;

  final List<String> motivos = ["Estudio", "Trabajo", "Viaje", "Enfermedad", "Otros"];
  final TextEditingController controladorOtros = TextEditingController();
  bool guardando = false;

  /// ***********************************************
  /// Liberación de recursos
  /// - Libera el controlador de texto.
  /// - Evita fugas de memoria.
  /// ***********************************************
  @override
  void dispose() {
    controladorOtros.dispose();
    super.dispose();
  }

  /// ***********************************************
  /// Guardar previsión de asistencia
  ///
  /// Validaciones:
  /// - Debe indicarse si asistirá o no.
  /// - Si no asiste → debe seleccionar un motivo.
  /// - Si el motivo es "Otros" → debe especificar detalle.
  ///
  /// Flujo:
  /// - Construye objeto [PrevisionAsistencia].
  /// - Llama a base de datos.
  /// - Cierra pantalla si éxito.
  /// ***********************************************
  Future<void> guardarPrevision() async {
    if (asistira == null) return;
    if (asistira == false && motivoSeleccionado == null) return;

    if (motivoSeleccionado == "Otros" && controladorOtros.text.trim().isEmpty) {
      return;
    }

    setState(() => guardando = true);

    try {
      final prevision = PrevisionAsistencia(
        uid: widget.uid,
        asistira: asistira!,
        motivo: asistira == false ? motivoSeleccionado : null,
        otrosDetalle: motivoSeleccionado == "Otros" ? controladorOtros.text.trim() : null,
      );

      await ConsultasAsistenciasBD.guardarPrevision(
        bandaId: widget.bandaId,
        eventoId: widget.eventoId,
        prevision: prevision,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        context.mostrarSnack("Error al guardar la previsión", esCorrecto: false);
      }
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  /// ***********************************************
  ///              --- Construcción UI ---
  ///
  /// Estructura:
  /// - AppBar fija
  /// - Pregunta principal (sí / no)
  /// - Motivos dinámicos si no asiste
  /// - Campo adicional si motivo es "Otros"
  /// - Botón guardar inferior
  /// ***********************************************
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ----------------------------
      //         BARRA SUPERIOR
      // ----------------------------
      appBar: AppBar(title: const Text("Previsión de asistencia")),

      // ----------------------------
      //       CUERPO PRINCIPAL
      // ----------------------------
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("¿Vas a asistir al evento?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // RADIO PRINCIPAL
              RadioGroup<bool>(
                groupValue: asistira,
                onChanged: (value) {
                  setState(() {
                    asistira = value;
                    motivoSeleccionado = null;
                    controladorOtros.clear();
                  });
                },
                child: Column(
                  children: [
                    RadioListTile(title: const Text("Sí, asistiré"), value: true),
                    RadioListTile(title: const Text("No podré asistir"), value: false),
                  ],
                ),
              ),

              // MOTIVOS SOLO SI NO ASISTE
              if (asistira == false) ...[
                const SizedBox(height: 12),
                const Text("Motivo:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                RadioGroup<String>(
                  groupValue: motivoSeleccionado,
                  onChanged: (value) {
                    setState(() {
                      motivoSeleccionado = value;
                      if (value != "Otros") {
                        controladorOtros.clear();
                      }
                    });
                  },
                  child: Column(
                    children: motivos.map((motivo) {
                      return RadioListTile<String>(title: Text(motivo), value: motivo);
                    }).toList(),
                  ),
                ),

                if (motivoSeleccionado == "Otros") ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: controladorOtros,
                    decoration: const InputDecoration(labelText: "Especifica el motivo", border: OutlineInputBorder()),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),

      // ----------------------------
      //       BOTÓN GUARDAR
      // ----------------------------
      bottomNavigationBar: BotonGuardar(onPressed: guardarPrevision, enabled: true),
    );
  }
}
