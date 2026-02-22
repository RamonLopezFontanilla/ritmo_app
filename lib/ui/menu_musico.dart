import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ritmo_app/consultas_bd/asistencias.dart';
import 'package:ritmo_app/consultas_bd/bandas.dart';
import 'package:ritmo_app/consultas_bd/eventos.dart';
import 'package:ritmo_app/consultas_bd/login.dart';
import 'package:ritmo_app/consultas_bd/musicos.dart';
import 'package:ritmo_app/consultas_bd/temporada.dart';
import 'package:ritmo_app/modelos/banda.dart';
import 'package:ritmo_app/modelos/evento_a_fichar.dart';
import 'package:ritmo_app/modelos/temporada.dart';
import 'package:ritmo_app/modelos/temporadas_selector.dart';
import 'package:ritmo_app/tutoriales/menu_musico.dart';
import 'package:ritmo_app/ui/lista_asistencias.dart';
import 'package:ritmo_app/ui/datos_musico.dart';
import 'package:ritmo_app/ui/datos_liquidacion_musico.dart';
import 'package:ritmo_app/ui/lista_eventos.dart';
import 'package:ritmo_app/ui/lista_partituras.dart';
import 'package:ritmo_app/ui/login.dart';
import 'package:ritmo_app/utiles/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ****************************************************************
/// Página principal del músico.
///
/// Permite:
/// - Visualizar datos personales del músico.
/// - Ver novedades publicadas por la banda.
/// - Seleccionar temporada activa.
/// - Consultar eventos, asistencias, partituras y liquidaciones.
/// - Fichar asistencia a un evento si está activo.
/// - Ejecutar tutorial guiado la primera vez.
/// - Cerrar sesión.
///
/// Es un [StatefulWidget] porque:
/// - Gestiona múltiples estados dinámicos.
/// - Maneja carga de datos asíncrona.
/// - Controla temporizador periódico.
/// - Administra fichaje en tiempo real.
/// - Gestiona temporada seleccionada.
/// ****************************************************************
class PaginaMenuMusico extends StatefulWidget {
  final String bandaId;
  final String musicoId;

  const PaginaMenuMusico({super.key, required this.bandaId, required this.musicoId});

  @override
  State<PaginaMenuMusico> createState() => EstadoPaginaMenuMusico();
}

/// ****************************************************************
/// Estado de la página principal del músico.
///
/// Responsabilidades:
/// - Cargar datos del músico y banda.
/// - Cargar temporadas disponibles.
/// - Cargar novedades periódicamente.
/// - Gestionar evento pendiente de fichaje.
/// - Validar permisos de ubicación.
/// - Registrar fichaje.
/// - Gestionar tutorial inicial.
/// - Construir interfaz principal.
/// ****************************************************************
class EstadoPaginaMenuMusico extends State<PaginaMenuMusico> {
  // DATOS DEL MÚSICO
  String nombreMusico = "";
  String nombreMusicoCorto = "";
  String nombreInstrumento = "";
  String? nombreCategoria;
  String nombreBanda = "";
  String nombreBandaCorto = "";
  bool cargando = true;
  Timer? timer;
  String novedadesTexto = "Cargando novedades...";
  String? iconoInstrumento;
  Banda? banda;

  // TEMPORADAS Y EVENTOS
  String temporadaSeleccionadaId = "";
  List<Temporada> temporadas = [];
  EventoAFichar? eventoAFichar;

  bool yaFichado = false;

  // Keys del tutorial (cada key identifica un widget a resaltar para explicar su función)
  final GlobalKey keyMenu = GlobalKey();
  final GlobalKey keyTemporada = GlobalKey();
  final GlobalKey keyNovedades = GlobalKey();
  final GlobalKey keyBotonFichaje = GlobalKey();
  final GlobalKey keyEventos = GlobalKey();
  final GlobalKey keyAsistencias = GlobalKey();
  final GlobalKey keyPartituras = GlobalKey();
  final GlobalKey keyLiquidacion = GlobalKey();

  /// ***********************************************
  /// Inicialización
  ///
  /// - Carga datos del músico.
  /// - Carga novedades.
  /// - Comprueba si debe mostrarse el tutorial.
  /// - Inicia temporizador periódico (cada 30s).
  ///************************************************
  @override
  void initState() {
    super.initState();
    iniciarPantalla();
  }

