import 'package:flutter/material.dart';
import 'package:ritmo_app/consultas_bd/temporada.dart';
import 'package:ritmo_app/modelos/temporada.dart';
import 'package:ritmo_app/utiles/widgets.dart';
import 'datos_temporada.dart';

/// ****************************************************************************************
/// Página de Lista de Temporadas
///
/// Permite al administrador:
/// - Visualizar todas las temporadas de la banda
/// - Buscar temporadas por nombre
/// - Crear una nueva temporada
/// - Editar una temporada existente
/// - Eliminar una temporada (si no tiene eventos ni liquidaciones)
///
/// Es un [StatefulWidget] porque:
/// - Gestiona estado de búsqueda
/// - Escucha cambios en tiempo real mediante StreamBuilder
/// - Controla navegación y acciones sobre temporadas
/// ****************************************************************************************
class PaginaListaTemporadas extends StatefulWidget {
  final String bandaId;
  final void Function()? onTemporadaCreada; //callback opcional

  const PaginaListaTemporadas({super.key, required this.bandaId, this.onTemporadaCreada});

  @override
  State<PaginaListaTemporadas> createState() => EstadoPaginaListaTemporadas();
}

/// ****************************************************************************************
/// Estado de la página de Lista de Temporadas
///
/// Contiene la lógica:
/// - Gestión del filtro de búsqueda
/// - Navegación a crear/editar temporada
/// - Eliminación con validación previa
/// - Construcción dinámica de la lista
/// ****************************************************************************************
class EstadoPaginaListaTemporadas extends State<PaginaListaTemporadas> {
  final TextEditingController controladorBusqueda = TextEditingController();

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
  /// Abrir pantalla de creación o edición de temporada
  ///
  /// Si se pasa temporadaId --> modo edición [PaginaDatosTemporada]
  /// Si es null --> modo creación [PaginaDatosTemporada]
  ///
  /// Al volver, ejecuta callback opcional para refrescar datos
  /// *******************************************************************
  Future<void> abrirDatosTemporada({String? temporadaId}) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaginaDatosTemporada(bandaId: widget.bandaId, temporadaId: temporadaId),
      ),
    );
    if (!mounted) return;
    widget.onTemporadaCreada?.call();
  }

  /// *******************************************************************
  /// Eliminar temporada
  ///
  /// Antes de eliminar:
  /// - Verifica que no tenga eventos ni liquidaciones asociadas con [ConsultasTemporadasBD.temporadaSePuedeEliminar].
  /// - Muestra mensaje si no se puede eliminar usando [ConsultasTemporadasBD.eliminarTemporada].
  /// *******************************************************************
  Future<void> eliminarTemporada(Temporada temp) async {
    if (!await ConsultasTemporadasBD.temporadaSePuedeEliminar(widget.bandaId, temp)) {
      if (!mounted) return;
      context.mostrarSnack("No se puede eliminar: existen liquidaciones o eventos", esCorrecto: false);
      return;
    }
    await ConsultasTemporadasBD.eliminarTemporada(widget.bandaId, temp);
  }

  /// *******************************************************************
  /// Formatear fecha en formato dd/MM/yyyy
  /// *******************************************************************
  String formatFecha(DateTime fecha) =>
      "${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}";

  /// ********************************************************
  ///                  --- Construir UI ---
  ///
  /// Estructura:
  /// - AppBar con título fijo
  /// - FloatingActionButton (crear temporada)
  /// - Cuadro de búsqueda
  /// - StreamBuilder con escucha en tiempo real
  ///
  /// La lista:
  /// - Se filtra en memoria por nombre
  /// - Muestra tarjeta personalizada por temporada
  /// - Presenta rango de fechas formateado
  ///
  /// Acciones disponibles en menú contextual:
  /// - Editar temporada
  /// - Eliminar temporada (con confirmación)
  /// - Cancelar
  /// ********************************************************
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ----------------------------
      //         BARRA SUPERIOR
      // ----------------------------
      appBar: AppBar(title: const Text("Temporadas")),

      // ----------------------------
      //         BOTÓN FLOTANTE (Permite crear nueva temporada)
      // ----------------------------
      floatingActionButton: FloatingActionButton(child: const Icon(Icons.add), onPressed: () => abrirDatosTemporada()),

      // ----------------------------
      //       CUERPO PRINCIPAL
      // ----------------------------
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            // ----------------------------
            //      CUADRO DE BÚSQUEDA (Permite buscar por nombre temporada)
            // ----------------------------
            CuadroBusqueda(
              controller: controladorBusqueda,
              hintText: 'Buscar por nombre',
              onChanged: (texto) => setState(() => filtroBusqueda = texto.toLowerCase()),
            ),

            const SizedBox(height: 12),

            // ----------------------------
            //     LISTA DE TEMPORADAS
            // ----------------------------
            Expanded(
              child: StreamBuilder<List<Temporada>>(
                stream: ConsultasTemporadasBD.streamTemporadas(widget.bandaId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text("Error al cargar temporadas"));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final List<Temporada> listaTemporadas = snapshot.data!
                      .where((t) => t.nombre.toLowerCase().contains(filtroBusqueda))
                      .toList();

                  if (listaTemporadas.isEmpty) {
                    return const Center(child: Text("No se encontraron temporadas"));
                  }

                  return ListView.builder(
                    itemCount: listaTemporadas.length,
                    itemBuilder: (context, index) {
                      final temp = listaTemporadas[index];

                      // --------------------------------
                      //        TARJETA TEMPORADA
                      // -------------------------------
                      return Tarjeta(
                        iconoWidget: const Icon(Icons.event, color: Colors.white),
                        titulo: temp.nombre,
                        subtitulo: "Desde: ${formatFecha(temp.fechaInicio)}  a: ${formatFecha(temp.fechaFin)}",
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                            builder: (_) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.edit),
                                    title: const Text('Editar temporada'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      abrirDatosTemporada(temporadaId: temp.id);
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.delete),
                                    title: const Text('Eliminar temporada'),
                                    onTap: () async {
                                      Navigator.pop(context);
                                      final confirmar = await mostrarDialogoConfirmacion(
                                        context: context,
                                        titulo: 'Eliminar temporada',
                                        mensaje: '¿Seguro que quieres eliminar la temporada "${temp.nombre}"?',
                                        icono: Icons.delete_forever,
                                        colorIcono: Colors.red.shade700,
                                      );
                                      if (!confirmar || !mounted) return;
                                      await eliminarTemporada(temp);
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.close),
                                    title: const Text('Cancelar'),
                                    onTap: () => Navigator.pop(context),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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
