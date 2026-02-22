import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ritmo_app/consultas_bd/instrumentos.dart';
import 'package:ritmo_app/modelos/categoria_instrumento.dart';
import 'package:ritmo_app/modelos/instrumento.dart';
import 'package:ritmo_app/utiles/widgets.dart';
import 'package:uuid/uuid.dart';

/// ********************************************************
/// Página de datos de un instrumento.
///
/// Permite:
/// - Crear un nuevo instrumento dentro de la banda.
/// - Editar un instrumento existente.
/// - Configurar una carpeta general de partituras
///   o múltiples carpetas por categoría.
/// - Seleccionar un icono:
///     - Desde iconos base del sistema (assets)
///     - Desde iconos ya existentes en la banda
///     - Subiendo una nueva imagen
/// - Validar que el nombre del instrumento sea único.
/// - Guardar la información completa en base de datos.
///
/// Es un [StatefulWidget] porque necesita mantener estado:
/// - Controladores de texto
/// - Estado de carga
/// - Imagen seleccionada
/// - Icono elegido
/// - Activación dinámica de categorías
/// ********************************************************
class PaginaDatosInstrumento extends StatefulWidget {
  final String bandaId;
  final String? instrumentoId;

  const PaginaDatosInstrumento({super.key, required this.bandaId, this.instrumentoId});
  bool get esEdicion => instrumentoId != null;

  @override
  State<PaginaDatosInstrumento> createState() => EstadoPaginaDatosInstrumento();
}

/// ********************************************************
/// Estado de la página de datos del instrumento.
///
/// Contiene toda la lógica:
/// - Carga inicial del instrumento en modo edición
/// - Gestión dinámica de categorías
/// - Gestión de iconos e imágenes
/// - Validaciones antes de guardar
/// - Construcción del objeto final [Instrumento]
/// ********************************************************
class EstadoPaginaDatosInstrumento extends State<PaginaDatosInstrumento> {
  /// Controladores de texto principales
  final TextEditingController controladorNombre = TextEditingController();
  final TextEditingController controladorCarpetaGeneral = TextEditingController();

  /// Indicador de carga (evita acciones simultáneas)
  bool cargando = false;

  /// Determina si el instrumento usa categorías
  bool tieneCategorias = false;

  /// Categorías predefinidas disponibles para activar
  final List<String> categoriasDisponibles = ["Primero", "Segundo", "Tercero", "Principal"];

  final Map<String, Map<String, dynamic>> categorias = {};

  /// Imagen nueva seleccionada desde galería
  File? imagen;

  /// URL o path del icono seleccionado
  String? iconoUrl;

  /// Lista de iconos base incluidos en assets
  final List<String> iconosBase = [
    "assets/instrumentos/clarinete.png",
    "assets/instrumentos/flauta.png",
    "assets/instrumentos/fliscorno.png",
    "assets/instrumentos/percusion.png",
    "assets/instrumentos/requinto.png",
    "assets/instrumentos/saxoalto.png",
    "assets/instrumentos/trombon.png",
    "assets/instrumentos/trompa.png",
    "assets/instrumentos/trompeta.png",
    "assets/instrumentos/tuba.png",
  ];

  final picker = ImagePicker();

  /// ********************************************************
  /// Inicialización del estado
  ///
  /// - Si estamos en modo edición, carga los datos del instrumento desde la base de datos.
  /// ********************************************************
  @override
  void initState() {
    super.initState();
    if (widget.esEdicion) {
      cargarDatos();
    }
  }

  /// ********************************************************
  /// Liberación de recursos
  ///
  /// - Libera controladores principales.
  /// - Libera controladores de categorías activas.
  /// - Evita fugas de memoria.
  /// ********************************************************
  @override
  void dispose() {
    controladorNombre.dispose();
    controladorCarpetaGeneral.dispose();
    for (var c in categorias.values) {
      c['controller']?.dispose();
    }
    super.dispose();
  }

