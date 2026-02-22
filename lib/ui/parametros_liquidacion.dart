import 'package:flutter/material.dart';
import 'package:ritmo_app/consultas_bd/liquidaciones.dart';
import 'package:ritmo_app/modelos/parametros_liquidacion.dart';
import 'package:ritmo_app/utiles/widgets.dart';

/// ****************************************************************************************
/// Página de Parámetros de Liquidación
///
/// Permite al administrador:
/// - Configurar la cantidad total a repartir
/// - Visualizar el total de puntos acumulados
/// - Definir puntos por tipo de evento
/// - Definir puntos por antigüedad
/// - Guardar parámetros y recalcular automáticamente la liquidación
///
/// Es un [StatefulWidget] porque:
/// - Carga datos desde base de datos
/// - Gestiona múltiples TextEditingController dinámicos
/// - Controla estado de carga
/// - Ejecuta proceso de guardado y recálculo
/// ****************************************************************************************
class PaginaParametrosLiquidacion extends StatefulWidget {
  final String bandaId;
  final String temporadaSeleccionadaId;

  const PaginaParametrosLiquidacion({super.key, required this.bandaId, required this.temporadaSeleccionadaId});

  @override
  State<PaginaParametrosLiquidacion> createState() => EstadoPaginaParametrosLiquidacion();
}

/// ****************************************************************************************
/// Estado de la página de Parámetros de Liquidación
///
/// Contiene la lógica:
/// - Carga inicial de parámetros
/// - Inicialización de controladores dinámicos
/// - Liberación de memoria
/// - Construcción del modelo actualizado
/// - Guardado y recálculo de liquidaciones
/// ****************************************************************************************
class EstadoPaginaParametrosLiquidacion extends State<PaginaParametrosLiquidacion> {
  bool cargando = true;

  final TextEditingController controladorCantidadRepartir = TextEditingController(text: "0");
  final TextEditingController controladorTotalPuntos = TextEditingController(text: "0");

  late ParametrosLiquidacion parametrosLiquidacion;

  final Map<String, TextEditingController> controladorPuntos = {};

  final List<List<String>> filasLiquidacion = [
    ["Ensayo puntual", "puntosEnsayoPuntual", "puntosAntigEP"],
    ["Ensayo retrasado", "puntosEnsayoRetraso", "puntosAntigER"],
    ["Actuación puntual", "puntosActuacionPuntual", "puntosAntigAP"],
    ["Actuación retrasada", "puntosActuacionRetrasada", "puntosAntigAR"],
    ["Semana Sta. puntual", "puntosSSPuntual", "puntosAntigSSP"],
    ["Semana Sta. retrasada", "puntosSSRetraso", "puntosAntigSSR"],
  ];

  /// ***********************************************
  /// Inicialización
  ///
  /// Se ejecuta al crear el estado.
  /// Lanza la carga inicial de parámetros.
  /// ***********************************************
  @override
  void initState() {
    super.initState();
    cargarDatosLiquidacion();
  }

