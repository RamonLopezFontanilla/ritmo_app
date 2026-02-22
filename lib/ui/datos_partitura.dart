import 'package:flutter/material.dart';
import 'package:ritmo_app/consultas_bd/generos.dart';
import 'package:ritmo_app/consultas_bd/instrumentos.dart';
import 'package:ritmo_app/consultas_bd/partituras.dart';
import 'package:ritmo_app/modelos/genero.dart';
import 'package:ritmo_app/modelos/partitura.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ritmo_app/utiles/widgets.dart';
import 'package:ritmo_app/modelos/otros_accesos_musico.dart';

/// ****************************************************************************************
///    Página principal de datos de una partitura
///
///    Funcionalidades:
///    - Crear una nueva partitura
///    - Editar una partitura existente
///    - Gestionar selección/creación/edición de géneros
///    - Comprobar visualización del PDF según instrumento/categoría
/// ****************************************************************************************
class PaginaDatosPartitura extends StatefulWidget {
  final String bandaId;
  final Partitura? partitura;

  const PaginaDatosPartitura({super.key, required this.bandaId, this.partitura});

  @override
  EstadoPaginaDatosPartitura createState() => EstadoPaginaDatosPartitura();
}

/// ****************************************************************************************
///    Estado de la página de datos de una partitura
///
///    - Gestiona controladores
///    - Controla el género seleccionado
///    - Gestiona lista de accesos a instrumentos
///    - Valida formulario
///    - Guarda datos
///    - Abre partitura para comprobación
/// ****************************************************************************************
class EstadoPaginaDatosPartitura extends State<PaginaDatosPartitura> {
  final TextEditingController controladorTitulo = TextEditingController();
  final TextEditingController controladorArchivo = TextEditingController();

  bool get esEdicion => widget.partitura != null;

  String? generoSeleccionadoId;

  String? accesoSeleccionado;
  List<AccesoInstrumento> accesosDisponibles = [];
  bool cargandoAccesos = true;

  /// **************************************************************
  /// Inicialización
  ///
  /// - Si es edición, carga los datos de la partitura
  /// **************************************************************
  @override
  void initState() {
    super.initState();

    if (widget.partitura != null) {
      controladorTitulo.text = widget.partitura!.titulo;
      controladorArchivo.text = widget.partitura!.archivo;
      generoSeleccionadoId = widget.partitura!.genero;
    }

    cargarAccesosInstrumentos();
  }

  /// ***********************************************
  /// Liberación de memoria
  ///
  /// Siempre es obligatorio liberar los TextEditingController
  /// para evitar fugas de memoria.
  ///************************************************
  @override
  void dispose() {
    controladorTitulo.dispose();
    controladorArchivo.dispose();
    super.dispose();
  }

  /// ***********************************************
  /// Obtención del stream de géneros
  ///************************************************
  Stream<List<Genero>> get generosStream => ConsultasGenerosBD.streamGeneros(widget.bandaId);

  /// ****************************************************
  /// Cargar todos los accesos a instrumentos
  ///
  /// Obtiene todas las combinaciones instrumento/categoría disponibles para la banda.
  ///
  /// Se utiliza exclusivamente para la sección "Comprobar" que permite abrir una partitura concreta.
  ///*****************************************************
  Future<void> cargarAccesosInstrumentos() async {
    try {
      final lista = await ConsultasInstrumentosBD.obtenerAccesosInstrumentos(widget.bandaId);

      if (!mounted) return;

      setState(() {
        accesosDisponibles = lista;

        // Inicializamos accesoSeleccionado
        if (lista.isNotEmpty) {
          // Siempre tomamos el primer acceso disponible
          final primerAcceso = lista.first;
          // formato instrumentoId|categoriaId
          accesoSeleccionado = '${primerAcceso.instrumentoId}|${primerAcceso.categoriaId ?? ''}';
        } else {
          accesoSeleccionado = null;
        }

        cargandoAccesos = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => cargandoAccesos = false);
      context.mostrarSnack('Error cargando accesos: $e', esCorrecto: false);
    }
  }

  /// ****************************************************
  ///    --- Abrir partitura seleccionada ---
  ///
  /// Construye la URI del PDF en almacenamiento en base a:
  /// - Banda
  /// - Archivo
  /// - Instrumento/Categoría
  ///
  /// Si la URI es válida, se lanza en aplicación externa.
  ///*****************************************************
  Future<void> abrirPartituraSeleccionada() async {
    if (accesoSeleccionado == null) return;

    final uri = await ConsultasPartiturasBD.obtenerUriPartitura(
      bandaId: widget.bandaId,
      archivo: controladorArchivo.text.trim(),
      instrumentoCat: accesoSeleccionado!,
    );

    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      context.mostrarSnack('No se pudo abrir la partitura', esCorrecto: false);
    }
  }