  /// ********************************************************
  /// Carga los datos del instrumento para edición
  ///
  /// - Obtiene datos desde base de datos.
  /// - Configura nombre e icono.
  /// - Detecta si tiene categorías o carpeta general.
  /// ********************************************************
  Future<void> cargarDatos() async {
    setState(() => cargando = true);

    if (widget.instrumentoId != null) {
      final inst = await ConsultasInstrumentosBD.obtenerInstrumento(
        bandaId: widget.bandaId,
        instrumentoId: widget.instrumentoId!,
      );

      if (inst != null) {
        controladorNombre.text = inst.nombre;
        iconoUrl = inst.iconoUrl;

        if (inst.categorias.isNotEmpty) {
          tieneCategorias = true;
          for (var cat in inst.categorias) {
            categorias[cat.nombre] = {
              "categoriaId": cat.categoriaId,
              "controller": TextEditingController(text: cat.carpetaPartituras),
            };
          }
        } else {
          controladorCarpetaGeneral.text = inst.carpetaPartituras;
        }
      }
    }

    setState(() => cargando = false);
  }

  /// ********************************************************
  /// Activa o desactiva una categoría.
  ///
  /// - Si se activa:
  ///     - Genera ID temporal
  ///     - Crea controlador para carpeta
  /// - Si se desactiva:
  ///     - Elimina controlador
  ///     - Libera memoria
  /// ********************************************************
  void toggleCategoria(String nombre, bool selected) {
    setState(() {
      if (selected) {
        categorias[nombre] = {
          "categoriaId": ConsultasInstrumentosBD.firestore.collection('tmp').doc().id,
          "controller": TextEditingController(),
        };
      } else {
        categorias[nombre]?['controller']?.dispose();
        categorias.remove(nombre);
      }
    });
  }

