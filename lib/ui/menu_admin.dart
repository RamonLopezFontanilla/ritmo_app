import 'package:flutter/material.dart';
import 'package:ritmo_app/consultas_bd/administradores.dart';
import 'package:ritmo_app/consultas_bd/bandas.dart';
import 'package:ritmo_app/consultas_bd/login.dart';
import 'package:ritmo_app/consultas_bd/temporada.dart';
import 'package:ritmo_app/modelos/temporada.dart';
import 'package:ritmo_app/modelos/temporadas_selector.dart';
import 'package:ritmo_app/tutoriales/menu_admin.dart';
import 'package:ritmo_app/ui/datos_banda.dart';
import 'package:ritmo_app/ui/lista_liquidacion_admin.dart';
import 'package:ritmo_app/modelos/administrador.dart';
import 'package:ritmo_app/modelos/banda.dart';
import 'package:ritmo_app/ui/lista_eventos.dart';
import 'package:ritmo_app/ui/lista_temporadas.dart';
import 'package:ritmo_app/ui/login.dart';
import 'package:ritmo_app/ui/parametros_banda.dart';
import 'package:ritmo_app/ui/lista_instrumentos.dart';
import 'package:ritmo_app/ui/lista_ubicaciones.dart';
import 'package:ritmo_app/ui/lista_partituras.dart';
import 'package:ritmo_app/ui/lista_musicos.dart';
import 'package:ritmo_app/utiles/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ****************************************************************
/// Página principal del Administrador de la Banda
///
/// Permite al administrador:
/// - Ver y editar novedades de la banda
/// - Gestionar plantilla de músicos
/// - Consultar eventos y liquidaciones
/// - Acceder a archivo de instrumentos, partituras y ubicaciones
///
/// Es un [StatefulWidget] porque se mantiene estado:
/// - Datos de administrador y banda
/// - Temporadas disponibles y seleccionada
/// - Novedades
/// - Estado de carga
/// ****************************************************************
class PaginaMenuAdministrador extends StatefulWidget {
  final String bandaId;
  final String uid;

  const PaginaMenuAdministrador({super.key, required this.bandaId, required this.uid});

  @override
  State<PaginaMenuAdministrador> createState() => EstadoPaginaMenuAdministrador();
}

/// ****************************************************************
/// Estado de la página del administrador (Guarda todos los datos que cambian)
///
/// Contiene toda la lógica:
/// - Carga de datos de administrador y banda
/// - Manejo de novedades
/// - Gestión de temporadas
/// - Validación de selección de temporada
/// - Navegación a secciones de la banda
/// - Control del tutorial inicial
/// ****************************************************************
class EstadoPaginaMenuAdministrador extends State<PaginaMenuAdministrador> {
  Administrador? admin;
  Banda? banda;

  bool cargando = true;
  List<Temporada> temporadas = [];

  String temporadaSeleccionadaId = "";
  String mensajeNovedades = "";

  final TextEditingController novedadesController = TextEditingController();

  // Keys del tutorial (cada key identifica un widget a resaltar para explicar su función)
  final GlobalKey keyTemporada = GlobalKey();
  final GlobalKey keyNovedades = GlobalKey();
  final GlobalKey keyPlantilla = GlobalKey();
  final GlobalKey keyEventos = GlobalKey();
  final GlobalKey keyLiquidacion = GlobalKey();
  final GlobalKey keyInstrumentos = GlobalKey();
  final GlobalKey keyPartituras = GlobalKey();
  final GlobalKey keyUbicaciones = GlobalKey();
  final GlobalKey keyMenu = GlobalKey();

  /// ***********************************************
  /// Inicialización
  ///
  /// Carga datos de la banda y administrador al iniciar la pantalla.
  /// Comprueba si se debe mostrar el tutorial al usuario.
  ///************************************************
  @override
  void initState() {
    super.initState();
    iniciarPantalla();
  }

