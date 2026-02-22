import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:ritmo_app/consultas_bd/eventos.dart';
import 'package:ritmo_app/consultas_bd/temporada.dart';
import 'package:ritmo_app/consultas_bd/ubicaciones.dart';
import 'package:ritmo_app/modelos/evento.dart';
import 'package:ritmo_app/modelos/ubicacion.dart';
import 'package:ritmo_app/ui/lista_ubicaciones.dart';
import 'package:ritmo_app/utiles/widgets.dart';

/// ********************************************************
/// Página de datos de un evento.
///
/// Permite:
/// - Crear un nuevo evento o editar uno existente.
/// - Seleccionar tipo de evento (Ensayo, Actuación, Semana Santa)
/// - Ingresar descripción, fecha y hora de inicio y fin
/// - Seleccionar ubicación del evento y lugar de cita
///
/// Es un [StatefulWidget] porque mantiene estado:
/// - Campos de texto
/// - Fechas y horas seleccionadas
/// - Ubicaciones seleccionadas
/// - Estado de carga
/// ********************************************************
class PaginaDatosEvento extends StatefulWidget {
  final String bandaId;
  final String temporada;
  final String? eventoId;

  const PaginaDatosEvento({super.key, required this.bandaId, required this.temporada, this.eventoId});

  @override
  State<PaginaDatosEvento> createState() => EstadoPaginaDatosEvento();
}

/// ********************************************************
/// Estado de la página de datos de un evento.
///
/// Contiene toda la lógica:
/// - Cargar datos de la temporada
/// - Cargar evento si se está editando
/// - Selección de fecha y hora
/// - Selección de ubicaciones
/// - Guardar evento
/// ********************************************************
class EstadoPaginaDatosEvento extends State<PaginaDatosEvento> {
  final controladorDescripcion = TextEditingController();
  final controladorLugarEvento = TextEditingController();
  final controladorLugarCita = TextEditingController();
  final controladorFechaInicio = TextEditingController();
  final controladorFechaFin = TextEditingController();
  final controladorHoraInicio = TextEditingController();
  final contrladorFechaFin = TextEditingController();
  final controladorHoraFin = TextEditingController();

  // Tipo de evento
  String tipo = 'Ensayo';

  // Fechas y horas
  DateTime? fechaInicio;
  DateTime? fechaFin;
  TimeOfDay? horaInicio;
  TimeOfDay? horaFin;

  // IDs de ubicaciones
  String? ubicacionEventoId;
  String? ubicacionCitaId;

  // Fechas de la temporada
  DateTime? temporadaInicio;
  DateTime? temporadaFin;

  // Indicador de carga
  bool cargando = false;

  /// ********************************************************
  /// Inicialización
  ///
  /// - Carga fechas de la temporada
  /// - Carga datos del evento si se está editando
  /// - Si es nuevo evento, pone descripción por defecto
  /// ********************************************************
  @override
  void initState() {
    super.initState();
    cargarTemporada();
    if (widget.eventoId != null) {
      cargarEvento();
    } else {
      controladorDescripcion.text = 'Ensayo semanal';
    }
  }

  /// ********************************************************
  /// Liberación de recursos
  ///
  /// - Importante liberar los controladores de texto para evitar fugas de memoria.
  /// ********************************************************
  @override
  void dispose() {
    controladorDescripcion.dispose();
    controladorLugarEvento.dispose();
    controladorLugarCita.dispose();
    controladorFechaInicio.dispose();
    controladorFechaFin.dispose();
    controladorHoraInicio.dispose();
    contrladorFechaFin.dispose();
    controladorHoraFin.dispose();
    super.dispose();
  }

  /// ********************************************************
  /// Cargar fechas de la temporada
  ///
  /// - Obtiene la temporada de la base de datos
  /// - Guarda fecha de inicio y fin para validación de datepicker
  /// ********************************************************
  Future<void> cargarTemporada() async {
    final temporadas = await ConsultasTemporadasBD.obtenerTemporadas(widget.bandaId);
    final temp = temporadas.firstWhereOrNull((t) => t.id == widget.temporada);
    if (temp == null) return;

    setState(() {
      temporadaInicio = temp.fechaInicio;
      temporadaFin = temp.fechaFin;
    });
  }