  /// **************************************************************
  /// Menú seleccionar icono
  ///
  /// Opciones:
  /// - Iconos básicos
  /// - Iconos ya existentes
  /// - Subir nuevo icono
  /// **************************************************************
  Future<void> seleccionarIcono() async {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.music_note),
              title: const Text("Iconos básicos"),
              onTap: () {
                Navigator.pop(context);
                seleccionarIconoBase();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Elegir icono existente"),
              onTap: () async {
                Navigator.pop(context);
                seleccionarIconoExistente();
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload),
              title: const Text("Subir nuevo icono"),
              onTap: () async {
                Navigator.pop(context);
                final picked = await picker.pickImage(source: ImageSource.gallery);
                if (picked != null) {
                  setState(() {
                    imagen = File(picked.path);
                    iconoUrl = null;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// **************************************************************
  /// Seleccionar icono base (assets)
  /// **************************************************************
  Future<void> seleccionarIconoBase() async {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: DialogoBase(
          icono: Icons.music_note,
          titulo: "Iconos básicos",
          children: [
            const SizedBox(height: 10),
            SizedBox(
              width: double.maxFinite,
              height: 320,
              child: GridView.builder(
                itemCount: iconosBase.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (_, index) {
                  final path = iconosBase[index];

                  return InkWell(
                    onTap: () {
                      setState(() {
                        iconoUrl = path; // guardamos como asset
                        imagen = null;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Image.asset(path),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// **************************************************************
  /// Seleccionar icono ya existente en la banda
  /// **************************************************************
  Future<void> seleccionarIconoExistente() async {
    final urls = await ConsultasInstrumentosBD.obtenerIconosInstrumentos(widget.bandaId);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Seleccionar icono"),
        content: SizedBox(
          width: double.maxFinite,
          child: urls.isEmpty
              ? const Text("No hay iconos disponibles")
              : GridView.builder(
                  shrinkWrap: true,
                  itemCount: urls.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemBuilder: (_, index) {
                    final url = urls[index];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          iconoUrl = url;
                          imagen = null;
                        });
                        Navigator.pop(context);
                      },
                      child: Image.network(url, fit: BoxFit.cover),
                    );
                  },
                ),
        ),
      ),
    );
  }

  /// ********************************************************
  /// Guarda el instrumento en base de datos.
  ///
  /// Flujo:
  /// - Valida nombre obligatorio.
  /// - Valida carpetas según modo.
  /// - Verifica nombre único.
  /// - Construye objeto [Instrumento].
  /// - Guarda todo en una sola operación.
  /// ********************************************************
  Future<void> guardarInstrumento() async {
    final nombre = controladorNombre.text.trim();
    if (nombre.isEmpty) {
      context.mostrarSnack('El nombre no puede estar vacío', esCorrecto: false);
      return;
    }

    final List<CategoriaInstrumento> listaCategorias = [];
    String carpetaGeneral = '';

    if (tieneCategorias) {
      for (var e in categorias.entries) {
        final carpeta = e.value['controller'].text.trim();
        if (carpeta.isEmpty) {
          context.mostrarSnack("Debe indicar la carpeta para ${e.key}", esCorrecto: false);
          return;
        }
        listaCategorias.add(
          CategoriaInstrumento(categoriaId: e.value['categoriaId'], nombre: e.key, carpetaPartituras: carpeta),
        );
      }
    } else {
      carpetaGeneral = controladorCarpetaGeneral.text.trim();
      if (carpetaGeneral.isEmpty) {
        context.mostrarSnack('Debe indicar la carpeta de partituras', esCorrecto: false);
        return;
      }
    }

    // Crear un ID de instrumento único si es nuevo
    final uuid = Uuid();
    final instrumentoId = widget.instrumentoId ?? uuid.v4();

    final instrumento = Instrumento(
      id: instrumentoId,
      nombre: nombre,
      carpetaPartituras: carpetaGeneral,
      iconoUrl: iconoUrl ?? '',
      categorias: listaCategorias,
    );

    if (await ConsultasInstrumentosBD.nombreInstrumentoExiste(
      bandaId: widget.bandaId,
      nombre: nombre,
      excluirInstrumentoId: widget.instrumentoId,
    )) {
      if (!mounted) return;
      context.mostrarSnack('Ya existe un instrumento con ese nombre', esCorrecto: false);
      return;
    }

    // Guardar instrumento **una sola vez**, con todas las categorías dentro
    await ConsultasInstrumentosBD.guardarInstrumento(bandaId: widget.bandaId, instrumento: instrumento, imagen: imagen);
    if (!mounted) return;
    context.mostrarSnack("Instrumento guardado", esCorrecto: true);
    Navigator.pop(context);
  }

  /// ********************************************************
  ///                  --- Construir UI ---
  ///
  /// - AppBar dinámico según edición o creación.
  /// - Campo nombre.
  /// - Selector visual de icono.
  /// - Interruptor de categorías.
  /// - Renderizado dinámico de carpetas.
  /// - Botón Guardar en bottomNavigationBar.
  /// ********************************************************
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ----------------------------
      //         BARRA SUPERIOR
      // ----------------------------
      appBar: AppBar(title: Text(widget.esEdicion ? "Editar Instrumento" : "Añadir Instrumento")),

      // ----------------------------
      //       CUERPO PRINCIPAL
      // ----------------------------
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            AppInput(controller: controladorNombre, label: "Nombre"),
            const SizedBox(height: 15),
            const Text("Icono", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            InkWell(
              onTap: seleccionarIcono,
              child: imagen != null
                  ? Image.file(imagen!, height: 80, width: 80)
                  : (iconoUrl != null && iconoUrl!.isNotEmpty)
                  ? iconoUrl!.startsWith('assets/')
                        ? Image.asset(iconoUrl!, height: 80, width: 80)
                        : Image.network(iconoUrl!, height: 80, width: 80)
                  : Container(height: 80, width: 80, color: Colors.grey[300], child: const Icon(Icons.add_a_photo)),
            ),
            SwitchListTile(
              title: const Text("¿Tiene categorías?"),
              value: tieneCategorias,
              onChanged: (v) => setState(() {
                tieneCategorias = v;
                categorias.clear();
                controladorCarpetaGeneral.clear();
              }),
            ),
            if (!tieneCategorias) ...[AppInput(controller: controladorCarpetaGeneral, label: "Carpeta de partituras")],
            if (tieneCategorias) ...[
              const SizedBox(height: 10),
              for (var cat in categoriasDisponibles)
                Row(
                  children: [
                    Checkbox(value: categorias.containsKey(cat), onChanged: (v) => toggleCategoria(cat, v!)),
                    SizedBox(width: 90, child: Text(cat)),
                    Expanded(
                      child: categorias.containsKey(cat)
                          ? AppInput(controller: categorias[cat]!['controller'], label: "Carpeta")
                          : AppInput(label: "Carpeta", enabled: false),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),

      // ----------------------------
      //       BOTÓN GUARDAR
      // ----------------------------
      bottomNavigationBar: BotonGuardar(enabled: !cargando, onPressed: guardarInstrumento),
    );
  }
}
