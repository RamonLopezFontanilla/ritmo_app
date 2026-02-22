import 'package:flutter/material.dart';
import 'package:ritmo_app/consultas_bd/bandas.dart';
import 'package:ritmo_app/modelos/banda.dart';
import 'package:ritmo_app/utiles/validadores.dart';
import 'package:ritmo_app/utiles/widgets.dart';

/// ****************************************************************************************
/// Página de edición de Datos de la Banda
///
/// Permite al administrador:
/// - Visualizar los datos actuales de la banda
/// - Modificar la información fiscal y de contacto
/// - Validar los campos antes de guardar
/// - Guardar los cambios en base de datos
///
/// Es un [StatefulWidget] porque:
/// - Se cargan datos asíncronos desde BD
/// - Se gestionan estados de carga y guardado
/// - Se utilizan controladores de formulario
/// ****************************************************************************************
class PaginaDatosBanda extends StatefulWidget {
  final String bandaId;
  const PaginaDatosBanda({super.key, required this.bandaId});

  @override
  State<PaginaDatosBanda> createState() => EstadoPaginaDatosBanda();
}

/// ****************************************************************************************
/// Estado de la página de Datos de la Banda
///
/// Contiene toda la lógica:
/// - Carga de datos desde base de datos
/// - Inicialización de controladores
/// - Validación de formulario
/// - Guardado de cambios
/// - Control de estados (cargando / grabando)
/// ****************************************************************************************
class EstadoPaginaDatosBanda extends State<PaginaDatosBanda> {
  // Modelo Banda actual cargado desde base de datos
  Banda? banda;

  /// --------------------------------------------------
  /// Controladores de los campos del formulario
  /// Permiten:
  /// - Mostrar datos iniciales
  /// - Leer valores modificados
  /// --------------------------------------------------
  final TextEditingController controladorNombre = TextEditingController();
  final TextEditingController controladorAdministradorEmail = TextEditingController();
  final TextEditingController controladorCif = TextEditingController();
  final TextEditingController controladorDireccion = TextEditingController();
  final TextEditingController controladorLocalidad = TextEditingController();
  final TextEditingController controladorProvincia = TextEditingController();
  final TextEditingController controladorCodPostal = TextEditingController();
  final TextEditingController controladorTelefono = TextEditingController();
  final TextEditingController controladorEmail = TextEditingController();

  bool cargando = true;
  bool grabando = false;

  /// ***********************************************
  /// Inicialización
  ///
  /// Se ejecuta al crear la pantalla.
  /// Carga los datos de la banda.
  /// ***********************************************
  @override
  void initState() {
    super.initState();
    cargarDatosBanda();
  }

  /// ***********************************************
  /// Liberación de memoria
  ///
  /// Se libera el controlador de novedades para evitar fugas de memoria.
  ///************************************************
  @override
  void dispose() {
    controladorNombre.dispose();
    controladorAdministradorEmail.dispose();
    controladorCif.dispose();
    controladorDireccion.dispose();
    controladorLocalidad.dispose();
    controladorProvincia.dispose();
    controladorCodPostal.dispose();
    controladorTelefono.dispose();
    controladorEmail.dispose();
    super.dispose();
  }

  /// *******************************************************************
  /// Cargar datos de la banda desde base de datos
  ///
  /// - Obtiene la banda usando el bandaId recibido [ConsultasBandasBD.obtenerDatosBanda].
  /// - Inicializa el modelo Banda
  /// - Rellena los controladores del formulario
  /// *******************************************************************
  Future<void> cargarDatosBanda() async {
    setState(() => cargando = true);

    try {
      final bandaDoc = await ConsultasBandasBD.obtenerDatosBanda(widget.bandaId);

      if (bandaDoc == null) {
        if (!mounted) return;
        context.mostrarSnack("No se encontró la banda", esCorrecto: false);
        return;
      }

      // Crear modelo Banda correctamente
      banda = Banda.fromMap(bandaDoc.id, bandaDoc.data() as Map<String, dynamic>);

      // Inicializar controladores con datos de Banda
      controladorNombre.text = banda!.nombre;
      controladorAdministradorEmail.text = banda!.administradorEmail;
      controladorCif.text = banda!.cif;
      controladorDireccion.text = banda!.direccion;
      controladorLocalidad.text = banda!.localidad;
      controladorProvincia.text = banda!.provincia;
      controladorCodPostal.text = banda!.cPostal;
      controladorTelefono.text = banda!.telefono;
      controladorEmail.text = banda!.email;
    } catch (e) {
      if (!mounted) return;
      context.mostrarSnack("Error al cargar datos de la banda", esCorrecto: false);
    } finally {
      setState(() => cargando = false);
    }
  }

