import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ritmo_app/consultas_bd/bandas.dart';
import 'package:ritmo_app/ui/menu_admin.dart';
import 'package:ritmo_app/ui/menu_musico.dart';
import 'package:ritmo_app/ui/lista_bandas_superadmin.dart';
import 'package:ritmo_app/ui/login_resetear_password.dart';
import 'package:ritmo_app/modelos/usuario.dart';
import 'package:ritmo_app/modelos/banda.dart';
import 'package:ritmo_app/utiles/validadores.dart';
import 'package:ritmo_app/utiles/widgets.dart';
import 'package:ritmo_app/consultas_bd/login.dart';
import 'package:uuid/uuid.dart';

/// ********************************************************
/// Página principal del login.
///
/// Es un [StatefulWidget] porque necesita mantener estado:
/// - Email y contraseña introducidos
/// - Estado de carga (login automático)
/// - Contador de clicks para acceso Super Admin
/// ********************************************************
class PaginaLogin extends StatefulWidget {
  const PaginaLogin({super.key});

  @override
  State<PaginaLogin> createState() => EstadoPaginaLogin();
}

/// ********************************************************
/// Estado de la página de login.
///
/// Contiene toda la lógica:
/// - Login automático y manual
/// - Gestión del dispositivo
/// - Navegación según el rol del usuario
/// - La construcción de la interfaz gráfica.
/// ********************************************************
class EstadoPaginaLogin extends State<PaginaLogin> {
  final controladorEmail = TextEditingController();
  final controladorPassword = TextEditingController();

  bool comprobandoLogin = true;
  int contadorClicksLogo = 0;

  /// ********************************************************
  /// Inicialización del estado
  ///
  /// Se comprueba automáticamente si el usuario ya tiene sesión iniciada.
  /// ********************************************************
  @override
  void initState() {
    super.initState();
    comprobarSiEstaLogueado();
  }

  /// ********************************************************
  /// Liberación de recursos
  ///
  /// Es importante liberar los controladores para evitar fugas de memoria.
  /// ********************************************************
  @override
  void dispose() {
    controladorEmail.dispose();
    controladorPassword.dispose();
    super.dispose();
  }

  /// ********************************************************
  /// Obtiene o genera un identificador único del dispositivo.
  ///
  /// - Se almacena de forma segura usando [FlutterSecureStorage].
  /// - Permite vincular un dispositivo a un usuario.
  /// - Si ya existe, se reutiliza para mantener consistencia.
  /// ********************************************************
  Future<String> obtenerIdDispositivo() async {
    const storage = FlutterSecureStorage();
    const key = 'device_uuid';

    final idAlmacenado = await storage.read(key: key);
    if (idAlmacenado != null) return idAlmacenado;

    final nuevoId = const Uuid().v4();
    await storage.write(key: key, value: nuevoId);
    return nuevoId;
  }

  /// ********************************************************
  /// Comprueba si existe una sesión activa.
  ///
  /// - Si el usuario está autenticado, se navega directamente según su rol mediante [navegarSegunRol]
  /// - Si ocurre un error, se muestra al usuario.
  /// ********************************************************
  Future<void> comprobarSiEstaLogueado() async {
    try {
      final usuario = await ConsultasLoginBD.loginAutomatico();
      if (usuario != null) {
        await navegarSegunRol(usuario);
      }
    } catch (e) {
      if (!mounted) return;
      context.mostrarSnack("Error al iniciar sesión automáticamente: $e", esCorrecto: false);
    } finally {
      if (mounted) setState(() => comprobandoLogin = false);
    }
  }

