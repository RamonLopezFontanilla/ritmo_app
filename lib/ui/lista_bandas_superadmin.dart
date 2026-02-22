import 'package:flutter/material.dart';
import 'package:ritmo_app/consultas_bd/bandas.dart';
import 'package:ritmo_app/ui/datos_banda_superadmin.dart';
import 'package:ritmo_app/modelos/banda.dart';
import 'package:ritmo_app/utiles/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ********************************************************
/// Página principal del Super Administrador
///
/// Permite al Super Admin:
/// - Visualizar la lista completa de bandas
/// - Buscar bandas por nombre o correo del administrador
/// - Editar o eliminar bandas existentes
/// - Crear nuevas bandas
///
/// Es un [StatefulWidget] porque se necesita mantener estado:
/// - Valor de búsqueda
/// - Actualización de la lista después de operaciones CRUD
/// ********************************************************
class PantallaSuperAdministrador extends StatefulWidget {
  const PantallaSuperAdministrador({super.key});

  @override
  State<PantallaSuperAdministrador> createState() => EstadoPantallaSuperAdministrador();
}

/// ********************************************************
/// Estado de la página del Super Administrador (Guarda todos los datos que cambian)
///
/// Contiene toda la lógica:
/// - Controlador de búsqueda
/// - Filtrado de bandas
/// - Menú de opciones para cada banda (editar/eliminar/cancelar)
/// - La construcción de la interfaz gráfica con lista de bandas y botón flotante para agregar nuevas
/// ********************************************************
class EstadoPantallaSuperAdministrador extends State<PantallaSuperAdministrador> {
  final TextEditingController controladorBusqueda = TextEditingController();

  String filtroBusqueda = "";

  /// ********************************************************
  /// Liberación de recursos
  ///
  /// Es importante liberar los controladores para evitar fugas de memoria.
  /// ********************************************************
  @override
  void dispose() {
    controladorBusqueda.dispose();
    super.dispose();
  }

  /// ********************************************************
  /// Mostrar menú de opciones para una banda
  ///
  /// Despliega un [BottomSheet] con opciones:
  /// 1. Editar banda --> navega a [PantallaEditarBandaSuperAdmin]
  /// 2. Eliminar banda --> pide confirmación y elimina mediante [ConsultasBandasBD.eliminarBanda]
  /// 3. Cancelar --> cierra el menú
  ///
  /// Actualiza la lista al volver de edición o eliminación mediante [setState].
  /// ********************************************************
  void mostrarMenuBanda(Banda banda) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Opción editar banda (navega a pantalla de edición)
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text("Editar"),
                  onTap: () async {
                    Navigator.pop(context);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PantallaEditarBandaSuperAdmin(bandaId: banda.id, datosIniciales: banda),
                      ),
                    );
                    setState(() {});
                  },
                ),
                // Opción eliminar banda (pide confirmación en diálogo)
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: const Text("Eliminar"),
                  onTap: () async {
                    Navigator.pop(context);

                    final confirmar = await mostrarDialogoConfirmacion(
                      context: context,
                      titulo: "Eliminar banda",
                      mensaje: "¿Seguro que quieres eliminar '${banda.nombre}'?",
                      icono: Icons.delete_forever,
                    );

                    if (!confirmar) return;

                    await ConsultasBandasBD.eliminarBanda(banda);

                    if (!mounted) return;
                    context.mostrarSnack("Banda eliminada correctamente", esCorrecto: true);
                    setState(() {});
                  },
                ),

                // Opción Cancelar (cierra el menú)
                ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text("Cancelar"),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// ********************************************************
  ///                  --- Construir UI ---
  ///
  /// Estructura:
  /// - AppBar con acciones administrativas
  /// - Botón flotante para crear nueva banda
  /// - Cuadro de búsqueda
  /// - Botón para reseteo de vista de tutoriales en el dispositivo
  ///
  /// La lista:
  /// - Se obtiene mediante consulta única (no Stream)
  /// - Se filtra en memoria por nombre o email
  /// - Muestra tarjeta personalizada por banda
  /// - Abre menú contextual al pulsar
  ///
  /// Acción especial:
  /// - Botón DEBUG para resetear flags de tutorial
  ///   almacenados en SharedPreferences
  /// ********************************************************
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ----------------------------
      //         BARRA SUPERIOR
      // ----------------------------
      appBar: AppBar(
        title: const Text("Super Administrador"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset tutorial',
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('tutorial_admin_visto', false);
              await prefs.setBool('tutorial_musico_visto', false);

              if (!mounted) return;
              context.mostrarSnack("Volverás a ver los tutoriales en este dispositivo", esCorrecto: true);
            },
          ),
        ],
      ),

      // ----------------------------
      //         BOTÓN FLOTANTE
      // ----------------------------
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const PantallaEditarBandaSuperAdmin()));
          setState(() {});
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
              hintText: 'Buscar banda o email',
              onChanged: (v) => setState(() => filtroBusqueda = v.toLowerCase()),
            ),
            const SizedBox(height: 14),

            // ----------------------------
            //       LISTA BANDAS
            // ----------------------------
            Expanded(
              child: FutureBuilder<List<Banda>>(
                future: ConsultasBandasBD.obtenerBandas(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text("No hay bandas"));
                  }

                  final bandasFiltradas = snapshot.data!.where((banda) {
                    final nombre = banda.nombre.toLowerCase();
                    final adminEmail = banda.administradorEmail.toLowerCase();
                    return nombre.contains(filtroBusqueda) || adminEmail.contains(filtroBusqueda);
                  }).toList();

                  if (bandasFiltradas.isEmpty) {
                    return const Center(child: Text("No hay bandas"));
                  }

                  return ListView.builder(
                    itemCount: bandasFiltradas.length,
                    itemBuilder: (context, index) {
                      final banda = bandasFiltradas[index];
                      return Tarjeta(
                        titulo: banda.nombre,
                        subtitulo: banda.administradorEmail,
                        iconoWidget: const Icon(Icons.queue_music, color: Colors.white),
                        onTap: () => mostrarMenuBanda(banda),
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