  /// ********************************************************
  /// Cargar datos del evento
  ///
  /// - Obtiene evento de la base de datos
  /// - Carga nombres de ubicaciones
  /// - Llena controladores de texto y fechas/horas
  /// ********************************************************
  Future<void> cargarEvento() async {
    setState(() => cargando = true);

    final eventos = await ConsultasEventosBD.obtenerEventosDeTemporada(widget.bandaId, widget.temporada);
    final evento = eventos.firstWhere(
      (e) => e.id == widget.eventoId,
      orElse: () => Evento(
        id: '',
        tipo: 'Ensayo',
        descripcion: '',
        ubicacionEventoId: '',
        ubicacionCitaId: '',
        inicio: DateTime.now(),
        fin: DateTime.now(),
        horaInicioTexto: '',
        horaFinTexto: '',
        temporada: widget.temporada,
      ),
    );

    // Mostrar el nombre de la ubicación
    evento.nombreUbicacionEvento = await ConsultasUbicacionesBD.obtenerNombreUbicacion(
      widget.bandaId,
      evento.ubicacionEventoId,
    );
    evento.nombreUbicacionCita = await ConsultasUbicacionesBD.obtenerNombreUbicacion(
      widget.bandaId,
      evento.ubicacionCitaId,
    );

    setState(() {
      tipo = evento.tipo;
      controladorDescripcion.text = evento.descripcion;
      ubicacionEventoId = evento.ubicacionEventoId;
      ubicacionCitaId = evento.ubicacionCitaId;

      fechaInicio = evento.inicio;
      fechaFin = evento.fin;
      horaInicio = TimeOfDay.fromDateTime(evento.inicio);
      horaFin = TimeOfDay.fromDateTime(evento.fin);

      controladorFechaInicio.text = formatearFecha(fechaInicio!);
      controladorFechaFin.text = formatearFecha(fechaFin!);
      controladorHoraInicio.text = evento.horaInicioTexto;
      controladorHoraFin.text = evento.horaFinTexto;
      controladorLugarEvento.text = evento.nombreUbicacionEvento.toString();
      controladorLugarCita.text = evento.nombreUbicacionCita.toString();

      cargando = false;
    });
  }

