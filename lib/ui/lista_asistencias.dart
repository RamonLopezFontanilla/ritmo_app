import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:ritmo_app/consultas_bd/asistencias.dart';
import 'package:ritmo_app/consultas_bd/eventos.dart';
import 'package:ritmo_app/consultas_bd/parametros_banda.dart';
import 'package:ritmo_app/consultas_bd/temporada.dart';
import 'package:ritmo_app/consultas_bd/ubicaciones.dart';
import 'package:ritmo_app/consultas_bd/usuarios.dart';
import 'package:ritmo_app/modelos/evento.dart';
import 'package:ritmo_app/utiles/widgets.dart';

/// ********************************************************
/// Página de lista de asistencias de un músico.
///
/// Permite:
/// - Consultar todas las asistencias de un músico en una temporada específica.
/// - Filtrar por tipo de evento (Ensayo, Actuación, Semana Santa).
/// - Filtrar por estado de asistencia (Puntual, Retraso, Ausencia).
/// - Generar un PDF con el resumen de asistencias.
///
/// Es un [StatefulWidget] porque mantiene estado:
/// - Lista de eventos y asistencias cargadas
/// - Filtros seleccionados por el usuario
/// - Estado de carga para mostrar indicadores
/// ********************************************************
class PaginaAsistencias extends StatefulWidget {
  final String bandaId;
  final String musicoId;
  final String temporadaSeleccionadaId;
  final String nombreMusico;
  final String nombreBanda;

  const PaginaAsistencias({
    super.key,
    required this.bandaId,
    required this.musicoId,
    required this.temporadaSeleccionadaId,
    required this.nombreMusico,
    required this.nombreBanda,
  });

  @override
  State<PaginaAsistencias> createState() => EstadoPaginaAsistencias();
}

/// ********************************************************
/// Estado de la página de asistencias.
///
/// Contiene toda la lógica:
/// - Carga de eventos y asistencias desde Firebase
/// - Determinación del estado de asistencia (Puntual, Retraso, Ausencia)
/// - Gestión de filtros
/// - Generación de PDF con el resumen de asistencias
/// - Construcción de la interfaz con lista y filtros
/// ********************************************************
class EstadoPaginaAsistencias extends State<PaginaAsistencias> {
  List<Evento> eventos = [];
  Map<String, DateTime> asistenciasMusico = {};
  bool cargando = true;

  // Filtros
  String tipoEventoFiltro = "Todos";
  String estadoFiltro = "Todos";
  String? nombreTemporada = "";
  String? nombreMusico = "";

  int umbralRetrasoMin = 30;

  final List<String> tiposEvento = ["Todos", "Ensayo", "Actuación", "Semana Santa"];
  final List<String> estadosAsistencia = ["Todos", "Puntual", "Retraso", "Ausencia"];

  /// ********************************************************
  /// Inicialización del estado
  ///
  /// - Carga los datos de la temporada y asistencias del músico.
  /// ********************************************************
  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  /// ********************************************************
  /// Carga eventos y asistencias desde la base de datos.
  ///
  /// Pasos:
  /// 1. Obtener el umbral de retraso configurado para la banda
  /// 2. Obtener el nombre de la temporada y del músico
  /// 3. Obtener todos los eventos de la temporada
  /// 4. Obtener el nombre de la ubicación para cada evento
  /// 5. Obtener todas las asistencias del músico
  /// 6. Actualizar el estado de la UI
  /// ********************************************************
  Future<void> cargarDatos() async {
    setState(() => cargando = true);

    umbralRetrasoMin = await ConsultasParametrosBD.obtenerUmbralRetraso(widget.bandaId);

    nombreTemporada = await ConsultasTemporadasBD.obtenerNombreTemporada(
      widget.bandaId,
      widget.temporadaSeleccionadaId,
    );

    nombreMusico = await ConsultasUsuariosBD.obtenerNombreMusico(widget.musicoId);
    eventos = await ConsultasEventosBD.obtenerEventosDeTemporada(widget.bandaId, widget.temporadaSeleccionadaId);

    for (var evento in eventos) {
      evento.nombreUbicacionEvento = await ConsultasUbicacionesBD.obtenerNombreUbicacion(
        widget.bandaId,
        evento.ubicacionEventoId,
      );
    }

    final asistencias = await ConsultasAsistenciasBD.obtenerAsistenciasMusico(widget.bandaId, widget.musicoId);

    asistenciasMusico = {for (var a in asistencias) a.eventoId: a.momentoFichaje};

    setState(() => cargando = false);
  }

