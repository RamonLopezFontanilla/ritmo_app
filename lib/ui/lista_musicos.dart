import 'package:flutter/material.dart';
import 'package:ritmo_app/consultas_bd/musicos.dart';
import 'package:ritmo_app/modelos/musico.dart';
import 'package:ritmo_app/ui/datos_musico.dart';
import 'package:ritmo_app/ui/lista_asistencias.dart';
import 'package:ritmo_app/utiles/widgets.dart';

/// ****************************************************************************************
/// Página de Lista de Músicos
///
/// Permite al administrador:
/// - Visualizar todos los músicos de la banda
/// - Buscar músicos por nombre o instrumento
/// - Filtrar activos/inactivos
/// - Ordenar alfabéticamente (A-Z / Z-A)
/// - Crear, editar y eliminar músicos
/// - Ver asistencias de cada músico
/// - Desvincular dispositivos de cada músico
///
/// Es un [StatefulWidget] porque:
/// - Gestiona estado de búsqueda y filtros
/// - Escucha cambios en tiempo real mediante StreamBuilder
/// - Controla navegación y acciones sobre músicos
/// ****************************************************************************************
class PaginaListaMusicos extends StatefulWidget {
  final String bandaId;
  final bool esAdmin;
  final String temporadaSeleccionadaId;
  final String nombreBanda;

  const PaginaListaMusicos({
    super.key,
    required this.bandaId,
    required this.esAdmin,
    required this.temporadaSeleccionadaId,
    required this.nombreBanda,
  });

  @override
  State<PaginaListaMusicos> createState() => EstadoPaginaListaMusicos();
}

/// ****************************************************************************************
/// Estado de la página de Lista de Músicos
///
/// Contiene la lógica:
/// - Gestión del filtro de búsqueda y orden
/// - Navegación a crear/editar músico
/// - Eliminación y desvinculación de dispositivo con confirmación
/// - Construcción dinámica de la lista agrupada por instrumento
/// ****************************************************************************************
class EstadoPaginaListaMusicos extends State<PaginaListaMusicos> {
  final TextEditingController controladorBusqueda = TextEditingController();

  bool ordenAscendente = true;
  bool mostrarInactivos = false;
  String filtroBusqueda = "";

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

  /// *******************************************************************
  /// Eliminar un músico de la banda
  ///
  /// Muestra snack de confirmación o error según corresponda
  /// *******************************************************************
  Future<void> eliminarMusico(String musicoId) async {
    try {
      await ConsultasMusicosBD.eliminarMusicoDeBanda(bandaId: widget.bandaId, musicoId: musicoId);
      if (!mounted) return;
      context.mostrarSnack('Músico eliminado correctamente', esCorrecto: true);
    } catch (e) {
      if (!mounted) return;
      context.mostrarSnack('Error al eliminar músico: $e', esCorrecto: false);
    }
  }

  /// *******************************************************************
  /// Desvincular el dispositivo de un músico
  ///
  /// Muestra snack de confirmación o error según corresponda
  /// *******************************************************************
  Future<void> desvincularDispositivo(String musicoId) async {
    try {
      await ConsultasMusicosBD.desvincularDispositivo(musicoId);
      if (!mounted) return;
      context.mostrarSnack('Dispositivo desvinculado correctamente', esCorrecto: true);
    } catch (e) {
      if (!mounted) return;
      context.mostrarSnack('Error al desvincular dispositivo: $e', esCorrecto: false);
    }
  }

  /// ********************************************************
  ///                  --- Construir UI ---
  ///
  /// Estructura:
  /// - AppBar con título fijo
  /// - FloatingActionButton (crear músico)
  /// - Cuadro de búsqueda
  /// - Switch para mostrar inactivos
  /// - Botón de orden alfabético
  /// - StreamBuilder con escucha en tiempo real
  ///
  /// La lista:
  /// - Se filtra en memoria (activo + búsqueda)
  /// - Se agrupa por instrumento
  /// - Se ordena dinámicamente según flag
  /// - Muestra cabecera por instrumento
  /// - Colorea icono según estado:
  ///     Verde --> Activo
  ///     Rojo --> Inactivo
  ///
  /// Acciones (solo admin):
  /// - Editar músico
  /// - Ver asistencias
  /// - Desvincular dispositivo
  /// - Eliminar músico
  /// ********************************************************
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ----------------------------
      //         BARRA SUPERIOR
      // ----------------------------
      appBar: AppBar(title: const Text("Plantilla de Músicos")),

