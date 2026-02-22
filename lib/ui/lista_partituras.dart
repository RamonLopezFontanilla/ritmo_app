import 'package:flutter/material.dart';
import 'package:ritmo_app/consultas_bd/generos.dart';
import 'package:ritmo_app/consultas_bd/musicos.dart';
import 'package:ritmo_app/modelos/otros_accesos_musico.dart';
import 'package:ritmo_app/modelos/partitura.dart';
import 'package:ritmo_app/ui/datos_partitura.dart';
import 'package:ritmo_app/consultas_bd/partituras.dart';
import 'package:ritmo_app/consultas_bd/instrumentos.dart';
import 'package:ritmo_app/utiles/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// ****************************************************************************************
/// Página de Lista de Partituras
///
/// Permite:
/// - Visualizar todas las partituras de la banda
/// - Buscar por título o género
/// - Filtrar por instrumento/categoría según accesos del músico
/// - Crear, editar y eliminar partituras (si esAdmin)
/// - Abrir la partitura correspondiente al instrumento del músico
/// - Seleccionar partitura cuando se usa en modo selección (repertorio)
///
/// Es un [StatefulWidget] porque:
/// - Gestiona estado de búsqueda
/// - Carga géneros y accesos async desde BD
/// - Controla selección dinámica de instrumento
/// - Escucha cambios en tiempo real mediante StreamBuilder
/// ****************************************************************************************
class PaginaListaPartituras extends StatefulWidget {
  final String bandaId;
  final bool esAdmin;
  final String musicoId;

  final bool modoSeleccion;

  const PaginaListaPartituras({
    super.key,
    required this.bandaId,
    required this.esAdmin,
    required this.musicoId,
    this.modoSeleccion = false,
  });

  @override
  State<PaginaListaPartituras> createState() => EstadoPaginaListaPartituras();
}

/// *******************************************************************************************
/// Estado de la página de Lista de Partituras
///
/// Contiene:
/// - Controlador del buscador
/// - Mapa de géneros (id → nombre)
/// - Accesos disponibles del músico
/// - Instrumento seleccionado
/// - Indicador de carga
///
/// Gestiona:
/// - Carga inicial de datos
/// - Construcción dinámica de accesos únicos
/// - Apertura de partituras según instrumento
/// - Menú contextual para acciones CRUD
/// *******************************************************************************************
class EstadoPaginaListaPartituras extends State<PaginaListaPartituras> {
  final TextEditingController controladorBusqueda = TextEditingController();

  String filtroBusqueda = "";

  Map<String, String> mapaGeneros = {};

  // Accesos del músico
  bool cargando = true;
  List<AccesoInstrumento> accesosDisponibles = [];
  AccesoInstrumento? accesoSeleccionado;