  Future<void> iniciarPantalla() async {
    await cargarDatosMusico();
    await cargarNovedades();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await comprobarPrimeraVezParaTutorial();
    });

    timer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!mounted) return;
      await cargarNovedades();
      await cargarEventoAFichar();
    });
  }

  /// ***********************************************
  /// Liberación de memoria
  ///
  /// - Cancela temporizador activo.
  /// - Evita fugas de memoria.
  ///************************************************
  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  /// ************************************************
  /// Cargar novedades de la banda
  ///
  /// - Consulta base de datos.
  /// - Actualiza texto mostrado.
  /// ************************************************
  Future<void> cargarNovedades() async {
    final texto = await ConsultasBandasBD.obtenerNovedades(widget.bandaId);

    if (!mounted) return;

    setState(() {
      novedadesTexto = texto;
    });
  }

  /// ************************************************
  /// Cargar datos del músico y banda
  ///
  /// - Obtiene datos del músico.
  /// - Obtiene datos de la banda.
  /// - Calcula versiones abreviadas.
  /// - Carga temporadas asociadas.
  /// ************************************************
  Future<void> cargarDatosMusico() async {
    try {
      final datos = await ConsultasMusicosBD.obtenerDatosMusicoParaMenu(
        bandaId: widget.bandaId,
        musicoId: widget.musicoId,
      );

      final bandaDoc = await ConsultasBandasBD.obtenerDatosBanda(widget.bandaId);

      Banda? bandaTmp;
      if (bandaDoc != null && bandaDoc.exists) {
        bandaTmp = Banda.fromMap(bandaDoc.id, bandaDoc.data() as Map<String, dynamic>);
      }

      // Asignamos al estado
      setState(() {
        banda = bandaTmp;
        nombreBanda = banda?.nombre ?? 'Sin banda asignada';
        nombreBandaCorto = nombreBanda.length > 36 ? '${nombreBanda.substring(0, 36)}...' : nombreBanda;

        iconoInstrumento = datos['iconoInstrumento'];
        nombreMusico = datos['nombreMusico'] ?? '';
        nombreMusicoCorto = nombreMusico.length > 40 ? '${nombreMusico.substring(0, 40)}...' : nombreMusico;

        nombreInstrumento = datos['nombreInstrumento'] ?? '';
        nombreCategoria = datos['nombreCategoria'] ?? '';
        cargando = false;
      });

      // Cargar temporadas ahora que banda ya no es null
      await cargarTemporadas();
    } catch (e) {
      setState(() {
        cargando = false;
        banda = null;
      });
      if (!mounted) return;
      context.mostrarSnack("Error al cargar datos: $e", esCorrecto: false);
    }
  }

  /// ************************************************
  /// Cargar temporadas de la banda
  ///
  /// - Obtiene lista de temporadas.
  /// - Marca temporada actual.
  /// - Carga evento a fichar.
  /// ************************************************
  Future<void> cargarTemporadas() async {
    if (banda == null) return;

    try {
      final resultado = await ConsultasTemporadasBD.obtenerTemporadasConActual(banda!.id);

      if (!mounted) return;

      setState(() {
        temporadas = resultado.lista;
        temporadaSeleccionadaId = resultado.actual?.id ?? "";
      });

      await cargarEventoAFichar();
    } catch (e) {
      if (!mounted) return;
      context.mostrarSnack("Error al cargar temporadas: $e", esCorrecto: false);
    }
  }

  /// ************************************************
  /// Comprobar si es la primera vez (tutorial)
  ///
  /// - Consulta SharedPreferences.
  /// - Muestra tutorial si no ha sido visto.
  /// ************************************************
  Future<void> comprobarPrimeraVezParaTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final visto = prefs.getBool('tutorial_musico_visto') ?? false;

    if (!visto) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        mostrarTutorial();
      });
      await prefs.setBool('tutorial_musico_visto', true);
    }
  }

  /// ************************************************
  /// Mostrar tutorial guiado
  /// ************************************************
  void mostrarTutorial() {
    TutorialMenuMusico(
      context: context,
      keyMenu: keyMenu,
      keyTemporada: keyTemporada,
      keyNovedades: keyNovedades,
      keyBotonFichaje: keyBotonFichaje,
      keyEventos: keyEventos,
      keyAsistencias: keyAsistencias,
      keyPartituras: keyPartituras,
      keyLiquidacion: keyLiquidacion,
    ).mostrar();
  }

  /// ***********************************************
  /// Manejo del menú desplegable AppBar
  /// ***********************************************
  void handleMenuSelection(String value) async {
    // --------------------------------------
    //   Acción al elegir datos del músico
    // --------------------------------------
    if (value == 'datos') {
      if (!mounted) return;
      final resultado = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaginaDatosMusico(musicoId: widget.musicoId, bandaId: widget.bandaId, esAdmin: false),
        ),
      );

      if (resultado == true) {
        // Hubo cambios, recargar datos del músico
        await cargarDatosMusico();
      }

      // --------------------------------------
      //    Acción al elegir ver tutorial
      // --------------------------------------
    } else if (value == 'tutorial') {
      mostrarTutorial();

      // -----------------------------------
      //   Acción al elegir cerrar sesión
      // -----------------------------------
    } else if (value == 'cerrar') {
      final confirmar = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),

            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.logout, size: 48, color: Colors.red.shade600),
                const SizedBox(height: 12),

                const Text(
                  "Cerrar sesión",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 12),

                const Text("¿Estás seguro de que quieres cerrar la sesión?", textAlign: TextAlign.center),
              ],
            ),

            actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            actions: [
              SizedBox(
                height: 40,
                child: TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
              ),
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Cerrar sesión"),
                ),
              ),
            ],
          );
        },
      );

      if (confirmar == true) {
        await ConsultasLoginBD.cerrarSesion();
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PaginaLogin()));
      }
    }
  }

  /// ***********************************************
  /// Mostrar diálogo de novedades (solo lectura)
  /// ***********************************************
  void mostrarDialogoNovedadesMusico() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            content: SingleChildScrollView(
              child: DialogoBase(
                icono: Icons.campaign_outlined,
                titulo: "Novedades",
                children: [
                  Center(
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.9, // 90% del ancho de pantalla
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 200),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(6),
                          color: const Color.fromARGB(255, 245, 230, 18),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            novedadesTexto,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 0, 0, 0)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              SizedBox(
                height: 40,
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    backgroundColor: Colors.indigo.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Cerrar", style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// ***********************************************
  /// Cargar evento a fichar
  /// ***********************************************
  Future<void> cargarEventoAFichar() async {
    if (temporadaSeleccionadaId.isEmpty) return;

    try {
      final evento = await ConsultasEventosBD.obtenerEventoAFichar(widget.bandaId, temporadaSeleccionadaId);

      if (evento == null) {
        if (!mounted) return;
        setState(() {
          eventoAFichar = null;
          yaFichado = false;
        });
        return;
      }

      final fichado = await ConsultasEventosBD.yaFichado(widget.bandaId, widget.musicoId, evento.id);

      if (!mounted) return;

      setState(() {
        eventoAFichar = evento;
        yaFichado = fichado;
        cargando = false;
      });
    } catch (e) {
      debugPrint("Error cargarEventoAFichar: $e");
    }
  }

  bool fichando = false;

  /// ************************************************
  /// Comprobar permisos de ubicación
  ///
  /// - Verifica GPS activo.
  /// - Solicita permisos si es necesario.
  /// ************************************************
  Future<bool> comprobarPermisosUbicacion() async {
    bool servicio = await Geolocator.isLocationServiceEnabled();
    if (!servicio) {
      context.mostrarSnack("Activa el GPS para poder fichar", esCorrecto: false);
      return false;
    }

    LocationPermission permiso = await Geolocator.checkPermission();

    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }

    if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) {
      context.mostrarSnack("Permiso de ubicación denegado", esCorrecto: false);
      return false;
    }

    return true;
  }

  /// ************************************************
  /// Validar temporada seleccionada
  ///
  /// - Se usa antes de navegar a consultas.
  /// ************************************************
  bool validarTemporadaSeleccionada() {
    if (temporadaSeleccionadaId.isEmpty) {
      context.mostrarSnack("Debes seleccionar una temporada", esCorrecto: false);
      return false;
    }
    return true;
  }

  /// ************************************************
  /// Fichar evento
  ///
  /// Flujo:
  /// - Verifica que haya evento.
  /// - Verifica que no esté ya fichado.
  /// - Comprueba permisos GPS.
  /// - Valida distancia al evento.
  /// - Registra fichaje.
  /// ************************************************
  Future<void> ficharEvento() async {
    if (eventoAFichar == null) return;
    if (yaFichado) {
      context.mostrarSnack("Ya has fichado este evento", esCorrecto: false);
      return;
    }

    if (fichando) return;
    setState(() => fichando = true);

    final permisosOk = await comprobarPermisosUbicacion();
    if (!permisosOk) {
      fichando = false;
      return;
    }

    try {
      final permitido = await ConsultasEventosBD.puedeFicharPorDistancia(
        bandaId: widget.bandaId,
        eventoId: eventoAFichar!.id,
      );

      if (!permitido) {
        if (!mounted) return;
        context.mostrarSnack("Estás demasiado lejos del lugar del evento", esCorrecto: false);
        fichando = false;
        return;
      }

      await ConsultasAsistenciasBD.registrarFichaje(
        temporadaSeleccionadaId: temporadaSeleccionadaId,
        bandaId: widget.bandaId,
        eventoId: eventoAFichar!.id,
        musicoId: widget.musicoId,
      );

      if (!mounted) return;
      setState(() {
        yaFichado = true;
      });
      if (!mounted) return;
      context.mostrarSnack("Fichaje registrado con éxito", esCorrecto: true);
    } catch (e) {
      if (!mounted) return;
      context.mostrarSnack("Error al fichar el evento", esCorrecto: false);
    } finally {
      if (mounted) {
        setState(() => fichando = false);
      }
    }
  }

  /// ************************************************
  /// Contruir icono
  /// ************************************************
  Widget construirIcono(String? ruta) {
    if (ruta == null || ruta.isEmpty) {
      return Image.asset("assets/logomin.png", height: 50);
    }

    if (ruta.startsWith("http")) {
      return Image.network(
        ruta,
        height: 50,
        errorBuilder: (_, __, ___) => Image.asset("assets/logomin.png", height: 50),
      );
    }

    return Image.asset(ruta, height: 50, errorBuilder: (_, __, ___) => Image.asset("assets/logomin.png", height: 50));
  }

  /// ***********************************************
  ///              --- Construcción UI ---
  ///
  /// Estructura:
  /// - AppBar con selector de temporada.
  /// - Menú desplegable.
  /// - Cabecera músico.
  /// - Novedades.
  /// - Tarjeta fichaje.
  /// - Grid de consultas.
  /// ***********************************************
  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();
    final enHora = eventoAFichar?.estaActivo ?? false;

    String textoFichar;

    if (eventoAFichar == null) {
      textoFichar = "Sin evento";
    } else if (yaFichado) {
      textoFichar = "✅ Ya fichado";
    } else if (enHora) {
      textoFichar = "⏰ Ficha ahora";
    } else if (eventoAFichar!.inicio.isAfter(ahora)) {
      final diff = eventoAFichar!.inicio.difference(ahora);

      if (diff.inMinutes <= 60) {
        textoFichar = "⏳ Empieza en ${diff.inMinutes} min.";
      } else {
        textoFichar = "Evento próximo";
      }
    } else {
      textoFichar = "⛔ Evento finalizado";
    }
    return Scaffold(
      // ----------------------------
      //         BARRA SUPERIOR
      // ----------------------------
      appBar: AppBar(
        // ------------------------------
        //   Desplegable de temporadas
        // ------------------------------
        title: Row(
          children: [
            //const SizedBox(width: 10),
            //const Text("Temporada:", style: TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            SelectorTemporada(
              key: keyTemporada,
              temporadas: temporadas,
              temporadaSeleccionadaId: temporadaSeleccionadaId,
              onChanged: (id) async {
                if (id == null) return;

                // Si es la misma temporada, no hacemos nada
                if (id == temporadaSeleccionadaId) return;

                setState(() {
                  temporadaSeleccionadaId = id;
                  eventoAFichar = null;
                  yaFichado = false;
                });

                await cargarEventoAFichar();
              },
            ),
          ],
        ),
        // ----------------------------
        //     Menú desplegable
        // ----------------------------
        actions: [
          PopupMenuButton<String>(
            onSelected: handleMenuSelection,
            key: keyMenu,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'datos', child: Text('Mis Datos')),
              PopupMenuItem(value: 'tutorial', child: Text('Ver tutorial')),
              PopupMenuItem(value: 'cerrar', child: Text('Cerrar sesión')),
            ],
          ),
        ],
      ),

      // ----------------------------
      //       CUERPO PRINCIPAL
      // ----------------------------
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              child: Column(
                children: [
                  // Nombre de la banda en recuadro
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(color: const Color.fromARGB(255, 243, 242, 243)),
                    child: Text(
                      nombreBandaCorto,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, fontFamily: "Arial", color: Colors.black),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ---------------------------------------
                  //       Cabecera de usuario con icono
                  // ---------------------------------------
                  construirIcono(iconoInstrumento),
                  const SizedBox(height: 10),

                  // Nombre músico
                  Text(nombreMusicoCorto, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  // Instrumento y categoría
                  Text(
                    nombreCategoria != null ? "$nombreInstrumento - $nombreCategoria" : nombreInstrumento,
                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                  ),

                  const SizedBox(height: 15),

                  // ----------------------------
                  //       Apartado Novedades
                  // ----------------------------
                  // Novedades
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text("📢 Novedades:", style: const TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(height: 5),

                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: mostrarDialogoNovedadesMusico,

                      child: Container(
                        width: double.infinity,
                        height: 90,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 245, 230, 18),
                          borderRadius: BorderRadius.circular(0),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            key: keyNovedades,
                            novedadesTexto.length > 100
                                ? '${novedadesTexto.substring(0, novedadesTexto.length.clamp(0, 100))}...'
                                : novedadesTexto,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 0, 0, 0)),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("✍️ Fichar:", style: const TextStyle(fontSize: 12)),
                      Text(textoFichar, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),

                  // ----------------------------
                  //      Tarjeta fichar
                  // ----------------------------
                  tarjetaFichar(
                    key: keyBotonFichaje,
                    fecha: eventoAFichar?.inicio ?? DateTime.now(),
                    titulo: eventoAFichar?.descripcion ?? "Sin evento disponible",
                    horario: eventoAFichar != null
                        ? "🕒 De ${eventoAFichar!.horaInicioTexto} h. "
                              "a ${eventoAFichar!.horaFinTexto} h."
                        : "",
                    lugar: eventoAFichar?.ubicacionNombre != null ? "📍 ${eventoAFichar!.ubicacionNombre}" : "",
                    onTap: (enHora && !yaFichado && !fichando) ? () => ficharEvento() : null,
                    fondo: (enHora && !yaFichado)
                        ? const Color.fromARGB(255, 62, 133, 66)
                        : const Color.fromARGB(255, 201, 200, 200),
                  ),
                  const SizedBox(height: 15),

                  // ----------------------------
                  //      Apartado Consultas
                  // ----------------------------
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text("📝 Consultar:", style: const TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(height: 5),
                  // Grid de opciones
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 1.6,
                    children: [
                      BotonAccion(
                        icon: Icons.event,
                        label: "Eventos",
                        widgetKey: keyEventos,
                        onTap: () {
                          if (!validarTemporadaSeleccionada()) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaginaListaEventos(
                                esAdmin: false,
                                uid: widget.musicoId,
                                bandaId: widget.bandaId,
                                temporadaSeleccionadaId: temporadaSeleccionadaId,
                              ),
                            ),
                          );
                        },
                      ),
                      BotonAccion(
                        icon: Icons.check_circle,
                        label: "Asistencias",
                        widgetKey: keyAsistencias,
                        onTap: () {
                          if (!validarTemporadaSeleccionada()) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaginaAsistencias(
                                bandaId: widget.bandaId,
                                musicoId: widget.musicoId,
                                temporadaSeleccionadaId: temporadaSeleccionadaId,
                                nombreMusico: nombreMusico,
                                nombreBanda: nombreBanda,
                              ),
                            ),
                          );
                        },
                      ),
                      BotonAccion(
                        icon: Icons.music_note,
                        label: "Partituras",
                        widgetKey: keyPartituras,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaginaListaPartituras(
                                musicoId: widget.musicoId,
                                esAdmin: false,
                                bandaId: widget.bandaId,
                              ),
                            ),
                          );
                        },
                      ),
                      BotonAccion(
                        icon: Icons.euro,
                        label: "Liquidación",
                        widgetKey: keyLiquidacion,
                        onTap: () {
                          if (!validarTemporadaSeleccionada()) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaginaLiquidacionMusico(
                                esAdmin: false,
                                bandaId: widget.bandaId,
                                temporadaSeleccionadaId: temporadaSeleccionadaId,
                                musicoId: widget.musicoId,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
