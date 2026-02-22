import 'package:flutter/material.dart';
import 'package:ritmo_app/consultas_bd/ubicaciones.dart';
import 'package:ritmo_app/modelos/ubicacion.dart';
import 'package:ritmo_app/ui/datos_ubicacion.dart';
import 'package:ritmo_app/utiles/widgets.dart';

/// ****************************************************************************************
/// Página de Lista de Ubicaciones
///
/// Permite:
/// - Visualizar todos los sitios registrados en la banda
/// - Buscar por nombre o dirección
/// - Crear nuevas ubicaciones
/// - Editar o eliminar ubicaciones existentes
/// - Seleccionar una ubicación cuando se usa en modo selección
///
/// Es un [StatefulWidget] porque:
/// - Gestiona estado del buscador
/// - Escucha cambios en tiempo real mediante StreamBuilder
/// - Controla navegación y acciones según modo selección
/// ****************************************************************************************
class PaginaListaUbicaciones extends StatefulWidget {
  final String bandaId;
  final bool seleccionar;

  const PaginaListaUbicaciones({super.key, required this.bandaId, required this.seleccionar});
  @override
  State<PaginaListaUbicaciones> createState() => EstadoPaginaListaUbicaciones();
}

/// *******************************************************************************************
/// Estado de la página de Lista de Ubicaciones
///
/// Contiene:
/// - Controlador del campo de búsqueda
/// - Texto de filtro en tiempo real
///
/// Gestiona:
/// - Filtrado dinámico de ubicaciones
/// - Menú contextual para acciones CRUD
/// - Devolución de datos cuando se usa en modo selección
/// *******************************************************************************************
class EstadoPaginaListaUbicaciones extends State<PaginaListaUbicaciones> {
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

  /// ***********************************************
  /// Mostrar menú contextual de ubicación
  ///
  /// Opciones disponibles:
  /// - Editar sitio
  /// - Eliminar sitio (con validación previa en BD)
  /// - Cancelar
  ///
  /// Antes de eliminar:
  /// - Se muestra diálogo de confirmación
  /// - Se valida que ningún evento tenga asignada la ubicación
  /// ***********************************************
  Future<void> mostrarMenuUbicacion(BuildContext context, Ubicacion ubic) async {
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
                title: const Text('Editar sitio'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaginaDatosUbicacion(bandaId: widget.bandaId, ubicacion: ubic),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Eliminar sitio'),
                onTap: () async {
                  final navigator = Navigator.of(context);

                  navigator.pop();

                  // Preguntar confirmación
                  final confirmar = await mostrarDialogoConfirmacion(
                    context: context,
                    titulo: 'Eliminar sitio',
                    mensaje: '¿Estás seguro de eliminar este sitio?',
                    icono: Icons.delete_forever,
                    colorIcono: Colors.red.shade700,
                  );

                  if (!confirmar || !mounted) return;

                  try {
                    // Validar si la partitura puede eliminarse
                    final puedeEliminar = await ConsultasUbicacionesBD.ubicacionSePuedeEliminar(
                      bandaId: widget.bandaId,
                      ubicacionId: ubic.id,
                    );
                    if (puedeEliminar) {
                      await ConsultasUbicacionesBD.eliminarUbicacion(widget.bandaId, ubic.id);
                      if (!mounted) return;
                      context.mostrarSnack('Sitio eliminado', esCorrecto: true);
                    } else {
                      context.mostrarSnack('No se puede eliminar: algún evento lo tiene asignado', esCorrecto: false);
                      return;
                    }
                  } catch (e) {
                    if (!mounted) return;
                    context.mostrarSnack("Error eliminando sitio: $e", esCorrecto: false);
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
  /// - Botón flotante para crear nueva ubicación
  /// - Cuadro de búsqueda
  /// - StreamBuilder con escucha en tiempo real
  /// - Filtrado dinámico por nombre
  /// - Lista de tarjetas de ubicación
  ///
  /// Comportamiento especial:
  /// - Si seleccionar == true → devuelve la ubicación al Navigator
  /// - Si seleccionar == false → muestra menú contextual
  /// ********************************************************
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ----------------------------
      //         BARRA SUPERIOR
      // ----------------------------
      appBar: AppBar(title: const Text('Sitios')),

      // ----------------------------
      //         BOTÓN FLOTANTE
      // ----------------------------
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => PaginaDatosUbicacion(bandaId: widget.bandaId)));
        },
        child: const Icon(Icons.add),
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
              hintText: 'Buscar por nombre o dirección',
              onChanged: (v) => setState(() => filtroBusqueda = v.toLowerCase()),
            ),

            const SizedBox(height: 14),

            // ----------------------------
            //     LISTA DE UBICACIONES
            // ----------------------------
            Expanded(
              child: StreamBuilder<List<Ubicacion>>(
                stream: ConsultasUbicacionesBD.streamUbicaciones(widget.bandaId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  final ubicaciones = snapshot.data!
                      .where((u) => u.nombre.toLowerCase().contains(filtroBusqueda))
                      .toList();

                  if (ubicaciones.isEmpty) return const Center(child: Text("No se encontraron sitios"));

                  return ListView.builder(
                    itemCount: ubicaciones.length,
                    itemBuilder: (context, index) {
                      final ubic = ubicaciones[index];
                      // ----------------------------
                      //     TARJETA DE UBICACIÓN
                      // ----------------------------
                      return InkWell(
                        onTap: () async {
                          if (widget.seleccionar) {
                            // Devuelve la ubicación seleccionada al Navigator
                            Navigator.pop(context, ubic);
                          } else {
                            mostrarMenuUbicacion(context, ubic);
                          }
                        },
                        child: Tarjeta(
                          iconoWidget: const Icon(Icons.place, color: Colors.white),
                          titulo: ubic.nombre,
                          subtitulo: ubic.direccion,
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
