import 'package:flutter/material.dart';
import 'package:ritmo_app/consultas_bd/asistencias.dart';
import 'package:ritmo_app/consultas_bd/eventos.dart';
import 'package:ritmo_app/modelos/musico_prevision.dart';
import 'package:ritmo_app/utiles/widgets.dart';

/// ****************************************************************
/// Página de lista de previsión de asistencias de un evento
///
/// Funcionalidades:
/// - Ver músicos agrupados por instrumento
/// - Filtrar por asistencia (Sí / No / NS-NC)
/// - Buscar por nombre o instrumento
/// - Ordenar alfabéticamente
/// - Mostrar motivo si no asiste
/// ****************************************************************
class PaginaListaPrevisionAsistencias extends StatefulWidget {
  final String bandaId;
  final String eventoId;

  const PaginaListaPrevisionAsistencias({super.key, required this.bandaId, required this.eventoId});

  @override
  State<PaginaListaPrevisionAsistencias> createState() => EstadoPaginaListaPrevisionAsistencias();
}

enum FiltroAsistencia { asisten, noAsisten, sinResponder }

/// ****************************************************************
/// Estado de la página de previsión de asistencias
///
/// Guarda todos los datos que cambian:
/// - Orden ascendente o descendente
/// - Filtro por asistencia
/// - Texto de búsqueda
/// - Fecha del evento
/// - Lista de músicos
/// - Indicador de carga
/// ****************************************************************
class EstadoPaginaListaPrevisionAsistencias extends State<PaginaListaPrevisionAsistencias> {
  bool ordenAscendente = true;
  FiltroAsistencia filtroAsistencia = FiltroAsistencia.asisten;
  String filtroBusqueda = "";

  final TextEditingController controladorBusqueda = TextEditingController();

  DateTime? fechaInicioEventoSeleccionado;
  bool cargando = true;
  List<PrevisionMusico> lista = [];

  /// **************************************************************
  /// Inicialización
  ///
  /// - Carga la fecha del evento
  /// - Carga la lista de previsión de asistencias
  /// **************************************************************
  @override
  void initState() {
    super.initState();
    cargarDatos();
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
  /// Cargar datos desde base de datos
  ///
  /// - Obtiene el evento para mostrar su fecha
  /// - Obtiene la lista de previsión de asistencias
  /// **************************************************************
  Future<void> cargarDatos() async {
    final evento = await ConsultasEventosBD.obtenerEventoPorId(widget.bandaId, widget.eventoId);

    if (evento != null) {
      fechaInicioEventoSeleccionado = evento.inicio;
    }
    lista = await ConsultasAsistenciasBD.obtenerPrevisionAsistencia(bandaId: widget.bandaId, eventoId: widget.eventoId);

    setState(() {
      cargando = false;
    });
  }

  /// **************************************************************
  /// Formatear fecha en formato dd/mm/yyyy
  /// **************************************************************
  String formatearFecha(DateTime fecha) {
    return "${fecha.day.toString().padLeft(2, '0')}/"
        "${fecha.month.toString().padLeft(2, '0')}/"
        "${fecha.year}";
  }

  /// **************************************************************
  /// Filtrar músicos por estado de asistencia
  ///
  /// - Sí asisten
  /// - No asisten
  /// - Sin responder
  /// **************************************************************
  bool filtrarPorAsistencia(PrevisionMusico u) {
    switch (filtroAsistencia) {
      case FiltroAsistencia.asisten:
        return u.asistira == true;
      case FiltroAsistencia.noAsisten:
        return u.asistira == false;
      case FiltroAsistencia.sinResponder:
        return u.asistira == null;
    }
  }

  /// **************************************************************
  ///                  --- Construir UI ---
  ///
  /// - AppBar: muestra la fecha del evento
  /// - Cuerpo principal:
  ///    a) Cuadro de búsqueda
  ///    b) Filtro por asistencia (radio buttons)
  ///    c) Lista agrupada por instrumento
  ///       - Orden alfabético
  ///       - Color lateral según estado
  ///       - Motivo si no asiste
  /// **************************************************************
  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      // ----------------------------
      //         BARRA SUPERIOR
      // ----------------------------
      appBar: AppBar(
        title: Text(
          fechaInicioEventoSeleccionado != null
              ? 'Previsión de Asistencia ${formatearFecha(fechaInicioEventoSeleccionado!)}'
              : 'Previsión de Asistencia',
        ),
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
              hintText: 'Buscar por nombre o instrumento',
              onChanged: (v) => setState(() => filtroBusqueda = v.toLowerCase()),
            ),

            // ----------------------------
            //     OPCIONES EN CABECERA
            // ----------------------------
            RadioGroup<FiltroAsistencia>(
              groupValue: filtroAsistencia,
              onChanged: (value) {
                if (value == null) return;
                setState(() => filtroAsistencia = value);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: FiltroAsistencia.values.map((f) {
                  final label = f == FiltroAsistencia.asisten
                      ? "Si"
                      : f == FiltroAsistencia.noAsisten
                      ? "No"
                      : "NS/NC";

                  return Expanded(
                    child: Row(
                      children: [
                        Radio<FiltroAsistencia>(value: f),
                        Flexible(child: Text(label)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            // ----------------------------
            //        BUSQUEDA MUSICOS
            // ----------------------------
            Expanded(
              child: Builder(
                builder: (context) {
                  final listaFiltrada = lista
                      .where(
                        (u) =>
                            filtrarPorAsistencia(u) &&
                            (filtroBusqueda.isEmpty ||
                                u.nombre.toLowerCase().contains(filtroBusqueda) ||
                                u.instrumento.toLowerCase().contains(filtroBusqueda)),
                      )
                      .toList();

                  final Map<String, List<PrevisionMusico>> agrupados = {};

                  for (var u in listaFiltrada) {
                    agrupados.putIfAbsent(u.instrumento, () => []);
                    agrupados[u.instrumento]!.add(u);
                  }

                  final instrumentosOrdenados = agrupados.keys.toList()
                    ..sort((a, b) => ordenAscendente ? a.compareTo(b) : b.compareTo(a));

                  return ListView(
                    children: instrumentosOrdenados.map((inst) {
                      final usuarios = agrupados[inst]!;

                      usuarios.sort(
                        (a, b) => ordenAscendente
                            ? a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase())
                            : b.nombre.toLowerCase().compareTo(a.nombre.toLowerCase()),
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 2),
                            child: Align(
                              alignment: Alignment.center,
                              child: Text(
                                inst.toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
                              ),
                            ),
                          ),
                          ...usuarios.map((u) {
                            final estadoColor = u.asistira == true
                                ? Colors.green
                                : u.asistira == false
                                ? Colors.red
                                : Colors.orange;

                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border(left: BorderSide(color: estadoColor, width: 6)),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(2, 3)),
                                ],
                              ),
                              child: Row(
                                children: [
                                  MiniAvatar(inicial: u.nombre.isNotEmpty ? u.nombre[0].toUpperCase() : '?'),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          u.nombre,
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          "${u.instrumento} ${u.categoria}",
                                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                                        ),
                                        if (u.asistira == false && u.motivo != null)
                                          Text(
                                            'Motivo: ${u.motivo}${u.otrosDetalle != null ? " (${u.otrosDetalle})" : ""}',
                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      );
                    }).toList(),
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