  Future<void> iniciarPantalla() async {
    await cargarDatos();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await comprobarPrimeraVezParaTutorial();
    });
  }

  /// ***********************************************
  /// Liberación de memoria
  ///
  /// Se libera el controlador de novedades para evitar fugas de memoria.
  ///************************************************
  @override
  void dispose() {
    novedadesController.dispose(); // Liberar controlador de texto en novedades
    super.dispose();
  }

  /// ******************************************************************
  /// Cargar datos de administrador, banda y temporada
  ///
  /// Obtiene de la base de datos:
  /// - Datos del administrador [ConsultasAdministradoresBD.obtenerAdministrador]
  /// - Datos de la banda [ConsultasBandasBD.obtenerDatosBanda]
  /// - Novedades de la banda [cargarTemporadas]
  /// - Temporadas disponibles y actual
  ///*******************************************************************
  Future<void> cargarDatos() async {
    try {
      // --- ADMINISTRADOR ---
      final adminTmp = await ConsultasAdministradoresBD.obtenerAdministrador(widget.uid);
      if (adminTmp == null) {
        setState(() {
          cargando = false;
          admin = null;
          banda = null;
        });
        return;
      }

      // --- BANDA ---
      final bandaDoc = await ConsultasBandasBD.obtenerDatosBanda(widget.bandaId);

      Banda? bandaTmp;

      if (bandaDoc != null && bandaDoc.exists) {
        bandaTmp = Banda.fromMap(bandaDoc.id, bandaDoc.data() as Map<String, dynamic>);
      }

      setState(() {
        admin = adminTmp;
        banda = bandaTmp;
        mensajeNovedades = bandaTmp?.novedades ?? '';
        cargando = false;
      });

      // --- TEMPORADAS ---
      await cargarTemporadas();
    } catch (e) {
      setState(() {
        cargando = false;
        admin = null;
        banda = null;
      });
      if (!mounted) return;
      context.mostrarSnack("Error al cargar datos: $e", esCorrecto: false);
    }
  }

  ///*******************************************************************
  /// Cargar temporadas de la banda
  ///
  /// Obtiene todas las temporadas de la banda y selecciona la actual [ConsultasTemporadasBD.obtenerTemporadasConActual]
  /// *******************************************************************
  Future<void> cargarTemporadas() async {
    if (banda == null) return;

    try {
      final resultado = await ConsultasTemporadasBD.obtenerTemporadasConActual(banda!.id);

      if (!mounted) return;

      setState(() {
        temporadas = resultado.lista;
        temporadaSeleccionadaId = resultado.actual?.id ?? "";
      });
    } catch (e) {
      if (!mounted) return;
      context.mostrarSnack("Error al cargar temporadas: $e", esCorrecto: false);
    }
  }

  /// *******************************************************************
  /// Comprobar si ya se ha visto el tutorial
  ///
  /// Usa SharedPreferences para mostrar el tutorial solo la primera vez
  /// *******************************************************************
  Future<void> comprobarPrimeraVezParaTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final visto = prefs.getBool('tutorial_admin_visto') ?? false;

    if (!visto) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        mostrarTutorial();
      });
      await prefs.setBool('tutorial_admin_visto', true);
    }
  }

  /// *******************************************************************
  /// Mostrar Tutorial
  ///
  /// Muestra paso a paso resaltando los elementos principales de la pantalla
  /// *******************************************************************
  void mostrarTutorial() {
    TutorialMenuAdministrador(
      context: context,
      keyMenu: keyMenu,
      keyTemporada: keyTemporada,
      keyNovedades: keyNovedades,
      keyPlantilla: keyPlantilla,
      keyEventos: keyEventos,
      keyLiquidacion: keyLiquidacion,
      keyInstrumentos: keyInstrumentos,
      keyPartituras: keyPartituras,
      keyUbicaciones: keyUbicaciones,
    ).mostrar();
  }

  /// *******************************************************************
  /// Validar que hay temporada seleccionada
  ///
  /// Se usa antes de acceder a eventos o liquidación
  /// *******************************************************************
  bool validarTemporadaSeleccionada() {
    if (temporadaSeleccionadaId.isEmpty) {
      context.mostrarSnack("Debes seleccionar una temporada", esCorrecto: false);
      return false;
    }
    return true;
  }

  /// *******************************************************************
  /// Manejo del menú desplegable AppBar
  ///
  /// Permite navegar a:
  /// - Datos de la banda [PaginaDatosBanda]
  /// - Parámetros [PaginaParametrosBanda]
  /// - Temporadas [cargarTemporadas]
  /// - Ver tutorial [cargarTutorial]
  /// - Cerrar sesión tras confirmar, usa [ConsultasLoginBD.cerrarSesion] y navega a [PaginaLogin]
  /// *******************************************************************
  void handleMenuDesplegable(String value) async {
    // --------------------------------------
    //   Acción al elegir datos de la banda
    // --------------------------------------
    if (value == 'datos') {
      if (!mounted) return;
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PaginaDatosBanda(bandaId: banda!.id)),
      );
      if (result == true) {
        cargarDatos();
      }
      // -------------------------------------------
      //  Acción al elegir parámetros de la banda
      // -------------------------------------------
    } else if (value == 'parametros') {
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => PaginaParametrosBanda(bandaId: banda!.id)));
      // -------------------------------------------
      //     Acción al elegir temporadas
      // -------------------------------------------
    } else if (value == 'temporadas') {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaginaListaTemporadas(
            bandaId: banda!.id,
            onTemporadaCreada: () async {
              await cargarTemporadas();
            },
          ),
        ),
      );
      // -------------------------------------------
      //     Acción al elegir ver tutorial
      // -------------------------------------------
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

  /// *******************************************************************
  /// Mostrar diálogo de novedades
  ///
  /// Permite editar el mensaje de novedades de la banda.
  /// Se almacena en BD mediante [ConsultasBandasBD.actualizarNovedades].
  /// *******************************************************************
  void mostrarDialogoNovedades() {
    if (banda?.id.isEmpty ?? true) {
      context.mostrarSnack("No hay banda asociada", esCorrecto: false);
      return;
    }

    novedadesController.text = mensajeNovedades;

    showDialog(
      context: context,
      barrierDismissible: false,
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
                titulo: "Editar novedades",
                children: [
                  TextField(
                    controller: novedadesController,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 0, 0, 0)),
                    maxLines: null,
                    minLines: 6,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color.fromARGB(255, 245, 230, 18),
                      hintText: "Escribe un mensaje para los músicos...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ],
              ),
            ),

            actions: [
              SizedBox(
                height: 40,
                child: TextButton(
                  onPressed: () {
                    novedadesController.clear();
                    setState(() {
                      mensajeNovedades = '';
                    });
                  },

                  child: const Text("Limpiar"),
                ),
              ),
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () async {
                    final nuevoMensaje = novedadesController.text.trim();
                    if (banda!.id.isEmpty) return;

                    await ConsultasBandasBD.actualizarNovedades(banda!.id, nuevoMensaje);

                    if (!mounted) return;

                    setState(() {
                      mensajeNovedades = nuevoMensaje;
                    });

                    Navigator.pop(context);
                  },
                  child: const Text("Guardar", style: TextStyle(fontWeight: FontWeight.w600)),
                ),
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
  /// - AppBar con selector de temporada y menú
  /// - Cuerpo con:
  ///   - Logo y nombre del administrador/banda
  ///   - Apartado Novedades
  ///   - Apartado Gestión (Plantilla, Eventos, Liquidación)
  ///   - Apartado Archivo (Instrumentos, Partituras, Ubicaciones)
  /// ********************************************************
  @override
  Widget build(BuildContext context) {
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
            const SizedBox(width: 8),
            SelectorTemporada(
              key: keyTemporada,
              temporadas: temporadas,
              temporadaSeleccionadaId: temporadaSeleccionadaId,
              onChanged: (id) {
                setState(() {
                  temporadaSeleccionadaId = id ?? "";
                });
              },
            ),
          ],
        ),

        // ----------------------------
        //     Menú desplegable
        // ----------------------------
        actions: [
          PopupMenuButton<String>(
            onSelected: handleMenuDesplegable,
            key: keyMenu,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'datos', child: Text('Datos de la Banda')),
              PopupMenuItem(value: 'temporadas', child: Text('Temporadas')),
              PopupMenuItem(value: 'parametros', child: Text('Parámetros')),
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
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 1),
                  // ---------------------------------------
                  //       Cabecera de usuario con logo
                  // ---------------------------------------
                  Image.asset("assets/logomin.png", height: 50),
                  const SizedBox(height: 10),
                  Text(
                    admin?.nombre ?? "Administrador",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    banda?.nombre ?? 'Sin banda asignada',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),

                  // ----------------------------
                  //       Apartado Novedades
                  // ----------------------------
                  const TituloApartado("💬  Novedades:"),
                  const SizedBox(height: 5),
                  InkWell(
                    onTap: mostrarDialogoNovedades,
                    child: Container(
                      height: 90,
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 245, 230, 18),
                        borderRadius: BorderRadius.circular(0),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        mensajeNovedades.isEmpty ? "Aquí aparecen novedades" : mensajeNovedades,
                        key: keyNovedades,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 0, 0, 0)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ----------------------------
                  //      Apartado Gestión
                  // ----------------------------
                  const TituloApartado("🎼  Gestión:"),
                  const SizedBox(height: 5),

                  // Fila 1: Plantilla y Eventos
                  Row(
                    children: [
                      // ----------------------------
                      //     Botón Plantilla
                      // ----------------------------
                      Expanded(
                        child: BotonAccion(
                          icon: Icons.group,
                          label: "Plantilla",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PaginaListaMusicos(
                                  esAdmin: true,
                                  bandaId: banda!.id,
                                  temporadaSeleccionadaId: temporadaSeleccionadaId,
                                  nombreBanda: banda?.nombre ?? 'Sin banda asignada',
                                ),
                              ),
                            );
                          },
                          widgetKey: keyPlantilla,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // ----------------------------
                      //     Botón Eventos
                      // ----------------------------
                      Expanded(
                        child: BotonAccion(
                          widgetKey: keyEventos,
                          icon: Icons.event,
                          label: "Eventos",
                          onTap: () {
                            if (!validarTemporadaSeleccionada()) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PaginaListaEventos(
                                  esAdmin: true,
                                  uid: widget.uid,
                                  bandaId: banda!.id,
                                  temporadaSeleccionadaId: temporadaSeleccionadaId,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Fila 2: Liquidación y hueco
                  Row(
                    children: [
                      // ----------------------------
                      //     Botón Liquidación
                      // ----------------------------
                      Expanded(
                        child: BotonAccion(
                          widgetKey: keyLiquidacion,
                          icon: Icons.euro,
                          label: "Liquidación",
                          onTap: () {
                            if (!validarTemporadaSeleccionada()) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PaginaLiquidacionAdmin(
                                  bandaId: banda!.id,
                                  temporadaSeleccionadaId: temporadaSeleccionadaId,
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(width: 10),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                  const SizedBox(height: 25),

                  // ----------------------------
                  //       Apartado Archivo
                  // ----------------------------
                  const TituloApartado("🗂️  Archivo:"),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      // ----------------------------
                      //     Botón instrumentos
                      // ----------------------------
                      Expanded(
                        child: BotonAccion(
                          widgetKey: keyInstrumentos,
                          icon: Icons.piano,
                          label: "Cuerdas",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => PaginaListaInstrumentos(bandaId: banda!.id)),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      // ----------------------------
                      //     Botón Partituras
                      // ----------------------------
                      Expanded(
                        child: BotonAccion(
                          widgetKey: keyPartituras,
                          icon: Icons.library_music,
                          label: "Partituras",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PaginaListaPartituras(musicoId: widget.uid, esAdmin: true, bandaId: banda!.id),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      // ----------------------------
                      //     Botón Ubicaciones
                      // ----------------------------
                      Expanded(
                        child: BotonAccion(
                          widgetKey: keyUbicaciones,
                          icon: Icons.location_on,
                          label: "Sitios",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PaginaListaUbicaciones(bandaId: banda!.id, seleccionar: false),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