  /// *******************************************************************
  /// Validar campos del formulario
  ///
  /// Reglas:
  /// - El título no puede estar vacío
  /// - Debe seleccionarse un género
  /// - El archivo no puede estar vacío
  /// *******************************************************************
  bool validarCampos() {
    if (controladorTitulo.text.trim().isEmpty) {
      context.mostrarSnack("El título es obligatorio", esCorrecto: false);
      return false;
    }

    if (generoSeleccionadoId == null) {
      context.mostrarSnack("Debes seleccionar un género", esCorrecto: false);
      return false;
    }

    if (controladorArchivo.text.trim().isEmpty) {
      context.mostrarSnack("El nombre de archivo es obligatorio", esCorrecto: false);
      return false;
    }
    return true;
  }

  /// ****************************************************
  /// Guardar datos de partitura
  ///
  /// Si partituraId es null --> se crea documento nuevo
  /// Si partituraId existe --> se actualiza
  ///*****************************************************
  Future<void> guardarDatosPartitura() async {
    if (!validarCampos()) return;

    final data = {
      'titulo': controladorTitulo.text.trim(),
      'archivo': controladorArchivo.text.trim(),
      'genero': generoSeleccionadoId,
    };

    try {
      await ConsultasPartiturasBD.guardarPartitura(
        bandaId: widget.bandaId,
        partituraId: widget.partitura?.id,
        datos: data,
      );

      if (!mounted) return;
      context.mostrarSnack(esEdicion ? 'Partitura actualizada' : 'Partitura añadida', esCorrecto: true);
      Navigator.pop(context);
    } catch (e) {
      context.mostrarSnack('Error guardando partitura: $e', esCorrecto: false);
    }
  }

