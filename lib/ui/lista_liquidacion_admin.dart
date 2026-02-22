import 'package:flutter/material.dart';
import 'package:ritmo_app/consultas_bd/liquidaciones.dart';
import 'package:ritmo_app/consultas_bd/temporada.dart';
import 'package:ritmo_app/consultas_bd/usuarios.dart';
import 'package:ritmo_app/modelos/musico_liquidacion.dart';
import 'package:ritmo_app/modelos/parametros_liquidacion.dart';
import 'parametros_liquidacion.dart';
import 'datos_liquidacion_musico.dart';

/// ****************************************************************
/// Página principal de administración de liquidación.
///
/// Permite:
/// - Visualizar la liquidación de una temporada.
/// - Activar o desactivar visibilidad para músicos.
/// - Incluir o excluir músicos en la liquidación.
/// - Modificar coeficiente de antigüedad individual.
/// - Ver puntos totales dinámicos.
/// - Acceder al detalle individual de cada músico.
/// - Recalcular automáticamente la liquidación tras cambios.
///
/// Es un [StatefulWidget] porque:
/// - Carga datos asíncronos iniciales.
/// - Mantiene estado de carga.
/// - Gestiona parámetros modificables.
/// - Maneja controladores dinámicos por músico.
/// - Reacciona a streams en tiempo real.
/// ****************************************************************
class PaginaLiquidacionAdmin extends StatefulWidget {
  final String bandaId;
  final String temporadaSeleccionadaId;

  const PaginaLiquidacionAdmin({super.key, required this.bandaId, required this.temporadaSeleccionadaId});

  @override
  State<PaginaLiquidacionAdmin> createState() => EstadoPaginaLiquidacionAdmin();
}

/// ****************************************************************
/// Estado de la página de generación de liquidación.
///
/// Responsabilidades:
/// - Cargar nombre de temporada.
/// - Obtener parámetros de liquidación.
/// - Sincronizar músicos activos.
/// - Escuchar cambios en liquidación vía StreamBuilder.
/// - Calcular total de puntos dinámicamente.
/// - Persistir cambios en inclusión y antigüedad.
/// - Recalcular liquidación tras modificaciones.
/// ****************************************************************
class EstadoPaginaLiquidacionAdmin extends State<PaginaLiquidacionAdmin> {
  bool loading = true;
  bool visibleMusicos = true;

  late ParametrosLiquidacion parametrosLiquidacion;

  final Map<String, TextEditingController> controladorAntiguedad = {};

  String? nombreTemporada;

  /// ***********************************************
  /// Inicialización
  /// - Carga datos iniciales.
  /// - Prepara parámetros.
  /// ***********************************************
  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  /// ***********************************************
  /// Cargar datos iniciales
  ///
  /// Flujo:
  /// - Obtener nombre de temporada.
  /// - Obtener parámetros de liquidación.
  /// - Sincronizar usuarios activos.
  /// - Desactivar estado loading.
  /// ***********************************************
  Future<void> cargarDatos() async {
    nombreTemporada = await ConsultasTemporadasBD.obtenerNombreTemporada(
      widget.bandaId,
      widget.temporadaSeleccionadaId,
    );

    parametrosLiquidacion = await ConsultasLiquidacionesBD.obtenerParametros(
      widget.bandaId,
      widget.temporadaSeleccionadaId,
    );

    visibleMusicos = parametrosLiquidacion.visibleMusico;
    ConsultasLiquidacionesBD.sincronizarUsuariosActivos(widget.bandaId, widget.temporadaSeleccionadaId);
    setState(() => loading = false);
  }

  /// ***********************************************
  ///              --- Construcción UI ---
  ///
  /// Estructura:
  /// - AppBar con acceso a parámetros.
  /// - Switch de visibilidad global.
  /// - Stream en tiempo real de músicos.
  /// - Cálculo dinámico de total de puntos.
  /// - Lista de tarjetas individuales:
  ///     - Nombre
  ///     - Puntos
  ///     - Inclusión en liquidación
  ///     - Coeficiente de antigüedad editable
  ///     - Importe final
  /// ***********************************************
  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      // ----------------------------
      //         BARRA SUPERIOR
      // ----------------------------
      appBar: AppBar(
        title: Text('Liquidación $nombreTemporada'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              // Abrir parámetros y actualizar liquidación al regresar
              final actualizado = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PaginaParametrosLiquidacion(
                    bandaId: widget.bandaId,
                    temporadaSeleccionadaId: widget.temporadaSeleccionadaId,
                  ),
                ),
              );

