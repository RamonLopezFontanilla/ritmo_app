import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:ritmo_app/consultas_bd/asistencias.dart';
import 'package:ritmo_app/consultas_bd/bandas.dart';
import 'package:ritmo_app/consultas_bd/eventos.dart';
import 'package:ritmo_app/consultas_bd/musicos.dart';
import 'package:ritmo_app/consultas_bd/parametros_banda.dart';
import 'package:ritmo_app/modelos/musico.dart';
import 'package:ritmo_app/utiles/widgets.dart';

/// ****************************************************************
/// Página de pasar lista de un evento
///
/// Funcionalidades:
/// - Ver músicos activos agrupados por instrumento
/// - Marcar/desmarcar asistencia en tiempo real
/// - Detectar retrasos según umbral configurable
/// - Buscar músicos por nombre o instrumento
/// - Generar PDF con el listado de asistencias
/// ****************************************************************
class PaginaPasarListaEvento extends StatefulWidget {
  final String temporadaSeleccionadaId;
  final String bandaId;
  final String eventoId;
  final DateTime fechaInicioEvento;
  final DateTime fechaFinEvento;

  const PaginaPasarListaEvento({
    super.key,
    required this.temporadaSeleccionadaId,
    required this.bandaId,
    required this.eventoId,
    required this.fechaInicioEvento,
    required this.fechaFinEvento,
  });

  @override
  State<PaginaPasarListaEvento> createState() => EstadoPaginaPasarListaEvento();
}

/// ****************************************************************
/// Estado de la página de pasar lista
///
/// Guarda todos los datos que cambian:
/// - Mapa local de asistencias modificadas
/// - Texto de búsqueda
/// - Umbral de retraso
/// ****************************************************************
class EstadoPaginaPasarListaEvento extends State<PaginaPasarListaEvento> {
  Map<String, DateTime?> mapaAsistencias = {};
  final TextEditingController controladorBusqueda = TextEditingController();

  String filtroBusqueda = "";
  int umbralRetraso = 10;

  /// **************************************************************
  /// Inicialización
  ///
  /// - Obtiene el umbral de retraso configurado para la banda
  /// **************************************************************
  @override
  void initState() {
    super.initState();
    ConsultasParametrosBD.obtenerUmbralRetraso(widget.bandaId).then((valor) {
      setState(() {
        umbralRetraso = valor;
      });
    });
  }

  /// **************************************************************
  /// Liberación de memoria
  ///
  /// - Libera el controlador de búsqueda
  /// **************************************************************
  @override
  void dispose() {
    controladorBusqueda.dispose();
    super.dispose();
  }

  /// **************************************************************
  /// Generar PDF de asistencias
  ///
  /// - Obtiene músicos activos
  /// - Obtiene asistencias reales del evento
  /// - Agrupa por instrumento
  /// - Calcula retrasos
  /// - Genera documento PDF listo para imprimir/compartir
  /// **************************************************************
  Future<void> generarPdfAsistencias() async {
    // Obtener músicos
    final musicos = await ConsultasMusicosBD.streamMusicos(widget.bandaId).first;

    // Obtener asistencias reales de la DB
    final asistencias = await ConsultasAsistenciasBD.streamAsistenciasEvento(
      bandaId: widget.bandaId,
      eventoId: widget.eventoId,
    ).first; // Map<String, DateTime>

    // Información de la banda y evento
    final bandaDoc = await ConsultasBandasBD.obtenerDatosBanda(widget.bandaId);
    final nombreBanda = bandaDoc?.data()?['nombre'] ?? 'Banda';
    final evento = await ConsultasEventosBD.obtenerEventoPorId(widget.bandaId, widget.eventoId);
    final fechaFormateada = DateFormat('dd/MM/yyyy HH:mm').format(widget.fechaInicioEvento);

    // Umbral de retraso
    final umbralRetraso = await ConsultasParametrosBD.obtenerUmbralRetraso(widget.bandaId);

    // --- AGRUPAR MÚSICOS POR INSTRUMENTO ---
    final Map<String, List<Musico>> musicosPorInstrumento = {};
    for (var m in musicos) {
      final instr = m.instrumentoNombre.isNotEmpty ? m.instrumentoNombre : 'Sin instrumento';
      musicosPorInstrumento.putIfAbsent(instr, () => []).add(m);
    }

    // Ordenar instrumentos alfabéticamente
    final instrumentosOrdenados = musicosPorInstrumento.keys.toList()..sort();

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) {
          final List<List<String>> filas = [];

          // Recorrer instrumentos
          for (final instr in instrumentosOrdenados) {
            final listaMusicos = musicosPorInstrumento[instr]!;

            // Ordenar músicos por nombre
            listaMusicos.sort((a, b) => a.nombre.compareTo(b.nombre));

            // Agregar músicos
            for (var m in listaMusicos) {
              final fichaje = asistencias[m.uid];
              String estado;
              if (fichaje == null) {
                estado = '';
              } else {
                final minutosRetraso = fichaje.difference(widget.fechaInicioEvento).inMinutes;
                if (minutosRetraso > umbralRetraso) {
                  estado = 'Presente (+$minutosRetraso min)';
                } else {
                  estado = 'Presente';
                }
              }
              filas.add([m.nombre, m.instrumentoNombre, estado]);
            }
          }

          return [
            // CABECERA
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(nombreBanda, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),
                pw.Text(
                  evento?.descripcion ?? 'Evento',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 5),
                pw.Text('Fecha inicio: $fechaFormateada', style: const pw.TextStyle(fontSize: 14)),
              ],
            ),
            pw.Divider(),
            pw.SizedBox(height: 15),

