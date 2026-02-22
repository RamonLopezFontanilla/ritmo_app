import 'package:flutter/material.dart';
import 'package:ritmo_app/consultas_bd/eventos.dart';
import 'package:ritmo_app/consultas_bd/temporada.dart';
import 'package:ritmo_app/consultas_bd/ubicaciones.dart';
import 'package:ritmo_app/modelos/evento.dart';
import 'package:ritmo_app/modelos/ubicacion.dart';
import 'package:ritmo_app/ui/datos_evento.dart';
import 'package:ritmo_app/ui/lista_prevision_asistencias.dart';
import 'package:ritmo_app/ui/lista_pasar_lista.dart';
import 'package:ritmo_app/ui/comunicar_asistencia.dart';
import 'package:ritmo_app/ui/lista_repertorio.dart';
import 'package:ritmo_app/utiles/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// ****************************************************************************************
/// Página de Lista de Eventos
///
/// Permite:
/// - Visualizar todos los eventos de una temporada
/// - Filtrar por finalizados/no finalizados
/// - Buscar por tipo o descripción
/// - Ordenar eventos por fecha (ascendente/descendente)
/// - Crear, editar, eliminar eventos (si esAdmin)
/// - Acceder a repertorio, previsión de asistencias y pasar lista
/// - Abrir ubicación en Google Maps y elegir entre lugar de cita y evento
///
/// Es un [StatefulWidget] porque:
/// - Gestiona estado de búsqueda, filtros y lista de eventos
/// - Carga datos async y cache de ubicaciones
/// - Controla navegación y acciones según rol
/// ****************************************************************************************
class PaginaListaEventos extends StatefulWidget {
  final bool esAdmin;
  final String uid;
  final String bandaId;
  final String temporadaSeleccionadaId;

  const PaginaListaEventos({
    super.key,
    required this.uid,
    required this.esAdmin,
    required this.bandaId,
    required this.temporadaSeleccionadaId,
  });

  @override
  State<PaginaListaEventos> createState() => EstadoPaginaListaEventos();
}

/// ****************************************************************************************
/// Estado de la página de Lista de Eventos
///
/// Contiene:
/// - Lista de eventos y cache de ubicaciones
/// - Filtros de búsqueda, finalizados y orden
/// - Funciones para abrir mapas, mostrar menús y CRUD de eventos
/// ****************************************************************************************
class EstadoPaginaListaEventos extends State<PaginaListaEventos> {
  final TextEditingController controladorBusqueda = TextEditingController();
  String? nombreTemporada = "";
  bool mostrarFinalizados = false;
  bool ordenAscendente = true;
  String filtroBusqueda = "";
  List<Evento> eventos = [];
  bool cargando = true;

  Map<String, Ubicacion> ubicacionesCache = {};

  /// ***********************************************
  /// Inicialización
  ///
  /// Se ejecuta al crear la pantalla. Carga datos de eventos de la temporada
  /// ***********************************************
  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  /// ***********************************************
  /// Liberación de memoria
  ///
  /// Se libera el controlador de búsqueda
  /// ***********************************************
  @override
  void dispose() {
    controladorBusqueda.dispose();
    super.dispose();
  }

  /// ***********************************************
  /// Cargar datos de la temporada y eventos
  ///
  /// Flujo:
  /// 1. Mostrar indicador de carga
  /// 2. Obtener nombre de la temporada de la BD
  /// 3. Obtener lista de eventos de la temporada
  /// 4. Para cada evento, obtener nombre de ubicación y almacenarlo localmente
  /// 5. Ocultar indicador de carga
  /// ***********************************************
  Future<void> cargarDatos() async {
    setState(() => cargando = true);
    nombreTemporada = await ConsultasTemporadasBD.obtenerNombreTemporada(
      widget.bandaId,
      widget.temporadaSeleccionadaId,
    );
    eventos = await ConsultasEventosBD.obtenerEventosDeTemporada(widget.bandaId, widget.temporadaSeleccionadaId);

    for (var evt in eventos) {
      evt.nombreUbicacionEvento = await ConsultasUbicacionesBD.obtenerNombreUbicacion(
        widget.bandaId,
        evt.ubicacionEventoId,
      );
    }

    setState(() => cargando = false);
  }