  /// ********************************************************
  /// Determina el estado de asistencia de un evento
  ///
  /// Reglas:
  /// - Si no hay registro de asistencia: "Ausencia"
  /// - Si llegó antes del umbral de retraso: "Puntual"
  /// - Si llegó después del umbral: "Retraso"
  /// ********************************************************
  String estadoAsistencia(Evento evento) {
    if (!asistenciasMusico.containsKey(evento.id)) return "Ausencia";

    final fichaje = asistenciasMusico[evento.id]!;
    final diffMin = fichaje.difference(evento.inicio).inMinutes;

    if (diffMin <= umbralRetrasoMin) return "Puntual";
    return "Retraso";
  }

  /// ********************************************************
  /// Genera un PDF con todas las asistencias del músico
  ///
  /// - Agrupa por tipo de evento
  /// - Ordena los eventos por fecha
  /// - Incluye resumen de puntuales, retrasos y ausencias
  /// - Muestra la fecha, hora y ubicación del evento
  /// ********************************************************
  Future<void> generarPdfAsistencias() async {
    final pdf = pw.Document();

    // Cabecera general
    pdf.addPage(
      pw.MultiPage(
        build: (context) {
          final List<pw.Widget> contenido = [];

          // Cabecera
          contenido.add(
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(widget.nombreBanda, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text('Informe de Asistencias', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.Text(widget.nombreMusico, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 12),
              ],
            ),
          );

          // Tipos de eventos
          final tipos = ["Ensayo", "Actuación", "Semana Santa"];

          for (final tipo in tipos) {
            // Filtrar eventos del tipo y que ya hayan ocurrido
            final eventosPorTipo = eventos.where((e) => e.tipo == tipo && e.inicio.isBefore(DateTime.now())).toList();

            if (eventosPorTipo.isEmpty) continue;

            // Ordenar eventos por fecha de inicio
            eventosPorTipo.sort((a, b) => a.inicio.compareTo(b.inicio));

            // Contadores
            int puntuales = 0;
            int retrasos = 0;
            int ausencias = 0;

            // Construir filas
            final List<List<String>> filas = eventosPorTipo.map((evt) {
              final estado = estadoAsistencia(evt);

              // Contar
              if (estado == "Puntual") {
                puntuales++;
              } else if (estado == "Retraso") {
                retrasos++;
              } else {
                ausencias++;
              }

              // Texto de estado para PDF
              String estadoTexto;
              if (estado == "Puntual") {
                estadoTexto = "Puntual";
              } else if (estado == "Retraso") {
                final fichaje = asistenciasMusico[evt.id]!;
                final minutosRetraso = fichaje.difference(evt.inicio).inMinutes;
                estadoTexto = "Retraso \n(+$minutosRetraso min)";
              } else {
                estadoTexto = "";
              }

              // Fecha y hora
              final fechaStr =
                  "${evt.inicio.day.toString().padLeft(2, '0')}/${evt.inicio.month.toString().padLeft(2, '0')}/${evt.inicio.year}";
              final horarioStr =
                  "${evt.inicio.hour.toString().padLeft(2, '0')}:${evt.inicio.minute.toString().padLeft(2, '0')}";

              final descripcionConFecha = "${evt.descripcion}\nFecha: $fechaStr Hora: $horarioStr";

              return [descripcionConFecha, evt.nombreUbicacionEvento ?? '', estadoTexto];
            }).toList();

            // Título del tipo
            contenido.add(pw.Text(tipo, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)));
            contenido.add(pw.SizedBox(height: 4));

            // Tabla
            contenido.add(
              pw.TableHelper.fromTextArray(
                headers: ['Evento', 'Lugar', 'Estado'],
                data: filas,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
              ),
            );

            // Resumen
            contenido.add(pw.SizedBox(height: 4));
            contenido.add(
              pw.Text(
                'Resumen: Puntual $puntuales | Retraso $retrasos | Ausencias $ausencias',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
            );
            contenido.add(pw.SizedBox(height: 12));
          }

          return contenido;
        },
      ),
    );

    // Mostrar PDF
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  /// ********************************************************
  ///                  --- Construir UI ---
  ///
  /// - AppBar con nombre de la temporada y del músico
  /// - Botón para generar PDF
  /// - Filtros por tipo de evento y estado de asistencia
  /// - Lista de eventos con tarjeta, color según asistencia
  /// ********************************************************
  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return Scaffold(
        // ----------------------------
        //         BARRA SUPERIOR
        // ----------------------------
        appBar: AppBar(title: Text("Asistencias")),
        // ----------------------------
        //       CUERPO PRINCIPAL
        // ----------------------------
        body: cargando
            ? const Center(child: CircularProgressIndicator())
            : const Center(child: CircularProgressIndicator()),
      );
    }