  /// ****************************************************
  /// Mostrar diálogo de género
  ///
  /// Permite:
  /// - Crear nuevo género
  /// - Editar género existente
  /// - Eliminar género (si no tiene partituras asociadas)
  ///
  /// Se usa normalización en minúsculas para evitar duplicados por diferencias de mayúsculas.
  ///*****************************************************
  Future<void> mostrarDialogoGenero({String? generoIdActual, String? nombreActual}) async {
    final controller = TextEditingController(text: nombreActual ?? '');
    final formKeyDialogo = GlobalKey<FormState>();

    String normalizar(String texto) => texto.trim().toLowerCase();

    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: formKeyDialogo,
              child: DialogoBase(
                icono: generoIdActual == null ? Icons.add : Icons.edit,
                titulo: generoIdActual == null ? 'Nuevo género' : 'Editar género',
                children: [
                  // ---------------- INPUT ----------------
                  AppInput(
                    label: 'Nombre del género',
                    controller: controller,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Campo obligatorio' : null,
                  ),

                  const SizedBox(height: 20),

                  // ---------------- BOTONES ----------------
                  Row(
                    children: [
                      // CANCELAR
                      Expanded(
                        child: TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
                      ),

                      const SizedBox(width: 12),

                      // GUARDAR / AÑADIR
                      Expanded(
                        child: BotonPrimarioDialogo(
                          label: generoIdActual == null ? "Añadir" : "Guardar",
                          icon: Icons.save,
                          onPressed: () async {
                            if (!formKeyDialogo.currentState!.validate()) return;

                            final nombre = controller.text.trim();
                            final nombreNormalizado = normalizar(nombre);

                            // Comprueba si ya existe
                            final existentes = await ConsultasGenerosBD.buscarGeneroPorNombreNormalizado(
                              widget.bandaId,
                              nombreNormalizado,
                            );

                            final yaExiste =
                                existentes.docs.isNotEmpty &&
                                (generoIdActual == null || existentes.docs.first.id != generoIdActual);

                            if (yaExiste) {
                              if (!mounted) return;
                              context.mostrarSnack('Ese género ya existe', esCorrecto: false);
                              return;
                            }

                            if (generoIdActual == null) {
                              // Crear nuevo
                              final nuevoDoc = await ConsultasGenerosBD.crearGenero(
                                widget.bandaId,
                                nombre,
                                nombreNormalizado,
                              );

                              setState(() {
                                generoSeleccionadoId = nuevoDoc.id;
                              });
                            } else {
                              // Editar existente
                              await ConsultasGenerosBD.actualizarGenero(
                                widget.bandaId,
                                generoIdActual,
                                nombre,
                                nombreNormalizado,
                              );

                              setState(() {
                                generoSeleccionadoId = generoIdActual;
                              });
                            }

                            if (!mounted) return;
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
                  ),

                  // ---------------- ELIMINAR (solo en edición) ----------------
                  if (generoIdActual != null) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () async {
                        final tienePartituras = await ConsultasGenerosBD.generoTienePartituras(
                          widget.bandaId,
                          generoIdActual,
                        );

                        if (tienePartituras) {
                          if (!mounted) return;
                          context.mostrarSnack(
                            'No se puede eliminar. Hay partituras con este género.',
                            esCorrecto: false,
                          );
                          return;
                        }

                        final confirmar = await mostrarDialogoConfirmacion(
                          context: context,
                          titulo: 'Eliminar género',
                          mensaje: '¿Seguro que quieres eliminar este género?',
                        );

                        if (!confirmar) return;

                        await ConsultasGenerosBD.eliminarGenero(widget.bandaId, generoIdActual);

                        if (!mounted) return;
                        setState(() {
                          if (generoSeleccionadoId == generoIdActual) {
                            generoSeleccionadoId = null;
                          }
                        });

                        Navigator.pop(context);
                      },
                      child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// ***********************************************
  ///            --- Construir UI ---
  ///
  /// - AppBar (título dinámico según modo)
  /// - Body (Formulario scrollable)
  /// - BottomNavigationBar (Botón guardar fijo)
  ///
  /// Este método se adapta a modo creación o edición
  /// ***********************************************
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ----------------------------
      //         BARRA SUPERIOR
      // ----------------------------
      appBar: AppBar(title: Text(esEdicion ? 'Editar Partitura' : 'Nueva Partitura')),

      // ----------------------------
      //       CUERPO PRINCIPAL
      // ----------------------------
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  AppInput(
                    controller: controladorTitulo,
                    label: 'Título',
                    validator: (v) => v == null || v.isEmpty ? 'El genero es obligatorio' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: StreamBuilder<List<Genero>>(
                          stream: generosStream,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const SizedBox(
                                height: 56,
                                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              );
                            }

                            final generos = snapshot.data!;

                            return AppDropdown<String>(
                              value: generos.any((g) => g.id == generoSeleccionadoId) ? generoSeleccionadoId : null,
                              label: 'Género',
                              items: generos
                                  .map((g) => DropdownMenuItem<String>(value: g.id, child: Text(g.nombre)))
                                  .toList(),
                              onChanged: (v) => setState(() => generoSeleccionadoId = v),
                              validator: (v) => v == null ? 'Selecciona un género' : null,
                            );
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          mostrarDialogoGenero();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: generoSeleccionadoId == null
                            ? null
                            : () async {
                                final genero = await ConsultasGenerosBD.obtenerGeneroPorId(
                                  widget.bandaId,
                                  generoSeleccionadoId!,
                                );

                                if (genero == null) return;

                                mostrarDialogoGenero(generoIdActual: genero.id, nombreActual: genero.nombre);
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppInput(
                    controller: controladorArchivo,
                    label: 'Archivo (sin .pdf)',
                    validator: (v) => v == null || v.isEmpty ? 'Campo obligatorio' : null,
                  ),
                  const SizedBox(height: 40),
                  Text('Comprobar', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  cargandoAccesos
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                      : AppDropdown<String>(
                          value: accesoSeleccionado,
                          label: 'Instrumento / Categoría',
                          items: accesosDisponibles
                              .map(
                                (a) => DropdownMenuItem<String>(
                                  value: '${a.instrumentoId}|${a.categoriaId ?? ''}',
                                  child: Text(a.nombre),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => accesoSeleccionado = v),
                        ),
                  const SizedBox(height: 12),
                  BotonAPantalla(
                    label: "VER PARTITURA",
                    icon: Icons.picture_as_pdf,
                    onPressed: abrirPartituraSeleccionada,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      // ----------------------------
      //       BOTÓN GUARDAR
      // ----------------------------
      bottomNavigationBar: BotonGuardar(enabled: true, onPressed: guardarDatosPartitura),
    );
  }
}