  /// ***********************************************
  /// Liberación de memoria
  ///
  /// Se eliminan todos los TextEditingController
  /// para evitar fugas de memoria.
  /// ***********************************************
  @override
  void dispose() {
    controladorCantidadRepartir.dispose();
    controladorTotalPuntos.dispose();
    for (var c in controladorPuntos.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// *******************************************************************
  /// Cargar datos de liquidación
  ///
  /// Flujo:
  /// - Obtiene parámetros desde base de datos
  /// - Inicializa controladores con valores actuales
  /// - Desactiva estado de carga
  /// *******************************************************************
  Future<void> cargarDatosLiquidacion() async {
    try {
      parametrosLiquidacion = await ConsultasLiquidacionesBD.obtenerParametros(
        widget.bandaId,
        widget.temporadaSeleccionadaId,
      );

      controladorCantidadRepartir.text = parametrosLiquidacion.cantidadRepartir.toString();
      controladorTotalPuntos.text = parametrosLiquidacion.totalPuntosLiquidacion.toString();

      /// Inicializar controllers usando el modelo
      controladorPuntos["puntosEnsayoPuntual"] = TextEditingController(
        text: parametrosLiquidacion.puntosEnsayoPuntual.toString(),
      );
      controladorPuntos["puntosEnsayoRetraso"] = TextEditingController(
        text: parametrosLiquidacion.puntosEnsayoRetraso.toString(),
      );
      controladorPuntos["puntosActuacionPuntual"] = TextEditingController(
        text: parametrosLiquidacion.puntosActuacionPuntual.toString(),
      );
      controladorPuntos["puntosActuacionRetrasada"] = TextEditingController(
        text: parametrosLiquidacion.puntosActuacionRetrasada.toString(),
      );
      controladorPuntos["puntosSSPuntual"] = TextEditingController(
        text: parametrosLiquidacion.puntosSSPuntual.toString(),
      );
      controladorPuntos["puntosSSRetraso"] = TextEditingController(
        text: parametrosLiquidacion.puntosSSRetraso.toString(),
      );

      controladorPuntos["puntosAntigAP"] = TextEditingController(text: parametrosLiquidacion.puntosAntigAP.toString());
      controladorPuntos["puntosAntigAR"] = TextEditingController(text: parametrosLiquidacion.puntosAntigAR.toString());
      controladorPuntos["puntosAntigEP"] = TextEditingController(text: parametrosLiquidacion.puntosAntigEP.toString());
      controladorPuntos["puntosAntigER"] = TextEditingController(text: parametrosLiquidacion.puntosAntigER.toString());
      controladorPuntos["puntosAntigSSP"] = TextEditingController(
        text: parametrosLiquidacion.puntosAntigSSP.toString(),
      );

      controladorPuntos["puntosAntigSSR"] = TextEditingController(
        text: parametrosLiquidacion.puntosAntigSSR.toString(),
      );
    } catch (e) {
      if (!mounted) return;
      context.mostrarSnack("Error cargando datos: $e", esCorrecto: false);
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  /// *******************************************************************
  /// Guardar parámetros y recalcular liquidación
  ///
  /// Flujo:
  /// - Construye objeto ParametrosLiquidacion actualizado
  /// - Guarda parámetros en base de datos
  /// - Recalcula liquidación de todos los músicos
  /// - Muestra mensaje de éxito o error
  /// *******************************************************************
  Future<void> guardarParametrosYLiquidacion() async {
    setState(() => cargando = true);

    try {
      final parametrosActualizados = ParametrosLiquidacion(
        cantidadRepartir: int.tryParse(controladorCantidadRepartir.text) ?? 0,
        totalPuntosLiquidacion: int.tryParse(controladorTotalPuntos.text) ?? 0,
        visibleMusico: parametrosLiquidacion.visibleMusico,
        puntosActuacionPuntual: int.tryParse(controladorPuntos["puntosActuacionPuntual"]?.text ?? "0") ?? 0,
        puntosActuacionRetrasada: int.tryParse(controladorPuntos["puntosActuacionRetrasada"]?.text ?? "0") ?? 0,
        puntosAntigAP: int.tryParse(controladorPuntos["puntosAntigAP"]?.text ?? "0") ?? 0,
        puntosAntigAR: int.tryParse(controladorPuntos["puntosAntigAR"]?.text ?? "0") ?? 0,
        puntosAntigEP: int.tryParse(controladorPuntos["puntosAntigEP"]?.text ?? "0") ?? 0,
        puntosAntigER: int.tryParse(controladorPuntos["puntosAntigER"]?.text ?? "0") ?? 0,
        puntosAntigSSP: int.tryParse(controladorPuntos["puntosAntigSSP"]?.text ?? "0") ?? 0,
        puntosAntigSSR: int.tryParse(controladorPuntos["puntosAntigSSR"]?.text ?? "0") ?? 0,
        puntosEnsayoPuntual: int.tryParse(controladorPuntos["puntosEnsayoPuntual"]?.text ?? "0") ?? 0,
        puntosEnsayoRetraso: int.tryParse(controladorPuntos["puntosEnsayoRetraso"]?.text ?? "0") ?? 0,
        puntosSSPuntual: int.tryParse(controladorPuntos["puntosSSPuntual"]?.text ?? "0") ?? 0,
        puntosSSRetraso: int.tryParse(controladorPuntos["puntosSSRetraso"]?.text ?? "0") ?? 0,
        valorPunto: 0,
      );

      // Guardar parámetros
      await ConsultasLiquidacionesBD.guardarParametros(
        widget.bandaId,
        widget.temporadaSeleccionadaId,
        parametrosActualizados,
      );

      // Recalcular liquidación de todos los músicos
      await ConsultasLiquidacionesBD.recalcularLiquidacion(widget.bandaId, widget.temporadaSeleccionadaId);

      if (!mounted) return;

      context.mostrarSnack("Parámetros y liquidación actualizados correctamente", esCorrecto: true);
      Navigator.pop(context, true);
    } catch (e) {
      context.mostrarSnack("Error guardando datos: $e", esCorrecto: false);
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  /// ********************************************************
  ///                  --- Construir UI ---
  ///
  /// Estructura:
  /// - AppBar fija
  /// - Indicador de carga
  /// - Campo cantidad a repartir
  /// - Campo total puntos (solo lectura)
  /// - Tabla editable de puntos y antigüedad
  /// - Botón inferior Guardar
  ///
  /// La tabla se construye dinámicamente usando:
  /// - Lista estructural filasLiquidacion
  /// - Mapa de controladores controladorPuntos
  /// ********************************************************
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ----------------------------
      //         BARRA SUPERIOR
      // ----------------------------
      appBar: AppBar(title: const Text("Parámetros de Liquidación")),

      // ----------------------------
      //       CUERPO PRINCIPAL
      // ----------------------------
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  AppInput(
                    controller: controladorCantidadRepartir,
                    label: "Cantidad a repartir (€)",
                    keyboardType: TextInputType.number,
                  ),
                  CampoEtiqueta(value: controladorTotalPuntos.text, label: "Total puntos"),
                  const SizedBox(height: 16),
                  Table(
                    border: TableBorder.all(color: Colors.grey.shade300),
                    columnWidths: const {
                      0: FlexColumnWidth(3), // Concepto
                      1: FlexColumnWidth(1), // Ptos.
                      2: FlexColumnWidth(1), // Antig.
                    },
                    children: [
                      const TableRow(
                        decoration: BoxDecoration(color: Colors.blueGrey),
                        children: [
                          Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              "Concepto",
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              "Ptos.",
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              "Antig.",
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      ...filasLiquidacion.map((fila) {
                        final concepto = fila[0];
                        final campoPuntos = fila[1];
                        final campoAntig = fila[2];
                        return TableRow(
                          children: [
                            Padding(padding: const EdgeInsets.all(8.0), child: Text(concepto)),
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: TextFormField(
                                controller: controladorPuntos[campoPuntos],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: TextFormField(
                                controller: controladorPuntos[campoAntig],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),

      // ----------------------------
      //       BOTÓN GUARDAR
      // ----------------------------
      bottomNavigationBar: BotonGuardar(enabled: !cargando, onPressed: guardarParametrosYLiquidacion),
    );
  }
}