  /// ********************************************************
  /// Login manual del usuario.
  ///
  /// Pasos:
  /// 1. Validar campos y formato de email con [esEmailValido]
  /// 2. Obtener ID del dispositivo con [obtenerIdDispositivo]
  /// 3. Verificar que el dispositivo no esté vinculado a otro usuario usando [ConsultasLoginBD.validarDispositivo]
  /// 4. Realizar login con [ConsultasLoginBD.login]
  /// 5. Vincular el dispositivo usando [ConsultasLoginBD.vincularDispositivo]
  /// 6. Navegar según rol con [navegarSegunRol]
  /// ********************************************************
  Future<void> iniciarSesion() async {
    final email = controladorEmail.text.trim();
    final password = controladorPassword.text.trim();
    final deviceId = await obtenerIdDispositivo();
    if (!mounted) return;
    if (email.isEmpty || password.isEmpty) {
      context.mostrarSnack("Por favor completa todos los campos.", esCorrecto: false);
      return;
    }

    if (!esEmailValido(email)) {
      context.mostrarSnack("El correo electrónico no es válido.", esCorrecto: false);
      return;
    }

    try {
      // Verifica que el dispositivo no esté asociado a otro usuario
      await ConsultasLoginBD.validarDispositivo(deviceId, email);

      // Login normal
      final usuario = await ConsultasLoginBD.login(email: email, password: password);

      // Vincular dispositivo si corresponde
      await ConsultasLoginBD.vincularDispositivo(usuario.id, deviceId, rol: usuario.rol);
      if (!mounted) return;
      context.mostrarSnack("Login correcto", esCorrecto: true);
      await navegarSegunRol(usuario);
    } catch (e) {
      if (!mounted) return;
      context.mostrarSnack(e.toString(), esCorrecto: false);
    }
  }

  /// ********************************************************
  /// Navega a la pantalla correspondiente según:
  /// 1. Si el usuario tiene bandas asignadas.
  /// 2. Si tiene una o varias bandas (muestra selector).
  /// 3. El rol del usuario (admin o músico).
  ///
  /// Casos:
  /// - Usuario sin bandas --> se cierra sesión [ConsultasLoginBD.cerrarSesion]
  /// - Usuario con 1 banda --> navega directamente según su rol
  /// - Usuario con varias bandas --> muestra selector antes de navegar
  /// ********************************************************
  Future<void> navegarSegunRol(Usuario usuario) async {
    if (!mounted) return;

    // Usuario sin bandas --> cerrar sesión
    if (usuario.bandasId.isEmpty) {
      await ConsultasLoginBD.cerrarSesion();
      context.mostrarSnack("No tienes ninguna banda asignada. Se cerró tu sesión.", esCorrecto: false);

      return;
    }

    // OBTENER BANDA SEGÚN CANTIDAD
    final String? bandaId = await obtenerBandaSeleccionada(usuario);
    if (bandaId == null) return;

    // NAVEGAR SEGÚN ROL
    await navegarSegunRolYBanda(usuario, bandaId);
  }

  /// ********************************************************
  /// Obtiene la banda con la que el usuario trabajará.
  ///
  /// - Si solo tiene una banda, la devuelve directamente.
  /// - Si tiene varias, muestra un selector.
  /// - Si ocurre un error o no existen datos válidos,
  ///   se cierra sesión.
  ///
  /// Devuelve:
  /// - El ID de la banda seleccionada.
  /// - null si se cancela o hay error.
  /// ********************************************************
  Future<String?> obtenerBandaSeleccionada(Usuario usuario) async {
    // Solo una banda → usar directamente
    if (usuario.bandasId.length == 1) {
      return usuario.bandasId.first;
    }

    // Varias bandas → obtener datos
    final bandas = await ConsultasBandasBD.obtenerBandasDelUsuario(usuario.bandasId);

    if (bandas.isEmpty) {
      await ConsultasLoginBD.cerrarSesion();
      context.mostrarSnack("No tienes ninguna banda asignada. Se cerró tu sesión.", esCorrecto: false);
      return null;
    }

    if (!mounted) return null;

    // Mostrar selector
    return await mostrarDialogoSeleccionBandas(context, bandas);
  }

  /// ********************************************************
  /// Realiza la navegación final según el rol del usuario y la banda seleccionada.
  ///
  /// - Admin --> [PaginaMenuAdministrador]
  /// - Músico --> asegura pertenencia a la banda y navega a [PaginaMenuMusico]
  /// ********************************************************