    // Aplicar filtros
    final eventosFiltrados = eventos.where((evento) {
      //Excluir eventos futuros
      if (evento.inicio.isAfter(DateTime.now())) return false;

      bool tipoOk = tipoEventoFiltro == "Todos" || evento.tipo == tipoEventoFiltro;
      final estado = estadoAsistencia(evento);
      bool estadoOk = estadoFiltro == "Todos" || estado == estadoFiltro;

      return tipoOk && estadoOk;
    }).toList();

    return Scaffold(
      // ----------------------------
      //         BARRA SUPERIOR
      // ----------------------------
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Asistencias $nombreTemporada"),
            Text(nombreMusico ?? '', style: const TextStyle(fontSize: 14)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.indigo),
            onPressed: generarPdfAsistencias,
          ),
        ],
      ),

      // ----------------------------
      //       CUERPO PRINCIPAL
      // ----------------------------
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            // ----------------------------
            //          FILTROS
            // ----------------------------
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Flexible(
                    child: AppDropdown<String>(
                      label: "Tipo de evento",
                      value: tipoEventoFiltro,
                      items: tiposEvento
                          .map(
                            (tipo) => DropdownMenuItem(
                              value: tipo,
                              child: Text(tipo, style: const TextStyle(fontSize: 14)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          tipoEventoFiltro = value!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: AppDropdown<String>(
                      label: "Estado de asistencia",
                      value: estadoFiltro,
                      items: estadosAsistencia
                          .map(
                            (estado) => DropdownMenuItem(
                              value: estado,
                              child: Text(estado, style: const TextStyle(fontSize: 14)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          estadoFiltro = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ----------------------------
            //       LISTA DE EVENTOS
            // ----------------------------
            Expanded(
              child: eventosFiltrados.isEmpty
                  ? const Center(child: Text("No hay eventos que coincidan con los filtros."))
                  : ListView.builder(
                      itemCount: eventosFiltrados.length,
                      itemBuilder: (context, index) {
                        final evt = eventosFiltrados[index];

                        // Determinar color según asistencia
                        final estado = estadoAsistencia(evt);
                        final color = estado == "Puntual"
                            ? Colors.green
                            : (estado == "Retraso" ? Colors.orange : Colors.red);

                        return Tarjeta(
                          colorIcono: color,
                          iconoWidget: MiniCalendario(fecha: evt.inicio, colorCalendario: color),
                          titulo: evt.descripcion,
                          subtituloWidget: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "🕒 De ${evt.inicio.hour}:${evt.inicio.minute.toString().padLeft(2, '0')} h. a "
                                "${'${evt.fin.hour}:${evt.fin.minute.toString().padLeft(2, '0')}'} h.",
                                style: const TextStyle(color: Colors.black87, fontSize: 13),
                              ),
                              Text(
                                "📍 ${evt.nombreUbicacionEvento ?? 'No definido'}",
                                style: const TextStyle(color: Colors.black54, fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