  /// ********************************************************
  /// Selector de fecha
  /// ********************************************************
  Future<DateTime?> seleccionarFecha(DateTime? inicial) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: inicial ?? now,
      firstDate: temporadaInicio ?? DateTime(now.year - 1),
      lastDate: temporadaFin ?? DateTime(now.year + 1),
    );
  }

  /// ********************************************************
  /// Selector de hora
  /// ********************************************************
  Future<TimeOfDay?> seleccionarHora(TimeOfDay? inicial) {
    return showTimePicker(context: context, initialTime: inicial ?? TimeOfDay.now());
  }

  String formatearFecha(DateTime date) =>
      "${date.day.toString().padLeft(2, '0')}/"
      "${date.month.toString().padLeft(2, '0')}/"
      "${date.year}";

  String formatearHora(TimeOfDay time) =>
      "${time.hour.toString().padLeft(2, '0')}:"
      "${time.minute.toString().padLeft(2, '0')}";

  /// ********************************************************
  /// Guardar evento
  ///
  /// - Valida fechas y horas
  /// - Construye objeto Evento
  /// - Guarda en la base de datos
  /// - Devuelve el evento a la pantalla anterior
  /// ********************************************************
  Future<void> guardarDatosEvento() async {
    if (fechaInicio == null || horaInicio == null || fechaFin == null || horaFin == null) {
      context.mostrarSnack('Selecciona fecha y hora de inicio y fin', esCorrecto: false);
      return;
    }

    final inicio = DateTime(
      fechaInicio!.year,
      fechaInicio!.month,
      fechaInicio!.day,
      horaInicio!.hour,
      horaInicio!.minute,
    );
    final fin = DateTime(fechaFin!.year, fechaFin!.month, fechaFin!.day, horaFin!.hour, horaFin!.minute);

    final evento = Evento(
      id: widget.eventoId ?? '',
      tipo: tipo,
      descripcion: controladorDescripcion.text.trim(),
      ubicacionEventoId: ubicacionEventoId ?? '',
      ubicacionCitaId: ubicacionCitaId ?? '',
      inicio: inicio,
      fin: fin,
      horaInicioTexto: controladorHoraInicio.text,
      horaFinTexto: controladorHoraFin.text,
      temporada: widget.temporada,
    );

    await ConsultasEventosBD.guardarEvento(evento, bandaId: widget.bandaId);

    if (!mounted) return;

    // Devuelve el evento creado a la pantalla anterior
    Navigator.pop(context, evento);
  }

  /// ********************************************************
  /// Construir UI
  ///
  /// - Campos de texto para descripción, fechas, horas y ubicaciones
  /// - Dropdown para tipo de evento
  /// - Botón guardar en bottomNavigationBar
  /// ********************************************************
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ----------------------------
      //         BARRA SUPERIOR
      // ----------------------------
      appBar: AppBar(title: Text(widget.eventoId != null ? 'Editar evento' : 'Nuevo evento')),

      // ----------------------------
      //       CUERPO PRINCIPAL
      // ----------------------------
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // TIPO
                  AppDropdown<String>(
                    label: 'Tipo',
                    value: tipo,
                    items: const [
                      DropdownMenuItem(value: 'Ensayo', child: Text('Ensayo')),
                      DropdownMenuItem(value: 'Actuación', child: Text('Actuación')),
                      DropdownMenuItem(value: 'Semana Santa', child: Text('Semana Santa')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        tipo = value!;
                        if (tipo == 'Ensayo' && controladorDescripcion.text.isEmpty) {
                          controladorDescripcion.text = 'Ensayo semanal';
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 8),

                  // DESCRIPCIÓN
                  AppInput(label: 'Descripción', controller: controladorDescripcion),
                  const SizedBox(height: 8),

                  // FECHA HORA INICIO
                  Row(
                    children: [
                      Expanded(
                        child: AppInput(
                          controller: controladorFechaInicio,
                          readOnly: true,
                          label: 'Fecha inicio',
                          suffixIcon: Icon(Icons.calendar_today),
                          onTap: () async {
                            final fecha = await seleccionarFecha(fechaInicio);
                            if (fecha == null) return;
                            setState(() {
                              fechaInicio = fecha;
                              controladorFechaInicio.text = formatearFecha(fecha);

                              // Si fechaFin es nula o anterior a la fechaInicio, la ponemos igual
                              if (fechaFin == null || fechaFin!.isBefore(fecha)) {
                                fechaFin = fecha;
                                controladorFechaFin.text = formatearFecha(fecha);
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppInput(
                          controller: controladorHoraInicio,
                          readOnly: true,
                          label: 'Hora inicio',
                          suffixIcon: Icon(Icons.access_time),
                          onTap: () async {
                            final hora = await seleccionarHora(horaInicio);
                            if (hora == null) return;
                            setState(() {
                              horaInicio = hora;
                              controladorHoraInicio.text = formatearHora(hora);
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // FECHA HORA FIN
                  Row(
                    children: [
                      Expanded(
                        child: AppInput(
                          label: 'Fecha fin',
                          controller: controladorFechaFin,
                          readOnly: true,
                          suffixIcon: Icon(Icons.calendar_today),
                          onTap: () async {
                            final fecha = await seleccionarFecha(fechaFin ?? fechaInicio);
                            if (fecha == null) return;
                            setState(() {
                              fechaFin = fecha;
                              controladorFechaFin.text = formatearFecha(fecha);
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppInput(
                          label: 'Hora fin',
                          controller: controladorHoraFin,
                          readOnly: true,
                          suffixIcon: Icon(Icons.access_time),
                          onTap: () async {
                            final hora = await seleccionarHora(horaFin ?? horaInicio);
                            if (hora == null) return;
                            setState(() {
                              horaFin = hora;
                              controladorHoraFin.text = formatearHora(hora);
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // LUGAR DEL EVENTO
                  AppInput(
                    label: 'Lugar del evento',
                    controller: controladorLugarEvento,
                    readOnly: true,
                    suffixIcon: const Icon(Icons.place_outlined),
                    onTap: () async {
                      final Ubicacion? ubicSeleccionada = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PaginaListaUbicaciones(bandaId: widget.bandaId, seleccionar: true),
                        ),
                      );

                      if (ubicSeleccionada != null) {
                        setState(() {
                          // Actualiza campo Lugar del Evento
                          controladorLugarEvento.text = ubicSeleccionada.nombre;

                          // Copiar automáticamente a cita si es necesario
                          controladorLugarCita.text = ubicSeleccionada.nombre;

                          // Guardar IDs para Firestore
                          ubicacionEventoId = ubicSeleccionada.id;
                          ubicacionCitaId = ubicSeleccionada.id;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),

                  // LUGAR DE LA CITA
                  AppInput(
                    label: 'Lugar de la cita',
                    controller: controladorLugarCita,
                    readOnly: true,
                    suffixIcon: Icon(Icons.place_outlined),
                    onTap: () async {
                      final Ubicacion? ubicSeleccionada = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PaginaListaUbicaciones(bandaId: widget.bandaId, seleccionar: true),
                        ),
                      );

                      if (ubicSeleccionada != null) {
                        setState(() {
                          controladorLugarCita.text = ubicSeleccionada.nombre;

                          // Guardar IDs para Firestore
                          ubicacionCitaId = ubicSeleccionada.id;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),

      // ----------------------------
      //       BOTÓN GUARDAR
      // ----------------------------
      bottomNavigationBar: BotonGuardar(enabled: !cargando, onPressed: guardarDatosEvento),
    );
  }
}
