import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:ritmo_app/consultas_bd/bandas.dart';
import 'package:ritmo_app/consultas_bd/liquidaciones.dart';
import 'package:ritmo_app/consultas_bd/temporada.dart';
import 'package:ritmo_app/consultas_bd/usuarios.dart';
import 'package:ritmo_app/modelos/musico_liquidacion.dart';
import 'package:ritmo_app/modelos/parametros_liquidacion.dart';

/// ****************************************************************************************
/// Página de Liquidación del Músico
///
/// Permite:
/// - Visualizar la liquidación individual de un músico en una temporada
/// - Consultar parámetros generales de la banda
/// - Consultar parámetros individuales del músico
/// - Ver desglose de puntos por tipo de evento
/// - Generar un PDF detallado de la liquidación
///
/// Es un [StatefulWidget] porque:
/// - Carga datos asíncronos desde base de datos
/// - Controla estado de carga
/// - Evalúa permisos de acceso
/// - Genera dinámicamente contenido PDF
/// ****************************************************************************************
class PaginaLiquidacionMusico extends StatefulWidget {
  final String bandaId;
  final String temporadaSeleccionadaId;
  final String musicoId;
  final bool esAdmin;

  const PaginaLiquidacionMusico({
    super.key,
    required this.bandaId,
    required this.temporadaSeleccionadaId,
    required this.musicoId,
    required this.esAdmin,
  });

  @override
  State<PaginaLiquidacionMusico> createState() => EstadoPaginaLiquidacionMusico();
}

/// ****************************************************************************************
/// Estado de la página de Liquidación del Músico
///
/// Contiene la lógica:
/// - Carga de datos (banda, temporada, músico, parámetros y liquidación)
/// - Evaluación de permisos de acceso
/// - Construcción del desglose de puntos
/// - Generación de documento PDF
/// - Construcción dinámica de la UI
/// ****************************************************************************************
class EstadoPaginaLiquidacionMusico extends State<PaginaLiquidacionMusico> {
  String? nombreTemporada;
  String nombreBanda = '';
  String nombreMusico = '';
  bool cargando = true;
  bool accesoPermitido = false;

  late ParametrosLiquidacion parametrosLiquidacion;
  late LiquidacionMusico musicoLiquidacion;

  /// ***********************************************
  /// Inicialización
  ///
  /// Se ejecuta al crear el estado.
  /// Lanza la carga inicial de datos.
  /// ***********************************************
  @override
  void initState() {
    super.initState();
    inicializar();
  }

  Future<void> inicializar() async {
    await cargarDatos();
  }

  /// *******************************************************************
  /// Cargar datos necesarios
  ///
  /// Flujo:
  /// - Obtiene datos de liquidación
  /// - Evalúa permisos de acceso
  /// - Desactiva estado de carga
  /// *******************************************************************
  Future<void> cargarDatos() async {
    await obtenerLiquidacion(); // Espera que los datos se carguen
    evaluarAcceso();
    setState(() => cargando = false);
  }

  /// *******************************************************************
  /// Obtener datos desde base de datos
  ///
  /// Recupera:
  /// - Nombre de la banda
  /// - Nombre de la temporada
  /// - Nombre del músico
  /// - Parámetros generales de liquidación
  /// - Datos individuales del músico
  /// *******************************************************************
  Future<void> obtenerLiquidacion() async {
    nombreBanda = await ConsultasBandasBD.obtenerNombreBanda(widget.bandaId);
    nombreTemporada = await ConsultasTemporadasBD.obtenerNombreTemporada(
      widget.bandaId,
      widget.temporadaSeleccionadaId,
    );
    nombreMusico = await ConsultasUsuariosBD.obtenerNombreMusico(widget.musicoId);
    parametrosLiquidacion = await ConsultasLiquidacionesBD.obtenerParametros(
      widget.bandaId,
      widget.temporadaSeleccionadaId,
    );
    musicoLiquidacion = await ConsultasLiquidacionesBD.obtenerLiquidacionMusico(
      widget.bandaId,
      widget.temporadaSeleccionadaId,
      widget.musicoId,
    );
  }

  /// *******************************************************************
  /// Evaluar permiso de acceso
  ///
  /// Reglas:
  /// - Admin --> siempre acceso permitido
  /// - Músico --> solo si:
  ///     - Liquidación es visible
  ///     - Está incluido en liquidación
  /// *******************************************************************
  void evaluarAcceso() {
    if (widget.esAdmin) {
      accesoPermitido = true;
    } else {
      accesoPermitido = parametrosLiquidacion.visibleMusico && musicoLiquidacion.incluidoEnLiquidacion;
    }
  }