      // ----------------------------
      //         BOTÓN FLOTANTE
      // ----------------------------
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.person_add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PaginaDatosMusico(bandaId: widget.bandaId, musicoId: null, esAdmin: widget.esAdmin),
            ),
          );
        },
      ),

      // ----------------------------
      //       CUERPO PRINCIPAL
      // ----------------------------
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            // ----------------------------
            //      CUADRO DE BÚSQUEDA
            // ----------------------------
            CuadroBusqueda(
              controller: controladorBusqueda,
              hintText: 'Buscar por nombre o instrumento',
              onChanged: (v) => setState(() => filtroBusqueda = v.toLowerCase()),
            ),

            // ----------------------------
            //     OPCIONES DE CABECERA
            // ----------------------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("  Incluir inactivos"),
                Transform.scale(
                  scale: 0.7,
                  child: Switch(value: mostrarInactivos, onChanged: (v) => setState(() => mostrarInactivos = v)),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => ordenAscendente = !ordenAscendente),
                  icon: Icon(ordenAscendente ? Icons.arrow_upward : Icons.arrow_downward),
                  label: Text(ordenAscendente ? "A-Z" : "Z-A"),
                ),
              ],
            ),

            // --------------------------------------------
            //    OBTENER MÚSICOS ORDENADOS Y AGRUPADOS
            // --------------------------------------------
            Expanded(
              child: StreamBuilder<List<Musico>>(
                stream: ConsultasMusicosBD.streamMusicos(widget.bandaId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  // Filtrar activos/inactivos y búsqueda
                  final filtrados = snapshot.data!.where((m) => mostrarInactivos || m.activo).where((m) {
                    final nombre = m.nombre.toLowerCase();
                    final instrumento = m.instrumentoNombre.toLowerCase();
                    return nombre.contains(filtroBusqueda) || instrumento.contains(filtroBusqueda);
                  }).toList();

                  if (filtrados.isEmpty) return const Center(child: Text("No hay músicos que coincidan."));

                  // Agrupar por instrumento
                  final Map<String, List<Musico>> agrupados = {};
                  for (var m in filtrados) {
                    agrupados.putIfAbsent(m.instrumentoNombre, () => []).add(m);
                  }

                  // Ordenar instrumentos
                  final instrumentosOrdenados = agrupados.keys.toList()
                    ..sort((a, b) => ordenAscendente ? a.compareTo(b) : b.compareTo(a));

                  // ---------------------------
                  //   MOSTRAR LISTA DE MÚSICOS
                  // ---------------------------
                  return ListView(
                    children: instrumentosOrdenados.map((instrumento) {
                      final usuarios = agrupados[instrumento]!;
                      usuarios.sort(
                        (a, b) => ordenAscendente ? a.nombre.compareTo(b.nombre) : b.nombre.compareTo(a.nombre),
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --------------------------------
                          //    CABECERA GRUPO INSTRUMENTO
                          // --------------------------------
                          Padding(
                            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 2),
                            child: Center(
                              child: Text(
                                instrumento.toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
                              ),
                            ),
                          ),

                          ...usuarios.map(
                            // --------------------------------
                            //        TARJETA MÚSICO
                            // -------------------------------
                            (u) => Tarjeta(
                              colorIcono: u.activo ? Colors.green : Colors.red,
                              iconoWidget: MiniAvatar(inicial: u.nombre[0].toUpperCase()),
                              titulo: u.nombre,
                              subtitulo: "${u.instrumentoNombre} ${u.categoriaNombre}",
                              onTap: widget.esAdmin
                                  ? () async {
                                      // --------------------------------
                                      //        MENÚ OPCIONES TARJETA
                                      // -------------------------------
                                      showModalBottomSheet(
                                        context: context,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                        ),
                                        builder: (_) => SafeArea(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Editar músico
                                              ListTile(
                                                leading: const Icon(Icons.edit),
                                                title: const Text('Editar músico'),
                                                onTap: () async {
                                                  Navigator.pop(context);

                                                  final actualizado = await Navigator.push<bool>(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => PaginaDatosMusico(
                                                        esAdmin: widget.esAdmin,
                                                        musicoId: u.uid,
                                                        bandaId: widget.bandaId,
                                                      ),
                                                    ),
                                                  );

                                                  if (!mounted) return;

                                                  if (actualizado == true) {
                                                    setState(() {});
                                                  }
                                                },
                                              ),

                                              // Ver asistencias del músico
                                              ListTile(
                                                leading: const Icon(Icons.calendar_month),
                                                title: const Text('Ver asistencias'),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => PaginaAsistencias(
                                                        bandaId: widget.bandaId,
                                                        musicoId: u.uid,
                                                        temporadaSeleccionadaId: widget.temporadaSeleccionadaId,
                                                        nombreMusico: u.nombre,
                                                        nombreBanda: widget.nombreBanda,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),

                                              // Desvincular dispositivo a músico
                                              ListTile(
                                                leading: const Icon(Icons.phone_iphone),
                                                title: const Text('Desvincular dispositivo'),
                                                onTap: () async {
                                                  Navigator.pop(context);
                                                  final confirmar = await mostrarDialogoConfirmacion(
                                                    context: context,
                                                    titulo: 'Desvincular dispositivo',
                                                    mensaje: '¿Quieres desvincular el dispositivo de "${u.nombre}"?',
                                                    icono: Icons.phone_iphone,
                                                    colorIcono: Colors.indigo,
                                                    textoConfirmar: 'Desvincular',
                                                    textoCancelar: 'Cancelar',
                                                  );
                                                  if (!confirmar) return;
                                                  await desvincularDispositivo(u.uid);
                                                },
                                              ),

                                              //Eliminar músico
                                              ListTile(
                                                leading: const Icon(Icons.delete),
                                                title: const Text('Eliminar'),
                                                onTap: () async {
                                                  Navigator.pop(context);
                                                  final confirmar = await mostrarDialogoConfirmacion(
                                                    context: context,
                                                    titulo: 'Eliminar músico',
                                                    mensaje:
                                                        '¿Seguro que quieres eliminar el músico "${u.nombre}"?\nSe eliminarán también todas sus asistencias.',
                                                    icono: Icons.delete_forever,
                                                    colorIcono: Colors.red.shade700,
                                                  );
                                                  if (!confirmar) return;
                                                  await eliminarMusico(u.uid);
                                                },
                                              ),

                                              //Cancelar menú
                                              ListTile(
                                                leading: const Icon(Icons.close),
                                                title: const Text('Cancelar'),
                                                onTap: () => Navigator.pop(context),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                  : null,
                            ),
                          ),
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
