import 'package:flutter/material.dart';
import 'package:ritmo_app/consultas_bd/login.dart';
import 'package:ritmo_app/utiles/widgets.dart';
import 'login.dart';

/// ********************************************************
/// Página principal de reseteo contraseña
///
/// Permite al usuario solicitar el envío de un correo electrónico para restablecer su contraseña en caso de haberla olvidado.
/// Esta clase es inmutable y delega toda la lógica al estado [EstadoPaginaReseteoPassword].
/// ********************************************************
class PaginaReseteoPassword extends StatefulWidget {
  const PaginaReseteoPassword({super.key});

  @override
  State<PaginaReseteoPassword> createState() => EstadoPaginaReseteoPassword();
}

/// ********************************************************
/// Estado de la página de reseteo contraseña (Guarda todos los datos que cambian)
///
/// Contiene:
/// - El controlador del campo email.
/// - La lógica de validación.
/// - La llamada a base de datos.
/// - La construcción de la interfaz gráfica.
/// ********************************************************
class EstadoPaginaReseteoPassword extends State<PaginaReseteoPassword> {
  final controladorEmail = TextEditingController();

  /// ********************************************************
  /// Liberación de recursos
  ///
  /// Es importante liberar los controladores para evitar fugas de memoria.
  /// ********************************************************
  @override
  void dispose() {
    controladorEmail.dispose();
    super.dispose();
  }

  /// ********************************************************
  /// Resetear contraseña
  ///
  /// Pasos:
  /// 1. Obtiene el email introducido por el usuario.
  /// 2. Verifica que no esté vacío.
  /// 3. Llama a [ConsultasLoginBD.enviarResetPassword].
  /// 4. Muestra un mensaje informativo mediante [mostrarSnackBar].
  ///
  /// Seguridad:
  /// - El mensaje mostrado no confirma si el correo existe, evitando así filtraciones de información.
  /// ********************************************************
  Future<void> resetearPassword() async {
    final email = controladorEmail.text.trim();

    if (email.isEmpty) {
      context.mostrarSnack("Por favor introduce tu correo electrónico.", esCorrecto: false);
      return;
    }

    try {
      await ConsultasLoginBD.enviarResetPassword(email);
      if (!mounted) return;
      context.mostrarSnack("Si el correo está registrado, recibirás un email con instrucciones.", esCorrecto: true);
    } catch (e) {
      final mensaje = e is Exception ? e.toString().replaceFirst("Exception: ", "") : "Error inesperado";
      context.mostrarSnack(mensaje, esCorrecto: false);
    }
  }

  /// ********************************************************
  ///                  --- Construir UI ---
  ///
  /// - Logo de la app
  /// - Título
  /// - Campo de email
  /// - Botón "Enviar correo de recuperación"
  /// - Botón "Volver al login"
  /// ********************************************************
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ----------------------------
      //       CUERPO PRINCIPAL
      // ----------------------------
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo.png', height: 100),
            const SizedBox(height: 40),
            const Text("Olvidé la contraseña", style: TextStyle(fontSize: 24)),
            const SizedBox(height: 20),
            AppInput(controller: controladorEmail, label: "Email"),
            const SizedBox(height: 20),

            // Botón reseteo contraseña
            BotonPrimarioDialogo(
              onPressed: resetearPassword,
              label: "Enviar correo de recuperación",
              icon: Icons.email_outlined,
            ),

            const SizedBox(height: 35),

            // Botón volver a login
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaginaLogin())),
              child: const Text("Volver al login"),
            ),
          ],
        ),
      ),
    );
  }
}