              if (actualizado == true) {
                await ConsultasLiquidacionesBD.recalcularLiquidacion(widget.bandaId, widget.temporadaSeleccionadaId);
              }
            },
          ),
        ],
      ),
      // ----------------------------
      //       CUERPO PRINCIPAL
      // ----------------------------
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            // ----------------------------
            //     OPCIONES DE CABECERA
            // ----------------------------
            child: Row(
              children: [
                const Expanded(
                  child: Text('Acceso a músicos', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Transform.scale(
                  scale: 0.7,
                  child: Switch(
                    value: visibleMusicos,
                    onChanged: (value) async {
                      setState(() => visibleMusicos = value);

                      parametrosLiquidacion = parametrosLiquidacion.copyWith(visibleMusico: value);

                      await ConsultasLiquidacionesBD.guardarParametros(
                        widget.bandaId,
                        widget.temporadaSeleccionadaId,
                        parametrosLiquidacion,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(),

          // --------------------------------------------
          //    OBTENER MÚSICOS PARA LIQUIDACIÓN
          // --------------------------------------------
          Expanded(
            child: StreamBuilder<List<LiquidacionMusico>>(
              stream: ConsultasLiquidacionesBD.streamMusicosLiquidacion(widget.bandaId, widget.temporadaSeleccionadaId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final listaMusicos = snapshot.data!;

                // --- Calcular total de puntos dinámicamente ---
                final totalPuntos = listaMusicos
                    .where((m) => m.incluidoEnLiquidacion)
                    .fold<int>(
                      0,
                      (sum, m) => sum + ConsultasLiquidacionesBD.calcularPuntosMusico(m, parametrosLiquidacion),
                    );

                return Column(
                  // ---------------------------
                  //   TOTAL DE PUNTOS
                  // ---------------------------
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text('Total de puntos: $totalPuntos', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    // ---------------------------
                    //   MOSTRAR LISTA DE MÚSICOS
                    // ---------------------------
                    Expanded(
                      child: ListView.builder(
                        itemCount: listaMusicos.length,
                        itemBuilder: (_, i) {
                          final musico = listaMusicos[i];
                          final incluido = musico.incluidoEnLiquidacion;

                          // Controlador de antigüedad
                          controladorAntiguedad.putIfAbsent(
                            musico.id,
                            () => TextEditingController(text: musico.puntosAntiguedad.toString()),
                          );
                          final controller = controladorAntiguedad[musico.id]!;
                          if (controller.text != musico.puntosAntiguedad.toString()) {
                            controller.text = musico.puntosAntiguedad.toString();
                          }

                          // --------------------------------
                          //        ACCIÓN TARJETA MÚSICO
                          // -------------------------------
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PaginaLiquidacionMusico(
                                    esAdmin: true,
                                    bandaId: widget.bandaId,
                                    temporadaSeleccionadaId: widget.temporadaSeleccionadaId,
                                    musicoId: musico.id,
                                  ),
                                ),
                              );
                            },
                            // --------------------------------
                            //        TARJETA MÚSICO
                            // -------------------------------
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                border: Border(left: BorderSide(color: incluido ? Colors.green : Colors.red, width: 6)),
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Nombre del músico en negrita
                                  FutureBuilder<String>(
                                    future: ConsultasUsuariosBD.obtenerNombreMusico(musico.id),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                        return const Text('...', style: TextStyle(fontWeight: FontWeight.bold));
                                      }
                                      if (snapshot.hasError) {
                                        return const Text('Error', style: TextStyle(fontWeight: FontWeight.bold));
                                      }
                                      return Text(
                                        snapshot.data ?? 'Sin nombre',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      );
                                    },
                                  ),
                                  // Fila: Puntos + switch
                                  Row(
                                    children: [
                                      Text('Puntos: ${musico.puntosTotales}'),
                                      const Spacer(),
                                      Transform.scale(
                                        scale: 0.7,
                                        child: Switch(
                                          value: incluido,
                                          onChanged: (value) async {
                                            await ConsultasLiquidacionesBD.musicosIncluidosLiquidacion(
                                              widget.bandaId,
                                              widget.temporadaSeleccionadaId,
                                            ).doc(musico.id).update({'incluidoEnLiquidacion': value});

                                            await ConsultasLiquidacionesBD.recalcularLiquidacion(
                                              widget.bandaId,
                                              widget.temporadaSeleccionadaId,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Fila: coeficiente + importe alineado a la derecha
                                  Row(
                                    children: [
                                      const Text('Coef.Antig.: '),
                                      SizedBox(
                                        width: 60,
                                        child: TextField(
                                          controller: controller,
                                          keyboardType: TextInputType.number,
                                          textAlign: TextAlign.center,
                                          decoration: InputDecoration(isDense: true),
                                          onSubmitted: (value) async {
                                            final antig = int.tryParse(value) ?? 0;

                                            await ConsultasLiquidacionesBD.musicosIncluidosLiquidacion(
                                              widget.bandaId,
                                              widget.temporadaSeleccionadaId,
                                            ).doc(musico.id).update({'puntosAntiguedad': antig});

                                            await ConsultasLiquidacionesBD.recalcularLiquidacion(
                                              widget.bandaId,
                                              widget.temporadaSeleccionadaId,
                                            );
                                          },
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        'Importe: ${musico.importeFinal.toStringAsFixed(0)} €',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