  Future<void> navegarSegunRolYBanda(Usuario usuario, String bandaId) async {
    if (!mounted) return;

    // ADMIN
    if (usuario.rol == 'admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaginaMenuAdministrador(bandaId: bandaId, uid: usuario.id),
        ),
      );
      return;
    }

    // MÚSICO
    await ConsultasLoginBD.asegurarMusicoEnBanda(bandaId: bandaId, musicoId: usuario.id);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PaginaMenuMusico(bandaId: bandaId, musicoId: usuario.id),
      ),
    );
  }

  /// ********************************************************
  /// Muestra un diálogo modal para seleccionar una banda.
  ///
  /// - Incluye buscador por nombre.
  /// - Se usa un [BottomSheet] para mejor UX en móvil.
  /// ********************************************************
  Future<String?> mostrarDialogoSeleccionBandas(BuildContext context, List<Banda> bandas) async {
    List<Banda> filtradas = List.from(bandas);
    final controladorBusqueda = TextEditingController();

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            builder: (_, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    CuadroBusqueda(
                      controller: controladorBusqueda,
                      onChanged: (value) {
                        final filtro = value.toLowerCase();
                        filtradas = bandas.where((b) => b.nombre.toLowerCase().contains(filtro)).toList();
                        setModalState(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtradas.isEmpty
                          ? const Center(child: Text("No se encontraron bandas"))
                          : ListView.separated(
                              controller: scrollController,
                              itemCount: filtradas.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final banda = filtradas[i];
                                return ListTile(
                                  leading: const Icon(Icons.library_music),
                                  title: Text(banda.nombre, maxLines: 2, overflow: TextOverflow.ellipsis),
                                  onTap: () => Navigator.pop(context, banda.id),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                    BotonPrimarioDialogo(label: "Cancelar", icon: Icons.close, onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ********************************************************
  /// Muestra un diálogo de autenticación para acceso al modo Super Administrador.
  ///
  /// Pasos:
  /// - Presenta un [AlertDialog] con un campo de contraseña.
  /// - La contraseña se valida mediante [ConsultasLoginBD.validarSuperAdmin].
  /// - Si la validación es correcta, se navega a pantalla SuperAdmin [PantallaSuperAdministrador].
  /// - Si es incorrecta, se muestra un mensaje de error.
  ///
  /// El diálogo no puede cerrarse tocando fuera de él ya que [barrierDismissible] es false para evitar cierres accidentales.
  /// ********************************************************
  Future<void> mostrarDialogoSuperAdmin() async {
    final controladorPassword = TextEditingController();

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        content: DialogoBase(
          icono: Icons.lock,
          titulo: "Acceso Super Admin",
          children: [
            TextField(
              controller: controladorPassword,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Introduce la contraseña", border: OutlineInputBorder()),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        actions: [
          SizedBox(
            height: 40,
            child: TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
          ),
          SizedBox(
            width: 120,
            child: BotonPrimarioDialogo(
              icon: Icons.login,
              label: "Aceptar",
              onPressed: () async {
                final valido = await ConsultasLoginBD.validarSuperAdmin(controladorPassword.text.trim());
                if (valido) {
                  if (!mounted) return;
                  context.mostrarSnack("Contraseña correcta", esCorrecto: true);
                  Navigator.pop(context, true);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PantallaSuperAdministrador()));
                } else {
                  if (!mounted) return;
                  context.mostrarSnack("Contraseña incorrecta", esCorrecto: false);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  /// ********************************************************
  ///                  --- Construir UI ---
  ///
  /// - Muestra logo con contador de clicks para Super Admin
  /// - Campos de texto para email y contraseña
  /// - Botón de login y enlace "Olvidé la contraseña"
  /// - Maneja estado de carga inicial con CircularProgressIndicator
  /// ********************************************************
  @override
  Widget build(BuildContext context) {
    if (comprobandoLogin) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      body: GestureDetector(
        onTap: () => contadorClicksLogo = 0,
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        contadorClicksLogo++;
                        if (contadorClicksLogo >= 5) {
                          contadorClicksLogo = 0;
                          await mostrarDialogoSuperAdmin();
                        }
                      },
                      child: Image.asset('assets/logo.png', height: 100),
                    ),
                    const SizedBox(height: 30),
                    const Text("Login", style: TextStyle(fontSize: 24)),
                    const SizedBox(height: 20),
                    AppInput(controller: controladorEmail, label: "Email"),
                    const SizedBox(height: 12),
                    AppInput(controller: controladorPassword, label: "Contraseña", obscureText: true),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 200,
                      child: BotonPrimarioDialogo(onPressed: iniciarSesion, label: "Iniciar sesión", icon: Icons.login),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () =>
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const PaginaReseteoPassword())),
                      child: const Text("Olvidé la contraseña"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