  /// *******************************************************************
  /// Generar PDF de la liquidación
  ///
  /// Contenido del PDF:
  /// - Cabecera con banda, temporada y músico
  /// - Parámetros generales
  /// - Parámetros individuales
  /// - Tabla de puntos detallada
  /// - Importe final a recibir
  ///
  /// Utiliza:
  /// - paquete pdf
  /// - paquete printing
  /// *******************************************************************
  Future<void> generarPdfLiquidacion() async {
    final pdf = pw.Document();

    // Construimos los datos de la tabla con columna Total Ptos.
    final repartoPuntos = [
      {
        'evento': 'Ensayos (puntuales)',
        'asistencias': musicoLiquidacion.numEnsayosPuntual,
        'ptosAsist': parametrosLiquidacion.puntosEnsayoPuntual,
        'ptosAnt':
            musicoLiquidacion.numEnsayosPuntual *
            (parametrosLiquidacion.puntosAntigEP * musicoLiquidacion.puntosAntiguedad),
      },
      {
        'evento': 'Ensayos (retrasados)',
        'asistencias': musicoLiquidacion.numActuacionRetraso,
        'ptosAsist': parametrosLiquidacion.puntosEnsayoRetraso,
        'ptosAnt':
            musicoLiquidacion.numActuacionRetraso *
            (parametrosLiquidacion.puntosAntigER * musicoLiquidacion.puntosAntiguedad),
      },
      {
        'evento': 'Actuaciones (puntuales)',
        'asistencias': musicoLiquidacion.numActuacionPuntual,
        'ptosAsist': parametrosLiquidacion.puntosActuacionPuntual,
        'ptosAnt':
            musicoLiquidacion.numActuacionPuntual *
            (parametrosLiquidacion.puntosAntigAP * musicoLiquidacion.puntosAntiguedad),
      },
      {
        'evento': 'Actuaciones (retrasadas)',
        'asistencias': musicoLiquidacion.numActuacionRetraso,
        'ptosAsist': parametrosLiquidacion.puntosActuacionRetrasada,
        'ptosAnt':
            musicoLiquidacion.numActuacionRetraso *
            (parametrosLiquidacion.puntosAntigAR * musicoLiquidacion.puntosAntiguedad),
      },
      {
        'evento': 'Semana Santa (puntuales)',
        'asistencias': musicoLiquidacion.numSemanaStaPuntual,
        'ptosAsist': parametrosLiquidacion.puntosSSPuntual,
        'ptosAnt':
            musicoLiquidacion.numSemanaStaPuntual *
            (parametrosLiquidacion.puntosAntigSSP * musicoLiquidacion.puntosAntiguedad),
      },
      {
        'evento': 'Semana Santa (retrasadas)',
        'asistencias': musicoLiquidacion.numSemanaStaRetraso,
        'ptosAsist': parametrosLiquidacion.puntosSSRetraso,
        'ptosAnt':
            musicoLiquidacion.numSemanaStaRetraso *
            (parametrosLiquidacion.puntosAntigSSR * musicoLiquidacion.puntosAntiguedad),
      },
    ];

    // Calculamos la columna total y el total general
    for (var e in repartoPuntos) {
      final int asistencias = (e['asistencias'] ?? 0) as int;
      final int ptosAsist = (e['ptosAsist'] ?? 0) as int;
      final int ptosAnt = (e['ptosAnt'] ?? 0) as int;

      e['total'] = asistencias * ptosAsist + ptosAnt;
    }
    final int totalGeneral = repartoPuntos.fold<int>(0, (sum, e) => sum + ((e['total'] ?? 0) as int));

    // Convertimos a lista de listas para pw.Table.fromTextArray
    final List<List<String>> tablaDatos = repartoPuntos
        .map(
          (e) => [
            e['asistencias'].toString(),
            e['evento'].toString(),
            e['ptosAsist'].toString(),
            e['ptosAnt'].toString(),
            e['total'].toString(),
          ],
        )
        .toList();

    // Agregamos fila de totales
    tablaDatos.add(['', 'Total de puntos:', '', '', totalGeneral.toString()]);

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          // ------------------------------
          //          CABECERA
          // ------------------------------
          pw.Text(nombreBanda, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('Liquidación $nombreTemporada', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.Text(nombreMusico, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 25),
          // ------------------------------
          //  PARÁMETROS GENERALES BANDA
          // ------------------------------
          pw.Text(
            'PARÁMETROS GENERALES',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.indigo),
          ),
          pw.SizedBox(height: 6),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Importe total a repartir:'),
              pw.Text('${parametrosLiquidacion.cantidadRepartir.toStringAsFixed(2)} Euros'),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [pw.Text('Total puntos músicos:'), pw.Text('${parametrosLiquidacion.totalPuntosLiquidacion}')],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Valor del punto:'),
              pw.Text('${parametrosLiquidacion.valorPunto.toStringAsFixed(2)} Euros'),
            ],
          ),