  /// *******************************************************************
  /// Validar campos del formulario
  ///
  /// Comprueba:
  /// - Campos obligatorios
  /// - Formato de CIF (DNI/NIE)
  /// - Código postal válido
  /// - Teléfono válido
  ///
  /// Devuelve true si todo es correcto
  /// *******************************************************************
  bool validarCampos() {
    if (controladorCif.text.isNotEmpty &&
        !esDniValido(controladorCif.text.trim()) &&
        !esNieValido(controladorCif.text.trim())) {
      context.mostrarSnack("El CIF no es válido", esCorrecto: false);
      return false;
    }
    if (controladorDireccion.text.trim().isEmpty) {
      context.mostrarSnack("La dirección es obligatoria", esCorrecto: false);
      return false;
    }
    if (controladorLocalidad.text.trim().isEmpty) {
      context.mostrarSnack("La localidad es obligatoria", esCorrecto: false);
      return false;
    }
    if (controladorProvincia.text.trim().isEmpty) {
      context.mostrarSnack("La provincia es obligatoria", esCorrecto: false);
      return false;
    }
    if (controladorCodPostal.text.isEmpty) {
      context.mostrarSnack("El código postal es obligatorio", esCorrecto: false);
      return false;
    }
    if (!esCodigoPostalValido(controladorCodPostal.text.trim())) {
      context.mostrarSnack("El código postal no es válido", esCorrecto: false);
      return false;
    }
    if (controladorTelefono.text.isNotEmpty && !esTelefonoValido(controladorTelefono.text.trim())) {
      context.mostrarSnack("El teléfono no es válido", esCorrecto: false);
      return false;
    }
    return true;
  }

  /// *******************************************************************
  /// Guardar datos de la banda
  ///
  /// - Valida los campos
  /// - Crea una copia del modelo con los cambios
  /// - Guarda en base de datos con [ConsultasBandasBD.guardarBanda]
  /// - Muestra mensaje de confirmación
  /// - Devuelve true a la pantalla anterior
  /// *******************************************************************
  Future<void> guardarDatosBanda() async {
    if (banda == null || !validarCampos()) return;

    FocusScope.of(context).unfocus();
    setState(() => grabando = true);

    try {
      // Crear copia del modelo con los cambios
      final bandaActualizada = banda!.copyWith(
        nombre: controladorNombre.text.trim(),
        administradorEmail: controladorAdministradorEmail.text.trim(),
        cif: controladorCif.text.trim(),
        direccion: controladorDireccion.text.trim(),
        localidad: controladorLocalidad.text.trim(),
        provincia: controladorProvincia.text.trim(),
        cPostal: controladorCodPostal.text.trim(),
        telefono: controladorTelefono.text.trim(),
        email: controladorEmail.text.trim(),
      );

      await ConsultasBandasBD.guardarBanda(bandaActualizada);

      if (!mounted) return;
      context.mostrarSnack("Datos de la banda guardados correctamente", esCorrecto: true);
      Navigator.pop(context, true);
    } catch (e) {
      context.mostrarSnack("Error al guardar los datos: $e", esCorrecto: false);
    } finally {
      if (mounted) setState(() => grabando = false);
    }
  }

  /// ********************************************************
  ///                  --- Construir UI ---
  ///
  /// Componentes:
  /// - AppBar
  /// - Campos del formulario con controladores
  /// - Botón de guardar
  /// ********************************************************
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ----------------------------
      //         BARRA SUPERIOR
      // ----------------------------
      appBar: AppBar(title: const Text("Editar datos de la banda")),

      // ----------------------------
      //       CUERPO PRINCIPAL
      // ----------------------------
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CampoEtiqueta(label: "Nombre de la banda", value: controladorNombre.text),
                  const SizedBox(height: 8),
                  CampoEtiqueta(value: controladorAdministradorEmail.text, label: "Email de administrador"),
                  const SizedBox(height: 8),
                  AppInput(controller: controladorCif, label: "CIF"),
                  const SizedBox(height: 8),
                  AppInput(controller: controladorDireccion, label: "Dirección"),
                  const SizedBox(height: 8),
                  AppInput(controller: controladorLocalidad, label: "Localidad"),
                  const SizedBox(height: 8),
                  AppInput(controller: controladorProvincia, label: "Provincia"),
                  const SizedBox(height: 8),
                  AppInput(controller: controladorCodPostal, label: "Código Postal"),
                  const SizedBox(height: 8),
                  AppInput(controller: controladorTelefono, label: "Teléfono"),
                  const SizedBox(height: 8),
                  AppInput(controller: controladorEmail, label: "Email contacto"),
                  const SizedBox(height: 16),
                ],
              ),
            ),

      // ----------------------------
      //       BOTÓN GUARDAR
      // ----------------------------
      bottomNavigationBar: BotonGuardar(enabled: !cargando && !grabando, onPressed: guardarDatosBanda),
    );
  }
}