  /// ***********************************************
  /// Inicialización
  ///
  /// - Carga los géneros disponibles
  /// - Si el usuario no es admin y no está en modo selección,
  ///   carga los accesos del músico
  /// ***********************************************
  @override
  void initState() {
    super.initState();

    cargarGeneros();

    if (!widget.esAdmin && !widget.modoSeleccion) {
      cargarAccesosMusico();
    } else {
      cargando = false;
    }
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
  /// Cargar géneros desde BD
  ///
  /// Obtiene el mapa de géneros (id → nombre)
  /// para mostrar el nombre legible en la lista
  /// ***********************************************
  Future<void> cargarGeneros() async {
    final generos = await ConsultasGenerosBD.obtenerGeneros(widget.bandaId);

    if (!mounted) return;

    setState(() {
      mapaGeneros = generos;
    });
  }

  /// ***********************************************
  /// Cargar accesos del músico
  ///
  /// Flujo:
  /// 1. Obtener documento del músico
  /// 2. Construir lista de accesos:
  ///    - Instrumento principal
  ///    - Otros accesos configurados
  /// 3. Evitar duplicados (instrumento + categoría)
  /// 4. Ordenar alfabéticamente
  /// 5. Seleccionar acceso principal por defecto
  ///
  /// Solo se ejecuta si:
  /// - No es admin
  /// - No está en modo selección
  /// ***********************************************
  Future<void> cargarAccesosMusico() async {
    setState(() => cargando = true);

    try {
      // Traemos el documento del músico
      final docMusico = await ConsultasMusicosBD.obtenerDocumentoMusico(
        bandaId: widget.bandaId,
        musicoId: widget.musicoId,
      );

      if (docMusico == null) {
        setState(() {
          accesosDisponibles = [];
          accesoSeleccionado = null;
          cargando = false;
        });
        return;
      }

      // Construimos la lista de accesos (principal + otros)
      final List<Map<String, dynamic>> listaAccesos = [];
      final Set<String> accesosUnicos = {};

      void agregarAcceso({
        required String key,
        required String instrumentoId,
        String? categoriaId,
        required String nombre,
      }) {
        final identificador = '$instrumentoId-${categoriaId ?? ''}';

        if (!accesosUnicos.contains(identificador)) {
          accesosUnicos.add(identificador);

          listaAccesos.add({'key': key, 'instrumentoId': instrumentoId, 'categoriaId': categoriaId, 'nombre': nombre});
        }
      }

      // --- Acceso principal ---
      final String? instrumentoPrincipal = docMusico['instrumento'];
      final String? categoriaPrincipal = docMusico['categoria'];

      if (instrumentoPrincipal != null) {
        final nombre = await ConsultasInstrumentosBD.obtenerNombreInstrumentoCategoria(
          instrumentoPrincipal,
          categoriaPrincipal,
          widget.bandaId,
        );

        agregarAcceso(
          key: 'principal',
          instrumentoId: instrumentoPrincipal,
          categoriaId: categoriaPrincipal,
          nombre: nombre,
        );
      }

      // --- Otros accesos ---
      final List otrosAccesos = docMusico['otrosAccesos'] ?? [];
      for (int i = 0; i < otrosAccesos.length; i++) {
        final acceso = otrosAccesos[i];
        final String? instrumentoId = acceso['instrumento'];
        final String? categoriaId = acceso['categoria'];

        if (instrumentoId != null) {
          final nombre = await ConsultasInstrumentosBD.obtenerNombreInstrumentoCategoria(
            instrumentoId,
            categoriaId,
            widget.bandaId,
          );

          agregarAcceso(key: 'otros_$i', instrumentoId: instrumentoId, categoriaId: categoriaId, nombre: nombre);
        }
      }

      // Orden alfabético
      listaAccesos.sort((a, b) => (a['nombre'] ?? '').compareTo(b['nombre'] ?? ''));

      setState(() {
        accesosDisponibles = listaAccesos
            .map(
              (a) => AccesoInstrumento(
                key: a['key'],
                instrumentoId: a['instrumentoId'],
                categoriaId: a['categoriaId'],
                nombre: a['nombre'],
              ),
            )
            .toList();
        accesoSeleccionado = accesosDisponibles.firstWhere((a) => a.key == 'principal');
        cargando = false;
      });
    } catch (e) {
      debugPrint('Error cargando accesos: $e');
      setState(() {
        accesosDisponibles = [];
        accesoSeleccionado = null;
        cargando = false;
      });
    }
  }

  /// ***********************************************
  /// Abrir partitura según instrumento seleccionado
  ///
  /// - Obtiene instrumento y categoría seleccionados
  /// - Construye identificador concatenado
  /// - Solicita URI a BD
  /// - Abre archivo en aplicación externa
  ///
  /// Solo disponible para músicos (no admin)
  /// ***********************************************
  Future<void> abrirPartitura(Partitura part) async {
    if (widget.esAdmin || accesoSeleccionado == null) return;

    // Obtenemos los IDs reales
    final instrumentoId = accesoSeleccionado?.instrumentoId;
    final categoriaId = accesoSeleccionado?.categoriaId;

    if (instrumentoId == null) return;

    // Pasamos los IDs concatenados a ConsultasBD
    final instrumentoCat = '$instrumentoId|${categoriaId ?? ''}';

    final uri = await ConsultasPartiturasBD.obtenerUriPartitura(
      bandaId: widget.bandaId,
      archivo: part.archivo,
      instrumentoCat: instrumentoCat,
    );

    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// ***********************************************
  /// Mostrar menú contextual de partitura
  ///
  /// Opciones:
  /// - Editar partitura
  /// - Eliminar partitura (con validación previa)
  /// - Cancelar
  ///
  /// Solo accesible para administradores
  /// ***********************************************
  Future<void> mostrarMenuPartitura(BuildContext context, Partitura part) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Editar partitura'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaginaDatosPartitura(bandaId: widget.bandaId, partitura: part),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Eliminar partitura'),
                onTap: () async {
                  // Mostramos el diálogo sin cerrar el BottomSheet
                  final confirmar = await mostrarDialogoConfirmacion(
                    context: context,
                    titulo: 'Eliminar partitura',
                    mensaje: '¿Estás seguro de eliminar esta partitura?',
                    icono: Icons.delete_forever,
                    colorIcono: Colors.red.shade700,
                  );

                  if (!confirmar || !mounted) return;

                  // Cerramos el BottomSheet ahora
                  Navigator.pop(context);

                  try {
                    final puedeEliminar = await ConsultasPartiturasBD.partituraSePuedeEliminar(
                      bandaId: widget.bandaId,
                      partituraId: part.id,
                    );

                    if (puedeEliminar) {
                      context.mostrarSnack('Partitura eliminada', esCorrecto: true);
                      await ConsultasPartiturasBD.eliminarPartitura(widget.bandaId, part.id);
                    } else {
                      context.mostrarSnack(
                        'No se puede eliminar: algún repertorio la tiene asignada',
                        esCorrecto: false,
                      );
                    }
                  } catch (e) {
                    if (!mounted) return;
                    context.mostrarSnack("Error eliminando partitura: $e", esCorrecto: false);
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
  /// Contiene:
  /// - AppBar dinámica (modo selección o normal)
  /// - Botón flotante (solo admin)
  /// - Buscador
  /// - Selector de instrumento (si aplica)
  /// - StreamBuilder con lista en tiempo real
  /// - Filtrado por título y género
  /// ********************************************************
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ----------------------------
      //         BARRA SUPERIOR
      // ----------------------------
      appBar: AppBar(title: Text(widget.modoSeleccion ? 'Añadir al repertorio' : 'Partituras')),

      // -----------------------------------------------
      //         BOTÓN FLOTANTE (sólo si esAdmin)
      // -----------------------------------------------
      floatingActionButton: widget.esAdmin && !widget.modoSeleccion
          ? FloatingActionButton(
              child: const Icon(Icons.add),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PaginaDatosPartitura(bandaId: widget.bandaId)),
                );
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
              hintText: 'Buscar por título o género',
              onChanged: (v) => setState(() => filtroBusqueda = v.toLowerCase()),
            ),

            const SizedBox(height: 14),

            // -----------------------------------------------------------------
            //   SELECTOR DE INSTRUMENTO (sólo si no esAdmin ni modoSelección)
            // -----------------------------------------------------------------
            if (!widget.esAdmin && !widget.modoSeleccion)
              cargando
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : AppDropdown<AccesoInstrumento>(
                      value: accesoSeleccionado,
                      items: accesosDisponibles.map((a) => DropdownMenuItem(value: a, child: Text(a.nombre))).toList(),
                      onChanged: (v) => setState(() => accesoSeleccionado = v),
                      label: 'Acceso seleccionado',
                    ),

            // ------------------------------
            //      BUSCAR PARTITURAS
            // ------------------------------
            Expanded(
              child: StreamBuilder<List<Partitura>>(
                stream: ConsultasPartiturasBD.streamPartituras(widget.bandaId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text("No hay partituras"));
                  }

                  final busqueda = filtroBusqueda.toLowerCase();

                  final partiturasFiltradas = snapshot.data!.where((part) {
                    final titulo = part.titulo.toLowerCase();
                    final generoNombre = (mapaGeneros[part.genero] ?? '').toLowerCase();

                    return titulo.contains(busqueda) || generoNombre.contains(busqueda);
                  }).toList();

                  if (partiturasFiltradas.isEmpty) {
                    return const Center(child: Text("No se encontraron partituras"));
                  }

                  // ------------------------------
                  //      LISTA DE PARTITURAS
                  // ------------------------------
                  return ListView.builder(
                    itemCount: partiturasFiltradas.length,
                    itemBuilder: (context, index) {
                      final part = partiturasFiltradas[index];

                      // ------------------------------
                      //      ACCIÓN TARJETA
                      // ------------------------------
                      return InkWell(
                        onTap: () async {
                          if (widget.esAdmin && widget.modoSeleccion) {
                            // Admin pero viene de selección → devolver al repertorio
                            Navigator.pop(context, {'id': part.id, 'datos': part});
                          } else if (widget.esAdmin && !widget.modoSeleccion) {
                            // Admin + no modo selección → no hacemos nada aquí, usamos onLongPress
                            mostrarMenuPartitura(context, part);
                          } else if (!widget.esAdmin) {
                            // No admin → abrir URI de la partitura
                            abrirPartitura(part);
                          }
                        },

                        // ------------------------------
                        //      TARJETA PARTITURAS
                        // ------------------------------
                        child: Tarjeta(
                          iconoWidget: const Icon(Icons.music_note, color: Colors.white),
                          titulo: part.titulo,
                          subtitulo: mapaGeneros[part.genero] ?? part.genero,
                        ),
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
