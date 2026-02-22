import 'package:flutter/material.dart';
import 'package:ritmo_app/consultas_bd/administradores.dart';
import 'package:ritmo_app/consultas_bd/bandas.dart';
import 'package:ritmo_app/modelos/administrador.dart';
import 'package:ritmo_app/modelos/banda.dart';
import 'package:ritmo_app/utiles/widgets.dart';

/// ********************************************************
/// Página de creación/edición de datos de Banda para Super Administrador (Inmutable)
///
/// Permite al Super Admin:
/// - Crear una nueva banda
/// - Editar los datos de una banda existente
/// - Asignar o crear administradores para la banda
///
/// Es un [StatefulWidget] porque se mantiene estado:
/// - Valores de los campos de texto
/// - Lista de administradores disponibles
/// - Administrador seleccionado
/// ********************************************************
class PantallaEditarBandaSuperAdmin extends StatefulWidget {
  final String? bandaId;
  final Banda? datosIniciales;

  const PantallaEditarBandaSuperAdmin({this.bandaId, this.datosIniciales, super.key});

  @override
  State<PantallaEditarBandaSuperAdmin> createState() => EstadoPantallaEditarBandaSuperAdmin();
}

/// ********************************************************
/// Estado de la página de datos Banda para Super Administrador
///
/// Contiene toda la lógica:
/// - Controladores de campos de texto
/// - Selección de administrador
/// - Carga de administradores desde BD
/// - Creación de nuevos administradores
/// - Guardado de banda nueva o edición de existente
/// ********************************************************
class EstadoPantallaEditarBandaSuperAdmin extends State<PantallaEditarBandaSuperAdmin> {
  final TextEditingController controladorNombre = TextEditingController();
  final TextEditingController controladorEmail = TextEditingController();
  final TextEditingController controladorPassword = TextEditingController();

  String? adminSeleccionado;
  List<Administrador> admins = [];

  /// ********************************************************
  /// Inicialización
  ///
  /// Se establece el nombre y administrador inicial si se está editando y se carga la lista de administradores disponibles.
  /// ********************************************************
  @override
  void initState() {
    super.initState();

    controladorNombre.text = widget.datosIniciales?.nombre ?? '';
    adminSeleccionado = widget.datosIniciales?.administradorId;

    cargarAdministradores();
  }

  /// ********************************************************
  /// Liberación de recursos
  ///
  /// Es importante liberar los controladores para evitar fugas de memoria.
  /// ********************************************************
  @override
  void dispose() {
    controladorNombre.dispose();
    controladorEmail.dispose();
    controladorPassword.dispose();
    super.dispose();
  }

  /// ********************************************************
  /// Cargar Administradores
  ///
  /// Consulta la lista de administradores en la base de datos y actualiza el estado para reflejar la lista en el dropdown.
  /// ********************************************************
  Future<void> cargarAdministradores() async {
    final lista = await ConsultasAdministradoresBD.obtenerAdministradores();
    setState(() {
      admins = lista;
    });
  }

  /// ********************************************************
  /// Crear Administrador
  ///
  /// Muestra un [AlertDialog] para introducir email y contraseña y crea un nuevo administrador mediante [ConsultasAdministradoresBD.crearAdministrador].
  /// Si la creación es exitosa, se añade a la lista de administradores y se selecciona automáticamente en el dropdown.
  /// ********************************************************
  Future<void> crearAdmin() async {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: DialogoBase(
            icono: Icons.person_add,
            titulo: "Crear Administrador",
            children: [
              // Campos de entrada
              AppInput(label: "Email", controller: emailController, keyboardType: TextInputType.emailAddress),
              AppInput(label: "Contraseña", controller: passwordController, obscureText: true),
              const SizedBox(height: 20),

              // Fila de botones
              Row(
                children: [
                  // Crear como texto plano
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancelar", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Cancelar como botón secundario
                  Expanded(
                    child: BotonPrimarioDialogo(
                      icon: Icons.save,
                      label: "Grabar",
                      onPressed: () async {
                        final email = emailController.text.trim();
                        final password = passwordController.text.trim();

                        if (email.isEmpty || password.isEmpty) return;

                        final nuevoAdmin = await ConsultasAdministradoresBD.crearAdministrador(
                          email,
                          password,
                          bandaId: widget.bandaId,
                        );

                        if (nuevoAdmin != null) {
                          setState(() {
                            admins.add(nuevoAdmin);
                            adminSeleccionado = nuevoAdmin.uid;
                          });
                        }

                        if (!mounted) return;
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// ********************************************************
  /// Guardar Banda
  ///
  /// Si la banda no existe (widget.bandaId == null) crea una nueva banda usando Usa [ConsultasBandasBD.crearBanda].
  /// Si la banda existe, la edita usando [ConsultasBandasBD.editarBanda].
  /// Valida que haya nombre de banda y administrador seleccionado.
  /// ********************************************************
  Future<void> guardarBanda() async {
    final nombre = controladorNombre.text.trim();
    if (nombre.isEmpty || adminSeleccionado == null) return;

    final admin = admins.firstWhere((a) => a.uid == adminSeleccionado);

    if (widget.bandaId == null) {
      await ConsultasBandasBD.crearBanda(nombre, admin);
    } else {
      final adminAnteriorId = widget.datosIniciales?.administradorId;
      await ConsultasBandasBD.editarBanda(widget.bandaId!, nombre, admin, adminAnteriorId);
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  /// ********************************************************
  ///                  --- Construir UI ---
  ///
  /// Estructura:
  /// - AppBar con título según modo (Nueva/Editar)
  /// - Column con:
  ///   * Campo de texto para nombre de banda
  ///   * Dropdown para seleccionar administrador
  ///   * Botón para crear nuevo administrador
  /// - BottomNavigationBar con botón guardar
  /// ********************************************************
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ----------------------------
      //         BARRA SUPERIOR
      // ----------------------------
      appBar: AppBar(title: Text(widget.bandaId == null ? "Nueva Banda" : "Editar Banda")),

      // ----------------------------
      //       CUERPO PRINCIPAL
      // ----------------------------
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            AppInput(label: "Nombre de la banda", controller: controladorNombre),
            const SizedBox(height: 16),
            AppDropdown<String>(
              value: adminSeleccionado,
              label: "Administrador",
              items: admins.map((a) => DropdownMenuItem(value: a.uid, child: Text(a.email))).toList(),
              onChanged: (v) => setState(() => adminSeleccionado = v),
            ),
            const SizedBox(height: 16),

            BotonAPantalla(icon: Icons.person_add, label: "Crear nuevo admin", onPressed: crearAdmin),
            const SizedBox(height: 16),
          ],
        ),
      ),

      // ----------------------------
      //       BOTÓN GUARDAR
      // ----------------------------
      bottomNavigationBar: BotonGuardar(onPressed: guardarBanda, enabled: true),
    );
  }
}