          pw.SizedBox(height: 25),

          // ------------------------------
          //     PARÁMETROS DEL MÚSICO
          // ------------------------------
          pw.Text(
            'PARÁMETROS DEL MÚSICO',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.indigo),
          ),
          pw.SizedBox(height: 6),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [pw.Text('Coeficiente antigüedad:'), pw.Text('${musicoLiquidacion.puntosAntiguedad}')],
          ),

          pw.SizedBox(height: 16),

          // ------------------------------
          //            TABLA
          // ------------------------------
          pw.SizedBox(height: 12),

          // Tabla de puntos con total
          pw.TableHelper.fromTextArray(
            headers: ['Cant.', 'Evento', 'Ptos./Asist.', 'Ptos./Antig.', 'Total Ptos.'],
            data: tablaDatos,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerRight, // Alinea todos los números a la derecha
            cellAlignments: {
              0: pw.Alignment.centerRight, // La primera columna (Evento) alineada a la izquierda
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          ),

          pw.SizedBox(height: 45),

          pw.Text(
            'IMPORTE A RECIBIR: ${musicoLiquidacion.importeFinal.toStringAsFixed(0)} Euros',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  /// *******************************************************************
  /// Widget auxiliar para mostrar filas tipo etiqueta/valor
  ///
  /// Parámetros:
  /// - texto: descripción
  /// - valor: dato a mostrar
  /// - negrita: resalta visualmente el valor
  /// *******************************************************************
  Widget fila(String texto, dynamic valor, {bool negrita = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(texto, style: TextStyle(fontSize: 14, fontWeight: negrita ? FontWeight.bold : FontWeight.normal)),
          Text(
            '${valor ?? 0}',
            style: TextStyle(fontSize: negrita ? 16 : 14, fontWeight: negrita ? FontWeight.bold : FontWeight.normal),
          ),
        ],
      ),
    );
  }

  /// ********************************************************
  ///                  --- Construir UI ---
  ///
  /// Estructura:
  /// - Estado de carga (CircularProgressIndicator)
  /// - Pantalla de acceso denegado si no tiene permiso
  /// - AppBar con opción de generar PDF
  /// - Parámetros generales
  /// - Parámetros del músico
  /// - Tabla de desglose
  /// - Resultado final
  ///
  /// La UI se construye dinámicamente según:
  /// - Estado de carga
  /// - Permiso de acceso
  /// ********************************************************
  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // -------------------------------------------
    //       SI NO ESTÁ PERMITIDA LA CONSULTA
    // -------------------------------------------
    if (!accesoPermitido) {
      return Scaffold(
        // ----------------------------
        //         BARRA SUPERIOR
        // ----------------------------
        appBar: AppBar(title: Text('Liquidación $nombreTemporada')),
        // ----------------------------
        //       CUERPO PRINCIPAL
        // ----------------------------
        body: const Center(
          child: Text(
            "Acceso denegado.\nNo estás incluido o la liquidación no es visible.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }
    // -------------------------------------------
    //       SI NO ESTÁ PERMITIDA LA CONSULTA
    // -------------------------------------------

    final List<Map<String, dynamic>> repartoPuntos = [
      {
        'evento': 'Ensayos (puntuales)',
        'asistencias': musicoLiquidacion.numEnsayosPuntual,
        'ptosAsist': parametrosLiquidacion.puntosEnsayoPuntual,
        'ptosAnt': (parametrosLiquidacion.puntosAntigEP * musicoLiquidacion.puntosAntiguedad),
      },
      {
        'evento': 'Ensayos (retrasados)',
        'asistencias': musicoLiquidacion.numActuacionRetraso,
        'ptosAsist': parametrosLiquidacion.puntosEnsayoRetraso,
        'ptosAnt': (parametrosLiquidacion.puntosAntigER * musicoLiquidacion.puntosAntiguedad),
      },
      {
        'evento': 'Actuaciones (puntuales)',
        'asistencias': musicoLiquidacion.numActuacionPuntual,
        'ptosAsist': parametrosLiquidacion.puntosActuacionPuntual,
        'ptosAnt': (parametrosLiquidacion.puntosAntigAP * musicoLiquidacion.puntosAntiguedad),
      },
      {
        'evento': 'Actuaciones (retrasados)',
        'asistencias': musicoLiquidacion.numActuacionRetraso,
        'ptosAsist': parametrosLiquidacion.puntosActuacionRetrasada,
        'ptosAnt': (parametrosLiquidacion.puntosAntigAR * musicoLiquidacion.puntosAntiguedad),
      },
      {
        'evento': 'Semana Santa (puntuales)',
        'asistencias': musicoLiquidacion.numSemanaStaPuntual,
        'ptosAsist': parametrosLiquidacion.puntosSSPuntual,
        'ptosAnt': (parametrosLiquidacion.puntosAntigSSP * musicoLiquidacion.puntosAntiguedad),
      },
      {
        'evento': 'Semana Santa (retrasados)',
        'asistencias': musicoLiquidacion.numSemanaStaRetraso,
        'ptosAsist': parametrosLiquidacion.puntosSSRetraso,
        'ptosAnt': (parametrosLiquidacion.puntosAntigSSR * musicoLiquidacion.puntosAntiguedad),
      },
    ];

    return Scaffold(
      // ----------------------------
      //         BARRA SUPERIOR
      // ----------------------------
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Liquidación $nombreTemporada"),
            Text(nombreMusico, style: const TextStyle(fontSize: 14)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.indigo),
            onPressed: generarPdfLiquidacion,
          ),
        ],
      ),

      // ----------------------------
      //       CUERPO PRINCIPAL
      // ----------------------------
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // Parámetros generales
            Center(
              child: Text(
                '--- PARÁMETROS GENERALES --',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple),
              ),
            ),
            fila('Importe total a repartir:', '${parametrosLiquidacion.cantidadRepartir} €'),
            fila('Total de puntos músicos:', parametrosLiquidacion.totalPuntosLiquidacion),
            fila('Valor del punto:', '${parametrosLiquidacion.valorPunto.toStringAsFixed(2)} €'),
            const SizedBox(height: 20),

            // Parámetros del músico
            Center(
              child: Text(
                '--- PARÁMETROS MÚSICO--- ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple),
              ),
            ),
            fila('Coeficiente antigüedad:', musicoLiquidacion.puntosAntiguedad),
            const SizedBox(height: 20),

            // Resultado de la liquidación
            Center(
              child: Text(
                '--- RESULTADO LIQUIDACIÓN ---',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple),
              ),
            ),
            DataTable(
              // Parámetros de la tabla
              columnSpacing: 8,
              horizontalMargin: 8,
              dataRowMinHeight: 36,
              dataRowMaxHeight: 45,

              // Cabecera de la tabla
              headingRowHeight: 45,
              columns: const [
                DataColumn(label: Text('Cant.'), columnWidth: FixedColumnWidth(60)),
                DataColumn(label: Text('Tipo Eventos'), columnWidth: FixedColumnWidth(130)),
                DataColumn(label: Text('Ptos./\nAsist.'), columnWidth: FixedColumnWidth(60)),
                DataColumn(label: Text('Ptos./\nAntig.'), columnWidth: FixedColumnWidth(60)),
              ],

              // Cuerpo de la tabla
              rows: repartoPuntos.map((e) {
                return DataRow(
                  cells: [
                    DataCell(SizedBox(width: 30, child: Text(e['asistencias'].toString(), textAlign: TextAlign.right))),
                    DataCell(Text(e['evento'].toString())),
                    DataCell(SizedBox(width: 40, child: Text(e['ptosAsist'].toString(), textAlign: TextAlign.right))),
                    DataCell(SizedBox(width: 40, child: Text(e['ptosAnt'].toString(), textAlign: TextAlign.right))),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            fila('Suma de puntos:', musicoLiquidacion.puntosTotales),
            fila('Importe a recibir:', '${musicoLiquidacion.importeFinal.toStringAsFixed(0)} €', negrita: true),
          ],
        ),
      ),
    );
  }
}
