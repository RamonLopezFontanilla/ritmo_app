import 'package:flutter/material.dart';
import 'package:ritmo_app/consultas_bd/bandas.dart';
import 'package:ritmo_app/consultas_bd/parametros_banda.dart';
import 'package:ritmo_app/ui/permisos_edicion.dart';
import 'package:ritmo_app/utiles/widgets.dart';

/// ****************************************************************************************
/// Página de Parámetros de la Banda
///
/// Permite al administrador:
/// - Visualizar los parámetros configurados de la banda
/// - Modificar distancia máxima permitida
/// - Modificar retraso permitido
/// - Configurar la ruta de partituras
/// - Acceder a la gestión de permisos de edición
///
/// Es un [StatefulWidget] porque:
/// - Gestiona el estado de carga (loading)
/// - Controla los valores de los TextEditingController
/// - Ejecuta operaciones asíncronas contra Firebase
/// - Maneja validaciones y guardado de datos
/// ****************************************************************************************
class PaginaParametrosBanda extends StatefulWidget {
  final String bandaId;
  const PaginaParametrosBanda({super.key, required this.bandaId});

  @override
  State<PaginaParametrosBanda> createState() => EstadoPaginaParametrosBanda();
}

/// ****************************************************************************************
/// Estado de la Página de Parámetros de la Banda
///
/// Contiene la lógica:
/// - Carga inicial de parámetros desde base de datos
/// - Gestión de controladores de texto
/// - Guardado de cambios
/// - Control de estado de carga
/// - Navegación hacia pantalla de permisos
/// ****************************************************************************************
class EstadoPaginaParametrosBanda extends State<PaginaParametrosBanda> {
  final TextEditingController controladorDistancia = TextEditingController();
  final TextEditingController controladorRetraso = TextEditingController();
  final TextEditingController controladorRuta = TextEditingController();

  bool cargando = true;
  String bandaId = "";

  /// ***********************************************
  /// Inicialización
  ///
  /// - Obtiene el bandaId recibido
  /// - Carga los parámetros desde Firebase
  ///************************************************
  @override
  void initState() {
    super.initState();
    bandaId = widget.bandaId;
    cargarParametros();
  }

  /// ***********************************************
  /// Liberación de memoria
  ///
  /// Se libera el controlador de novedades para evitar fugas de memoria.
  ///************************************************
  @override
  void dispose() {
    controladorDistancia.dispose();
    controladorRetraso.dispose();
    controladorRuta.dispose();
    super.dispose();
  }

  /// *******************************************************************
  /// Cargar parámetros desde Firebase
  ///
  /// - Activa estado de carga
  /// - Obtiene los datos usando [ConsultasParametrosBD.obtenerParametrosBanda]
  /// - Rellena los controladores con los valores obtenidos
  /// - Muestra error si algo falla
  /// *******************************************************************
  Future<void> cargarParametros() async {
    setState(() => cargando = true);

    try {
      final parametros = await ConsultasParametrosBD.obtenerParametrosBanda(bandaId);
      if (!mounted) return;

      if (parametros == null) {
        context.mostrarSnack("No se encontraron parámetros", esCorrecto: false);
        return;
      }

      controladorDistancia.text = (parametros['distancia'] ?? '').toString();
      controladorRetraso.text = (parametros['retraso'] ?? '').toString();
      controladorRuta.text = parametros['rutaPartituras'] ?? '';
    } catch (e) {
      if (!mounted) return;
      context.mostrarSnack("Error al cargar parámetros", esCorrecto: false);
    } finally {
      if (mounted) {
        setState(() => cargando = false);
      }
    }
  }

  /// *******************************************************************
  /// Guardar parámetros en Firebase
  ///
  /// - Valida que no esté cargando
  /// - Convierte valores numéricos
  /// - Guarda usando [ConsultasBandasBD.guardarParametrosBanda]
  /// - Muestra mensaje de éxito o error
  /// - Cierra la pantalla tras guardar correctamente
  /// *******************************************************************
  Future<void> guardarParametros() async {
    if (bandaId.isEmpty || cargando) return;

    setState(() => cargando = true);

    try {
      await ConsultasBandasBD.guardarParametrosBanda(
        bandaId: bandaId,
        distancia: int.tryParse(controladorDistancia.text) ?? 0,
        retraso: int.tryParse(controladorRetraso.text) ?? 0,
        rutaPartituras: controladorRuta.text.trim(),
      );

      if (!mounted) return;

      context.mostrarSnack("Parámetros guardados correctamente", esCorrecto: true);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      context.mostrarSnack("Error al guardar los parámetros", esCorrecto: false);
    } finally {
      if (mounted) {
        setState(() => cargando = false);
      }
    }
  }

  /// ********************************************************
  ///                  --- Construir UI ---
  ///
  /// Componentes:
  /// - AppBar
  /// - Campos de edición de parámetros
  /// - Botón de acceso a permisos de edición
  /// - Botón guardar
  /// ********************************************************
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ----------------------------
      //         BARRA SUPERIOR
      // ----------------------------
      appBar: AppBar(title: const Text("Parámetros de Banda")),

      // ----------------------------
      //       CUERPO PRINCIPAL
      // ----------------------------
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  AppInput(
                    controller: controladorDistancia,
                    keyboardType: TextInputType.number,
                    label: "Distancia máxima (metros)",
                  ),

                  const SizedBox(height: 16),

                  AppInput(
                    controller: controladorRetraso,
                    keyboardType: TextInputType.number,
                    label: "Retraso permitido (minutos)",
                  ),

                  const SizedBox(height: 16),

                  AppInput(controller: controladorRuta, label: "Ruta de partituras"),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: BotonAPantalla(
                      label: "CONFIGURAR PERMISOS",
                      icon: Icons.security,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PaginaPermisosEdicion(bandaId: bandaId)),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),

      // ----------------------------
      //       BOTÓN GUARDAR
      // ----------------------------
      bottomNavigationBar: BotonGuardar(enabled: !cargando, onPressed: guardarParametros),
    );
  }
}