  /// ***********************************************
  /// Abrir Google Maps en coordenadas
  ///
  /// Intenta abrir la app nativa de Maps primero. Si falla, abre la versión web.
  /// ***********************************************
  Future<void> abrirMapsCoordenadas({required double lat, required double lng}) async {
    final uri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
    final webUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) return;
    context.mostrarSnack("No se pudo abrir Google Maps", esCorrecto: false);
  }

  /// ***********************************************
  /// Mostrar diálogo si el lugar de cita y el del evento son distintos
  ///
  /// Permite al usuario decidir a cuál ubicación abrir en Maps
  /// ***********************************************
  Future<void> mostrarDialogoUbicacionesPorCoordenadas({
    required BuildContext context,
    required Ubicacion evento,
    required Ubicacion cita,
  }) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('¿A dónde quieres ir?'),
        content: const Text('El lugar de cita y el del evento son distintos.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              abrirMapsCoordenadas(lat: cita.latitud, lng: cita.longitud);
            },
            child: Text('Lugar de cita\n${cita.nombre}'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              abrirMapsCoordenadas(lat: evento.latitud, lng: evento.longitud);
            },
            child: Text('Lugar del evento\n${evento.nombre}'),
          ),
        ],
      ),
    );
  }

  /// ***********************************************
  /// Mostrar menú de opciones al tocar un evento
  ///
  /// Admin --> Editar, Repertorio, Previsión, Pasar Lista, Eliminar
  /// Usuario --> Ver Repertorio, Confirmar asistencia si el evento no ha empezado
  /// También permite abrir Maps
  /// ***********************************************
  void mostrarOpcionesEvento(BuildContext context, Evento evt) {
    final bool eventoEmpezado = evt.inicio.isBefore(DateTime.now());

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        final puedePasarLista = evt.inicio.isBefore(DateTime.now());

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.esAdmin) ...[
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Editar evento'),
                  onTap: () async {
                    Navigator.pop(context); // Cierra el BottomSheet

                    // Abrir la página de edición y esperar el evento editado
                    final Evento? eventoActualizado = await Navigator.push<Evento?>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PaginaDatosEvento(
                          bandaId: widget.bandaId,
                          temporada: widget.temporadaSeleccionadaId,
                          eventoId: evt.id,
                        ),
                      ),
                    );

                    if (!mounted) return;

                    if (eventoActualizado != null) {
                      // Reemplazar solo el evento editado en la lista
                      setState(() {
                        final index = eventos.indexWhere((e) => e.id == eventoActualizado.id);
                        if (index != -1) {
                          eventos[index] = eventoActualizado;
                        }
                      });
                      context.mostrarSnack("Evento actualizado correctamente", esCorrecto: true);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.music_note),
                  title: const Text('Ver/Añadir Repertorio'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PaginaListaRepertorio(
                          esAdmin: widget.esAdmin,
                          bandaId: widget.bandaId,
                          eventoId: evt.id,
                          musicoId: widget.uid,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.people_alt),
                  title: const Text('Previsión de asistencias'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PaginaListaPrevisionAsistencias(bandaId: widget.bandaId, eventoId: evt.id),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.list),
                  title: Text('Pasar lista', style: TextStyle(color: puedePasarLista ? null : Colors.grey)),
                  enabled: puedePasarLista,
                  onTap: puedePasarLista
                      ? () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaginaPasarListaEvento(
                                temporadaSeleccionadaId: widget.temporadaSeleccionadaId,
                                bandaId: widget.bandaId,
                                eventoId: evt.id,
                                fechaInicioEvento: evt.inicio,
                                fechaFinEvento: evt.fin,
                              ),
                            ),
                          );
                        }
                      : null,
                ),
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: const Text('Eliminar evento'),
                  onTap: () async {
                    final navigator = Navigator.of(context);

                    navigator.pop();

                    // Preguntar confirmación
                    final confirmar = await mostrarDialogoConfirmacion(
                      context: context,
                      titulo: 'Eliminar evento',
                      mensaje: '¿Estás seguro de eliminar este evento?\nSe eliminarán también todas sus asistencias.',
                      icono: Icons.delete_forever,
                      colorIcono: Colors.red.shade700,
                    );

                    if (!confirmar || !mounted) return;

                    try {
                      // Llamada a ConsultasBD para eliminar evento y asistencias
                      await ConsultasEventosBD.eliminarEventoYAsistencias(bandaId: widget.bandaId, eventoId: evt.id);

                      if (!mounted) return;
                      context.mostrarSnack("Evento y asistencias eliminadas", esCorrecto: true);

                      // Actualizar la lista local
                      setState(() {
                        eventos.removeWhere((e) => e.id == evt.id);
                      });
                    } catch (e) {
                      if (!mounted) return;
                      context.mostrarSnack("Error eliminando evento: $e", esCorrecto: false);
                    }
                  },
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.music_note),
                  title: const Text('Ver Repertorio'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PaginaListaRepertorio(
                          esAdmin: widget.esAdmin,
                          bandaId: widget.bandaId,
                          eventoId: evt.id,
                          musicoId: widget.uid,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.check, color: eventoEmpezado ? Colors.grey : null),
                  title: Text(
                    'Confirmar asistencia/ausencia',
                    style: TextStyle(color: eventoEmpezado ? Colors.grey : null),
                  ),
                  enabled: !eventoEmpezado,
                  onTap: eventoEmpezado
                      ? null
                      : () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PaginaPrevisionAsistencia(bandaId: widget.bandaId, eventoId: evt.id, uid: widget.uid),
                            ),
                          );
                        },
                ),
              ],
              ListTile(
                leading: const Icon(Icons.map),
                title: const Text('Cómo llegar a evento'),
                onTap: () async {
                  Navigator.pop(context);
                  // Obtener la ubicación del evento
                  final eventoUbicacion = await ConsultasUbicacionesBD.obtenerUbicacion(
                    widget.bandaId,
                    evt.ubicacionEventoId,
                  );

                  // Obtener la ubicación de la cita, si existe
                  final citaUbicacion = evt.ubicacionCitaId.isNotEmpty
                      ? await ConsultasUbicacionesBD.obtenerUbicacion(widget.bandaId, evt.ubicacionCitaId)
                      : null;

                  // Revisar si la ubicación del evento existe
                  if (eventoUbicacion == null) {
                    context.mostrarSnack("No hay ubicación del evento definida", esCorrecto: false);
                    return;
                  }

                  // Decidir a dónde dirigir según si la ubicación de cita es distinta
                  if (citaUbicacion == null || eventoUbicacion.id == citaUbicacion.id) {
                    // Mismo lugar o no hay cita definida → abrir evento directamente
                    await abrirMapsCoordenadas(lat: eventoUbicacion.latitud, lng: eventoUbicacion.longitud);
                  } else {
                    // Lugares distintos → mostrar diálogo para elegir
                    await mostrarDialogoUbicacionesPorCoordenadas(
                      context: context,
                      evento: eventoUbicacion,
                      cita: citaUbicacion,
                    );
                  }
                },
              ),

              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancelar'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  /// ********************************************************
  ///                  --- Construir UI ---
  ///
  /// Estructura:
  /// - AppBar con nombre de temporada
  /// - FloatingActionButton (solo admin)
  /// - Cuadro de búsqueda
  /// - Filtro de eventos finalizados
  /// - Selector de orden asc/desc
  /// - Lista dinámica de eventos
  ///
  /// La lista:
  /// - Se filtra en memoria
  /// - Se ordena dinámicamente
  /// - Colorea eventos según estado:
  ///     Rojo --> Finalizado
  ///     Verde --> En curso
  ///     Naranja --> Próximo
  ///
  /// Usa Tarjeta personalizada con MiniCalendario
  /// ********************************************************
  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();

    var eventosFiltrados = eventos.where((evt) {
      if (!mostrarFinalizados && evt.fin.isBefore(ahora)) {
        return false;
      }
      return true;
    }).toList();

    if (filtroBusqueda.isNotEmpty) {
      eventosFiltrados = eventosFiltrados.where((evt) {
        return evt.descripcion.toLowerCase().contains(filtroBusqueda) ||
            evt.tipo.toLowerCase().contains(filtroBusqueda);
      }).toList();
    }

    eventosFiltrados.sort((a, b) => ordenAscendente ? a.inicio.compareTo(b.inicio) : b.inicio.compareTo(a.inicio));

    return Scaffold(
      // ----------------------------
      //         BARRA SUPERIOR
      // ----------------------------
      appBar: AppBar(title: Text("Eventos $nombreTemporada")),

      // ----------------------------
      //         BOTÓN FLOTANTE
      // ----------------------------
      floatingActionButton: widget.esAdmin
          ? FloatingActionButton(
              child: const Icon(Icons.add),
              onPressed: () async {
                // Abrir página de creación de evento
                final nuevoEvento = await Navigator.push<Evento>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PaginaDatosEvento(bandaId: widget.bandaId, temporada: widget.temporadaSeleccionadaId),
                  ),
                );
                // Refrescar toda la lista
                cargarDatos();

                // Si se devolvió un evento, agregarlo a la lista y actualizar
                if (nuevoEvento != null) {
                  setState(() {
                    eventos.add(nuevoEvento);
                  });
                }
              },
            )
          : null,

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
              hintText: 'Buscar por tipo o descripcion',
              onChanged: (v) => setState(() => filtroBusqueda = v.toLowerCase()),
            ),

            // ----------------------------
            //     OPCIONES EN CABECERA
            // ----------------------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("  Incluir Finalizados"),
                Transform.scale(
                  scale: 0.7,
                  child: Switch(
                    value: mostrarFinalizados,
                    onChanged: (value) => setState(() => mostrarFinalizados = value),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => ordenAscendente = !ordenAscendente),
                  icon: Icon(ordenAscendente ? Icons.arrow_upward : Icons.arrow_downward, size: 20),
                  label: Text(ordenAscendente ? "Ascendente" : "Descendente", style: const TextStyle(fontSize: 14)),
                ),
              ],
            ),

            // ----------------------------
            //        BUSQUEDA EVENTOS
            // ----------------------------
            Expanded(
              child: cargando
                  ? const Center(child: CircularProgressIndicator())
                  : eventosFiltrados.isEmpty
                  ? const Center(child: Text("No hay eventos que coincidan"))
                  :
                    // ----------------------------
                    //       LISTA EVENTOS
                    // ----------------------------
                    ListView.builder(
                      itemCount: eventosFiltrados.length,
                      itemBuilder: (context, index) {
                        final evt = eventosFiltrados[index];
                        Color color;

                        if (evt.fin.isBefore(ahora)) {
                          color = const Color(0xFFFF5252);
                        } else if (evt.inicio.isBefore(ahora)) {
                          color = const Color.fromARGB(255, 2, 175, 92);
                        } else {
                          color = const Color.fromARGB(255, 241, 146, 3);
                        }

                        // ----------------------------
                        //       TARJETA EVENTO
                        // ----------------------------
                        return Tarjeta(
                          colorIcono: color,
                          iconoWidget: MiniCalendario(fecha: evt.inicio, colorCalendario: color),
                          titulo: evt.descripcion,
                          subtituloWidget: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "🕒 De ${evt.horaInicioTexto} a ${evt.horaFinTexto}",
                                style: const TextStyle(color: Colors.black87, fontSize: 13),
                              ),
                              Text(
                                "📍 ${evt.nombreUbicacionEvento ?? 'No definido'}",
                                style: const TextStyle(color: Colors.black54, fontSize: 13),
                              ),
                            ],
                          ),
                          onTap: () => mostrarOpcionesEvento(context, evt),
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
