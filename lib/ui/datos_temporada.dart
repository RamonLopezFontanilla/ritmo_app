import 'package:flutter/material.dart';
import 'package:ritmo_app/consultas_bd/temporada.dart';
import 'package:ritmo_app/modelos/temporada.dart';
import 'package:ritmo_app/utiles/widgets.dart';

/// ****************************************************************************************
/// Página de creación / edición de Temporada
///
/// Permite al administrador:
/// - Crear una nueva temporada
/// - Editar una temporada existente
/// - Seleccionar fechas de inicio y fin
/// - Validar que el rango de fechas sea correcto
/// - Evitar solapamientos con otras temporadas
///
/// Es un [StatefulWidget] porque:
/// - Gestiona estado de carga
/// - Mantiene valores seleccionados en desplegables
/// - Ejecuta validaciones antes de guardar
/// ****************************************************************************************
class PaginaDatosTemporada extends StatefulWidget {
  final String bandaId;
  final String? temporadaId;

  const PaginaDatosTemporada({super.key, required this.bandaId, this.temporadaId});
  @override
  State<PaginaDatosTemporada> createState() => EstadoPaginaDatosTemporada();
}

/// ****************************************************************************************
/// Estado de la página de Datos de Temporada
///
/// Contiene la lógica:
/// - Carga de temporadas existentes
/// - Carga de datos en modo edición
/// - Construcción de fechas desde desplegables
/// - Validación de rango y solapamientos
/// - Guardado en base de datos
/// ****************************************************************************************
class EstadoPaginaDatosTemporada extends State<PaginaDatosTemporada> {
  // Valores individuales para fecha de inicio
  int? inicioDia;
  int? inicioMes;
  int? inicioAnio;

  // Valores individuales para fecha de fin
  int? finDia;
  int? finMes;
  int? finAnio;

  // Estados de pantalla
  bool cargando = true;
  bool grabando = false;

  // Lista de temporadas existentes. Se usa para validar solapamientos
  List<Temporada> temporadasExistentes = [];

  /// ***********************************************
  /// Inicialización
  ///
  /// Se ejecuta al crear la pantalla.
  /// ***********************************************
  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  /// *******************************************************************
  /// Inicio de la lógica principal
  ///
  /// - Carga todas las temporadas existentes [ConsultasTemporadasBD.obtenerTemporadas].
  /// - Si estamos en modo edición, carga los datos [ConsultasTemporadasBD.obtenerTemporadaPorId].
  /// *******************************************************************
  Future<void> cargarDatos() async {
    try {
      temporadasExistentes = await ConsultasTemporadasBD.obtenerTemporadas(widget.bandaId);

      if (widget.temporadaId != null) {
        final temporada = await ConsultasTemporadasBD.obtenerTemporadaPorId(widget.bandaId, widget.temporadaId!);

        if (temporada == null) return;

        inicioDia = temporada.fechaInicio.day;
        inicioMes = temporada.fechaInicio.month;
        inicioAnio = temporada.fechaInicio.year;

        finDia = temporada.fechaFin.day;
        finMes = temporada.fechaFin.month;
        finAnio = temporada.fechaFin.year;
      }
    } catch (e, s) {
      debugPrint("Error al inicializar temporada: $e");
      debugPrintStack(stackTrace: s);

      if (mounted) {
        context.mostrarSnack("Error cargando datos", esCorrecto: false);
      }
    } finally {
      if (mounted) {
        setState(() => cargando = false);
      }
    }
  }

  /// *******************************************************************
  /// Cargar datos de una temporada existente (modo edición)
  ///
  /// Inicializa los desplegables con los valores actuales
  /// *******************************************************************
  DateTime? get fechaInicioCompleta => (inicioAnio != null && inicioMes != null && inicioDia != null)
      ? DateTime(inicioAnio!, inicioMes!, inicioDia!)
      : null;

  DateTime? get fechaFinCompleta =>
      (finAnio != null && finMes != null && finDia != null) ? DateTime(finAnio!, finMes!, finDia!) : null;

  /// *******************************************************************
  /// Crear modelo de temporada actual
  ///
  /// Devuelve null si las fechas no están completas
  /// *******************************************************************
  Temporada? get temporadaActual {
    if (fechaInicioCompleta == null || fechaFinCompleta == null) return null;

    return Temporada.crear(id: widget.temporadaId ?? '', inicio: fechaInicioCompleta!, fin: fechaFinCompleta!);
  }

  /// *******************************************************************
  /// Validar que no exista solapamiento con otras temporadas
  ///
  /// Ignora la propia temporada si estamos editando
  /// *******************************************************************
  bool validarSolapamiento(Temporada nueva) {
    for (final t in temporadasExistentes) {
      if (widget.temporadaId != null && t.id == widget.temporadaId) continue;
      if (nueva.solapaCon(t)) return false;
    }
    return true;
  }

