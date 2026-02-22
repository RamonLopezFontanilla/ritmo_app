import 'package:flutter/material.dart';
import 'package:ritmo_app/consultas_bd/instrumentos.dart';
import 'package:ritmo_app/modelos/instrumento.dart';
import 'package:ritmo_app/ui/datos_instrumento.dart';
import 'package:ritmo_app/utiles/widgets.dart';

/// ****************************************************************************************
/// Página de Lista de Instrumentos
///
/// Permite:
/// - Visualizar todos los instrumentos de una banda
/// - Buscar por nombre o categoría
/// - Crear nuevos instrumentos
/// - Editar instrumentos existentes
/// - Eliminar instrumentos (si no están asignados a músicos)
///
/// Es un [StatefulWidget] porque:
/// - Gestiona estado del buscador
/// - Mantiene caché de imágenes
/// - Escucha cambios en tiempo real mediante Stream
/// ****************************************************************************************
class PaginaListaInstrumentos extends StatefulWidget {
  final String bandaId;
  const PaginaListaInstrumentos({super.key, required this.bandaId});

  @override
  State<PaginaListaInstrumentos> createState() => EstadoPaginaListaInstrumentos();
}

/// ****************************************************************************************
/// Estado de la página de Lista de Instrumentos
///
/// Contiene:
/// - Controlador de búsqueda
/// - Texto de filtro actual
/// - Caché de URLs de imágenes
/// - Funciones para mostrar menú y eliminar instrumentos
/// ****************************************************************************************
class EstadoPaginaListaInstrumentos extends State<PaginaListaInstrumentos> {
  final TextEditingController controladorBusqueda = TextEditingController();

  String filtroBusqueda = "";

  /// Cache de URLs de imágenes
  final Map<String, String> cacheImagenes = {};

  /// ***********************************************
  /// Liberación de memoria
  ///
  /// Se libera el controlador del buscador
  /// ***********************************************
  @override
  void dispose() {
    controladorBusqueda.dispose();
    super.dispose();
  }

  /// ***********************************************
  /// Obtener URL de imagen con caché
  ///
  /// Flujo:
  /// 1. Si el path está vacío --> retornar vacío
  /// 2. Si es asset local --> retornar directamente
  /// 3. Si ya está en caché --> retornar desde memoria
  /// 4. Si no --> consultar BD y guardarlo en caché
  /// ***********************************************
  Future<String> obtenerUrlImagenConCache(String path) async {
    if (path.isEmpty) return "";

    // Si es un asset, retornamos directamente
    if (path.startsWith("assets/")) return path;

    // Revisar caché
    if (cacheImagenes.containsKey(path)) return cacheImagenes[path]!;

    // Intentar obtener URL desde la base de datos
    try {
      final url = await ConsultasInstrumentosBD.obtenerUrlImagen(path);
      cacheImagenes[path] = url;
      return url;
    } catch (e) {
      return "";
    }
  }