            // TABLA
            pw.TableHelper.fromTextArray(
              headers: ['Nombre', 'Instrumento', 'Estado'],
              data: filas,
              cellAlignment: pw.Alignment.centerLeft,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ];
        },
      ),
    );

    // Imprimir PDF
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  /// **************************************************************
  ///                  --- Construir UI ---
  ///
  /// - AppBar con botón de exportar PDF
  /// - Cuadro de búsqueda
  /// - Lista en tiempo real de músicos
  /// - Agrupación por instrumento
  /// - Indicador visual:
  ///     • Verde --> Presente
  ///     • Amarillo --> Presente con retraso
  ///     • Rojo --> Ausente
  /// **************************************************************
  @override
  Widget build(BuildContext context) {
    final fechaFormateada = DateFormat('dd/MM/yy').format(widget.fechaInicioEvento);
    return Scaffold(
      // ----------------------------
      //         BARRA SUPERIOR
      // ----------------------------
      appBar: AppBar(
        title: Text('Pasar Lista a $fechaFormateada'),
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
            //       CUADRO BÚSQUEDA
            // ----------------------------
            CuadroBusqueda(
              controller: controladorBusqueda,
              hintText: 'Buscar músico...',
              onChanged: (val) {
                setState(() {
                  filtroBusqueda = val.trim().toLowerCase();
                });
              },
            ),
            const SizedBox(height: 14),
            // -----------------------------------
            //     BUSQUEDA MÚSICOS-ASISTENCIAS
            // -----------------------------------
            Expanded(
              child: StreamBuilder<List<Musico>>(
                stream: ConsultasMusicosBD.streamMusicos(widget.bandaId),
                builder: (context, snapshotMusicos) {
                  if (snapshotMusicos.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshotMusicos.hasData || snapshotMusicos.data!.isEmpty) {
                    return const Center(child: Text('No hay músicos disponibles.'));
                  }

                  // Filtrar según búsqueda
                  final musicosFiltrados = snapshotMusicos.data!
                      .where(
                        (m) =>
                            m.activo &&
                            (m.nombre.toLowerCase().contains(filtroBusqueda) ||
                                m.instrumentoNombre.toLowerCase().contains(filtroBusqueda)),
                      )
                      .toList();

                  // Agrupar por instrumento
                  final Map<String, List<Musico>> musicosPorInstrumento = {};
                  for (var m in musicosFiltrados) {
                    final instr = m.instrumentoNombre.isNotEmpty ? m.instrumentoNombre : 'Sin instrumento';
                    musicosPorInstrumento.putIfAbsent(instr, () => []).add(m);
                  }

                  // Ordenar instrumentos alfabéticamente
                  final instrumentosOrdenados = musicosPorInstrumento.keys.toList()..sort();

                  if (musicosFiltrados.isEmpty) {
                    return const Center(child: Text('No se encontraron músicos.'));
                  }

                  return StreamBuilder<Map<String, DateTime>>(
                    stream: ConsultasAsistenciasBD.streamAsistenciasEvento(
                      bandaId: widget.bandaId,
                      eventoId: widget.eventoId,
                    ),
                    builder: (context, snapshotAsistencias) {
                      final asistencias = snapshotAsistencias.data ?? {};

                      // ----------------------------
                      //       LISTA MÚSICOS
                      // ----------------------------
                      return ListView(
                        children: instrumentosOrdenados.expand((instr) {
                          final musicos = musicosPorInstrumento[instr]!;
                          // Ordenar músicos por nombre
                          musicos.sort((a, b) => a.nombre.compareTo(b.nombre));

                          return [
                            // Cabecera del instrumento
                            Padding(
                              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 2),
                              child: Center(
                                child: Text(
                                  instr.toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
                                ),
                              ),
                            ),
                            // Lista de músicos de ese instrumento
                            ...musicos.map((musico) {
                              final musicoId = musico.uid;
                              final momentoFichaje = asistencias[musicoId];
                              final presente = (mapaAsistencias[musicoId] ?? momentoFichaje) != null;

                              int minutosRetraso = 0;
                              bool esRetraso = false;

                              if (momentoFichaje != null) {
                                minutosRetraso = momentoFichaje.difference(widget.fechaInicioEvento).inMinutes;
                                if (minutosRetraso > umbralRetraso) esRetraso = true;
                              }

                              return Tarjeta(
                                titulo: musico.nombre,
                                subtitulo:
                                    '${musico.instrumentoNombre}'
                                    '${musico.categoriaNombre.isNotEmpty ? " - ${musico.categoriaNombre}" : ""}'
                                    '${esRetraso ? " - ($minutosRetraso min retraso)" : ""}',
                                colorIcono: !presente
                                    ? Colors.red.shade700
                                    : esRetraso
                                    ? Colors.amber
                                    : Colors.green,
                                iconoWidget: null,
                                onTap: () async {
                                  final estabaPresente = presente;
                                  final nuevoPresente = !estabaPresente;
                                  final nuevoFichaje = nuevoPresente ? DateTime.now() : null;

                                  await ConsultasAsistenciasBD.guardarAsistenciaEvento(
                                    temporadaSeleccionadaId: widget.temporadaSeleccionadaId,
                                    bandaId: widget.bandaId,
                                    eventoId: widget.eventoId,
                                    musicoId: musicoId,
                                    fichaje: nuevoFichaje,
                                    presente: nuevoPresente,
                                    fechaInicioEvento: widget.fechaInicioEvento,
                                    fechaFinEvento: widget.fechaFinEvento,
                                  );

                                  setState(() {
                                    mapaAsistencias[musicoId] = nuevoFichaje;
                                  });
                                },
                              );
                            }),
                          ];
                        }).toList(),
                      );
                    },
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
