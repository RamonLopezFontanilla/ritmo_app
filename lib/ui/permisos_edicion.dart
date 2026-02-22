import 'package:flutter/material.dart';
import 'package:ritmo_app/consultas_bd/parametros_banda.dart';
import 'package:ritmo_app/utiles/widgets.dart';

/// ****************************************************************************************
/// Página de Permisos de Edición de Músicos
///
/// Permite al administrador:
/// - Configurar qué campos del perfil del músico pueden editarse
/// - Activar o desactivar permisos mediante interruptores (Switch)
/// - Guardar los cambios en base de datos
///
/// Es un [StatefulWidget] porque:
/// - Gestiona estado de carga y guardado
/// - Mantiene en memoria el mapa de permisos
/// - Realiza operaciones asíncronas contra Firebase
/// ****************************************************************************************
class PaginaPermisosEdicion extends StatefulWidget {
  final String bandaId;

  const PaginaPermisosEdicion({super.key, required this.bandaId});

  @override
  State<PaginaPermisosEdicion> createState() => EstadoPaginaPermisosEdicion();
}

/// ****************************************************************************************
/// Estado de la Página de Permisos de Edición
///
/// Contiene la lógica:
/// - Carga inicial de permisos desde base de datos
/// - Gestión dinámica del mapa de permisos
/// - Guardado de cambios
/// - Control de estados de carga y guardado
/// ****************************************************************************************
class EstadoPaginaPermisosEdicion extends State<PaginaPermisosEdicion> {
  // --------------------------------------------------
  // MAPA DE PERMISOS (claveCampo -> permitido)
  // --------------------------------------------------
  Map<String, bool> permisos = {};

  // --------------------------------------------------
  // VARIABLES DE ESTADO
  // --------------------------------------------------
  bool cargando = true;
  bool guardando = false;

  // --------------------------------------------------
  // LISTA DE CAMPOS VISUALES
  // (Orden mostrado en pantalla)
  // --------------------------------------------------
  final campos = [
    'Nombre',
    'Teléfono',
    'Fecha Nacimiento',
    'Fecha Alta',
    'Primera Semana Santa',
    'Instrumento',
    'Categoría',
    'Otros Accesos',
  ];

  // --------------------------------------------------
  // MAPEO: Texto visible -> Clave en base de datos
  // --------------------------------------------------
  final Map<String, String> campoClave = {
    'Nombre': 'nombre',
    'Teléfono': 'telefono',
    'Fecha Nacimiento': 'fechaNacimiento',
    'Fecha Alta': 'fechaAlta',
    'Primera Semana Santa': 'primerAnoSemanaSanta',
    'Instrumento': 'instrumento',
    'Categoría': 'categoria',
    'Otros Accesos': 'otrosAccesos',
  };

  /// ***********************************************
  /// Inicialización
  ///
  /// - Se ejecuta al crear el estado
  /// - Llama a la carga inicial de permisos
  ///************************************************
  @override
  void initState() {
    super.initState();
    cargarPermisos();
  }

  /// *******************************************************************
  /// Cargar permisos desde Firebase
  ///
  /// - Obtiene el mapa de permisos usando
  ///   [ConsultasParametrosBD.obtenerPermisosEdicion]
  /// - Actualiza el estado cuando finaliza
  /// - Muestra mensaje en caso de error
  /// *******************************************************************
  Future<void> cargarPermisos() async {
    try {
      permisos = await ConsultasParametrosBD.obtenerPermisosEdicion(widget.bandaId);
      if (!mounted) return;
      setState(() => cargando = false);
    } catch (_) {
      if (!mounted) return;
      context.mostrarSnack("Error cargando permisos", esCorrecto: false);
      setState(() => cargando = false);
    }
  }

  /// *******************************************************************
  /// Guardar permisos en Firebase
  ///
  /// - Evita múltiples ejecuciones simultáneas
  /// - Guarda el mapa completo de permisos
  /// - Muestra mensaje de éxito o error
  /// - Cierra la pantalla tras guardar correctamente
  /// *******************************************************************
  Future<void> guardarPermisos() async {
    if (guardando) return;

    setState(() => guardando = true);

    try {
      await ConsultasParametrosBD.guardarPermisosEdicion(widget.bandaId, permisos);
      if (!mounted) return;

      context.mostrarSnack("Permisos actualizados", esCorrecto: true);
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      context.mostrarSnack("Error al guardar permisos", esCorrecto: false);
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  /// ********************************************************
  /// Construcción de la interfaz (UI)
  ///
  /// Estructura principal:
  /// 1. AppBar: muestra el título "Permisos de Músicos"
  /// 2. Cuerpo:
  ///    - Si está cargando los permisos, muestra un indicador circular de progreso
  ///    - Si los datos ya están listos, muestra una lista de interruptores (SwitchListTile) para cada campo:
  ///       a) El texto visible del campo
  ///       b) El estado actual del permiso (activado/desactivado)
  ///       c) Permite modificar el valor directamente desde la UI
  /// 3. Botón de guardado en la parte inferior:
  ///    - Solo habilitado si no se está cargando ni guardando
  ///    - Al pulsarlo, guarda los cambios en Firebase y cierra la pantalla
  ///
  /// Permite al administrador:
  /// - Visualizar permisos actuales
  /// - Activar o desactivar permisos de edición
  /// - Guardar los cambios de forma segura
  /// ********************************************************
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ----------------------------
      //         BARRA SUPERIOR
      // ----------------------------
      appBar: AppBar(title: const Text("Permisos de Músicos")),
      // ----------------------------
      //       CUERPO PRINCIPAL
      // ----------------------------
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: campos.map((campo) {
                final key = campoClave[campo]!;
                return SwitchListTile(
                  title: Text(campo),
                  value: permisos[key] ?? false,
                  onChanged: (v) => setState(() => permisos[key] = v),
                );
              }).toList(),
            ),
      // ----------------------------
      //       BOTÓN GUARDAR
      // ----------------------------
      bottomNavigationBar: BotonGuardar(enabled: !cargando && !guardando, onPressed: guardarPermisos),
    );
  }
}