  /// ***********************************************
  /// Mostrar menú de opciones del instrumento
  ///
  /// Opciones:
  /// - Editar
  /// - Eliminar (si es posible)
  /// - Cancelar
  /// ***********************************************
  Future<void> mostrarMenuInstrumento(BuildContext context, Instrumento inst) async {
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
                title: const Text('Editar instrumento'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaginaDatosInstrumento(bandaId: widget.bandaId, instrumentoId: inst.id),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Eliminar instrumento'),
                onTap: () async {
                  final navigator = Navigator.of(context);

                  navigator.pop();

                  // Preguntar confirmación
                  final confirmar = await mostrarDialogoConfirmacion(
                    context: context,
                    titulo: 'Eliminar instrumento',
                    mensaje: '¿Estás seguro de eliminar este instrumento?',
                    icono: Icons.delete_forever,
                    colorIcono: Colors.red.shade700,
                  );

                  if (!confirmar || !mounted) return;

                  try {
                    // Validar si el instrumento puede eliminarse
                    final puedeEliminar = await ConsultasInstrumentosBD.instrumentoSePuedeEliminar(
                      bandaId: widget.bandaId,
                      instrumentoId: inst.id,
                    );
                    if (puedeEliminar) {
                      await ConsultasInstrumentosBD.eliminarInstrumento(
                        bandaId: widget.bandaId,
                        instrumentoId: inst.id,
                      );
                      if (!mounted) return;
                      context.mostrarSnack('Instrumento eliminado', esCorrecto: true);
                    } else {
                      context.mostrarSnack('No se puede eliminar: algún músico lo tiene asignado', esCorrecto: false);
                      return;
                    }
                  } catch (e) {
                    if (!mounted) return;
                    context.mostrarSnack("Error eliminando instrumento: $e", esCorrecto: false);
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
  /// - AppBar con título fijo
  /// - Botón flotante para crear instrumento
  /// - Cuadro de búsqueda
  /// - StreamBuilder con escucha en tiempo real
  /// - Filtrado por nombre o categoría
  /// - Lista dinámica de tarjetas con imagen
  ///
  /// Las imágenes:
  /// - Se buscan en asset local o URL remota
  /// - Utilizan caché en memoria para optimizar rendimiento
  /// ********************************************************
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ----------------------------
      //         BARRA SUPERIOR
      // ----------------------------
      appBar: AppBar(title: const Text("Cuerdas disponibles")),

      // ----------------------------
      //         BOTÓN FLOTANTE
      // ----------------------------
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => PaginaDatosInstrumento(bandaId: widget.bandaId)));
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
            //       CUADRO BÚSQUEDA
            // ----------------------------
            CuadroBusqueda(
              controller: controladorBusqueda,
              hintText: 'Buscar por instrumento o categoría',
              onChanged: (v) => setState(() => filtroBusqueda = v.toLowerCase()),
            ),
            const SizedBox(height: 14),

            // ----------------------------
            //      BUSQUEDA INSTRUMENTOS
            // ----------------------------
            Expanded(
              child: StreamBuilder<List<Instrumento>>(
                stream: ConsultasInstrumentosBD.streamListaInstrumentos(widget.bandaId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final instrumentos = snapshot.data!;
                  final busqueda = filtroBusqueda.toLowerCase();

                  final listaFiltrada = instrumentos.where((inst) {
                    return inst.nombre.toLowerCase().contains(busqueda) ||
                        inst.categorias.any((c) => c.nombre.toLowerCase().contains(busqueda));
                  }).toList();

                  if (listaFiltrada.isEmpty) {
                    return const Center(child: Text("No se encontraron instrumentos"));
                  }

                  // ----------------------------
                  //       LISTA INSTRUMENTOS
                  // ----------------------------
                  return ListView.builder(
                    itemCount: listaFiltrada.length,
                    itemBuilder: (context, index) {
                      final inst = listaFiltrada[index];

                      // ----------------------------
                      //      TARJETA INSTRUMENTO
                      // ----------------------------
                      return InkWell(
                        onTap: () => mostrarMenuInstrumento(context, inst),
                        child: Tarjeta(
                          iconoWidget: FutureBuilder<String>(
                            future: obtenerUrlImagenConCache(inst.iconoUrl),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return Container(
                                  width: 50,
                                  height: 50,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.music_note, color: Colors.grey),
                                );
                              }

                              final path = snapshot.data!;
                              if (path.startsWith("assets/")) {
                                return Image.asset(path, width: 50, height: 50, fit: BoxFit.cover);
                              } else {
                                return Image.network(path, width: 50, height: 50, fit: BoxFit.cover);
                              }
                            },
                          ),
                          titulo: inst.nombre,
                          subtitulo: inst.categorias.isEmpty
                              ? "Sin categorías"
                              : inst.categorias.map((c) => c.nombre).join(" • "),
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