  /// ****************************************************************************************
  /// Guardar temporada
  ///
  /// Pasos:
  /// - Comprueba que las fechas estén completas
  /// - Valida rango correcto (inicio <= fin)
  /// - Valida solapamientos [validarSolapamiento]
  /// - Guarda en base de datos [ConsultasTemporadasBD.guardarTemporada]
  /// - Devuelve true a la pantalla anterior
  /// ****************************************************************************************
  Future<void> guardarDatosTemporada() async {
    if (grabando) return;
    setState(() => grabando = true);

    try {
      if (fechaInicioCompleta == null || fechaFinCompleta == null) {
        context.mostrarSnack("Debes seleccionar fecha de inicio y fin", esCorrecto: false);
        return;
      }

      final nuevaTemporada = temporadaActual!;
      if (!nuevaTemporada.esRangoValido) {
        context.mostrarSnack("La fecha de fin no puede ser anterior a la de inicio", esCorrecto: false);
        return;
      }
      if (!validarSolapamiento(nuevaTemporada)) {
        context.mostrarSnack("Las fechas se solapan con otra temporada", esCorrecto: false);
        return;
      }

      await ConsultasTemporadasBD.guardarTemporada(widget.bandaId, nuevaTemporada);

      if (!mounted) return;
      context.mostrarSnack("Temporada guardada", esCorrecto: true);
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => grabando = false);
    }
  }

  /// ****************************************************************************************
  /// Nombre calculado de la temporada
  ///
  /// Formato:
  ///   AñoInicio / AñoFin (2 últimos dígitos)
  ///
  /// Devuelve cadena vacía si las fechas no están completas
  /// ****************************************************************************************
  String get nombreTemporada {
    if (fechaInicioCompleta == null || fechaFinCompleta == null) return '';
    final anioInicio = fechaInicioCompleta!.year;
    final anioFin = fechaFinCompleta!.year % 100; // últimos 2 dígitos
    return "$anioInicio/$anioFin";
  }

  /// ****************************************************************************************
  /// Generar lista de valores para desplegables
  ///
  /// - Recibe rango mínimo y máximo
  /// - Devuelve lista de [DropdownMenuItem] de enteros
  /// ****************************************************************************************
  List<DropdownMenuItem<int>> generarLista(int min, int max) {
    return List.generate(max - min + 1, (i) => DropdownMenuItem(value: min + i, child: Text((min + i).toString())));
  }

  /// ********************************************************
  ///                  --- Construir UI ---
  ///
  /// Estructura principal:
  /// 1. AppBar: muestra título según si es edición o creación de temporada
  /// 2. Cuerpo:
  ///    - Muestra indicador de carga si los datos aún no están listos
  ///    - Si hay datos, muestra:
  ///       a) Nombre calculado de la temporada
  ///       b) Selección de fecha de inicio (día, mes, año) usando desplegables
  ///       c) Selección de fecha de fin (día, mes, año) usando desplegables
  /// 3. Botón de guardado en la parte inferior (enabled solo si no está cargando)
  ///
  /// Permite al usuario:
  /// - Visualizar las fechas seleccionadas
  /// - Cambiar día, mes y año de inicio y fin
  /// - Guardar la temporada validando rangos y solapamientos
  /// ********************************************************
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ----------------------------
      //         BARRA SUPERIOR
      // ----------------------------
      appBar: AppBar(title: Text(widget.temporadaId != null ? "Editar Temporada" : "Nueva Temporada")),

      // ----------------------------
      //       CUERPO PRINCIPAL
      // ----------------------------
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  CampoEtiqueta(label: "Nombre", value: nombreTemporada),
                  const SizedBox(height: 20),

                  const Text("Fecha de inicio", style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Expanded(
                        child: AppDropdown<int>(
                          label: "Día",
                          value: inicioDia,
                          items: generarLista(1, 31),
                          onChanged: (v) {
                            setState(() => inicioDia = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppDropdown<int>(
                          label: "Mes",
                          value: inicioMes,
                          items: generarLista(1, 12),
                          onChanged: (v) {
                            setState(() => inicioMes = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppDropdown<int>(
                          label: "Año",
                          value: inicioAnio,
                          items: generarLista(2000, 2100),
                          onChanged: (v) {
                            setState(() => inicioAnio = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  const Text("Fecha de fin", style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Expanded(
                        child: AppDropdown<int>(
                          label: "Día",
                          value: finDia,
                          items: generarLista(1, 31),
                          onChanged: (v) {
                            setState(() => finDia = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppDropdown<int>(
                          label: "Mes",
                          value: finMes,
                          items: generarLista(1, 12),
                          onChanged: (v) {
                            setState(() => finMes = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppDropdown<int>(
                          label: "Año",
                          value: finAnio,
                          items: generarLista(2000, 2100),
                          onChanged: (v) {
                            setState(() => finAnio = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),

      // ----------------------------
      //       BOTÓN GUARDAR
      // ----------------------------
      bottomNavigationBar: BotonGuardar(enabled: !cargando, onPressed: guardarDatosTemporada),
    );
  }
}
