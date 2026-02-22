import 'package:flutter/material.dart';
import 'package:ritmo_app/consultas_bd/instrumentos.dart';
import 'package:ritmo_app/consultas_bd/musicos.dart';
import 'package:ritmo_app/consultas_bd/parametros_banda.dart';
import 'package:ritmo_app/consultas_bd/usuarios.dart';
import 'package:ritmo_app/utiles/widgets.dart';

/// ********************************************************
/// Página de datos de un músico.
///
/// Permite:
/// - Visualizar y editar los datos personales de un músico
///   (nombre, email, teléfono, fecha de nacimiento).
/// - Configurar los datos dentro de la banda:
///     - Activo / inactivo
///     - Instrumento y categoría
///     - Año de primera Semana Santa
///     - Otros accesos a instrumentos
/// - Crear un nuevo músico o editar uno existente.
///
/// Es un [StatefulWidget] porque necesita mantener estado:
/// - Controladores de texto para los campos
/// - Estado de carga y guardado
/// - Selección de dropdowns y switches
/// - Listas dinámicas de instrumentos, categorías y accesos
/// ********************************************************
class PaginaDatosMusico extends StatefulWidget {
  final String? musicoId;
  final String bandaId;
  final bool esAdmin;

  const PaginaDatosMusico({super.key, this.musicoId, required this.bandaId, required this.esAdmin});

  @override
  State<PaginaDatosMusico> createState() => EstadoPaginaDatosMusico();
}

/// ********************************************************
/// Estado de la página de datos del músico.
///
/// Contiene toda la lógica:
/// - Carga inicial de permisos, instrumentos y datos del músico
/// - Gestión dinámica de campos editables según permisos
/// - Conversión de fechas entre String y DateTime
/// - Diálogo para otros accesos a instrumentos
/// - Guardado seguro de datos personales y de banda
/// ********************************************************
class EstadoPaginaDatosMusico extends State<PaginaDatosMusico> {
  final TextEditingController controladorNombre = TextEditingController();
  final TextEditingController controladorEmail = TextEditingController();
  final TextEditingController controladorTelefono = TextEditingController();
  final TextEditingController controladorFechaNacimiento = TextEditingController();
  final TextEditingController controladorFechaAlta = TextEditingController();
  final TextEditingController controladorPassword = TextEditingController();

  bool cargando = false;
  String? instrumentoSeleccionado;
  String? categoriaSeleccionada;
  String? anioSemanaSantaSeleccionado;
  bool activo = true;

  List<Map<String, dynamic>> instrumentos = [];
  List<Map<String, dynamic>> categorias = [];
  List<String> aniosSemanaSanta = [];

  List<Map<String, String>> otrosAccesos = [];

  Map<String, bool> permisosBanda = {};

  /// ********************************************************
  /// Inicialización del estado
  ///
  /// - Genera lista de años para "Primera Semana Santa"
  /// - Configura fecha de alta si es nuevo músico
  /// - Carga permisos de edición, instrumentos y datos del músico
  /// ********************************************************
  @override
  void initState() {
    super.initState();

    // Lista de años disponibles para antigüedad Semana Santa
    final anioActual = DateTime.now().year;
    aniosSemanaSanta = List.generate(anioActual - 1970 + 1, (i) => (anioActual - i).toString());

    // Fecha de alta por defecto
    if (widget.musicoId == null) {
      final hoy = DateTime.now();
      controladorFechaAlta.text =
          "${hoy.day.toString().padLeft(2, '0')}/${hoy.month.toString().padLeft(2, '0')}/${hoy.year}";
    }

    // Cargar permisos e instrumentos y luego datos si es edición
    () async {
      setState(() => cargando = true);
      await cargarPermisosEdicion();
      await cargarInstrumentos();
      if (widget.musicoId != null) {
        await cargarDatosMusico();
      }
      setState(() => cargando = false);
    }();
  }

  /// ********************************************************
  /// Liberación de recursos
  ///
  /// - Importante liberar los controladores de texto para evitar fugas de memoria.
  /// ********************************************************
  @override
  void dispose() {
    controladorNombre.dispose();
    controladorEmail.dispose();
    controladorTelefono.dispose();
    controladorFechaNacimiento.dispose();
    controladorFechaAlta.dispose();
    controladorPassword.dispose();
    super.dispose();
  }

  /// ********************************************************
  /// Comprueba si el usuario tiene permiso para editar un campo.
  /// ********************************************************
  bool tienePermiso(String permiso) {
    if (widget.esAdmin) return true;
    return permisosBanda[permiso] ?? false;
  }

  /// ********************************************************
  /// Carga permisos de edición desde la base de datos
  ///
  /// - Si falla, asigna permisos por defecto (todo bloqueado)
  /// ********************************************************
  Future<void> cargarPermisosEdicion() async {
    try {
      permisosBanda = await ConsultasParametrosBD.obtenerPermisosEdicion(widget.bandaId);
    } catch (e) {
      permisosBanda = {
        'nombre': false,
        'telefono': false,
        'fechaNacimiento': false,
        'fechaAlta': false,
        'primerAnoSemanaSanta': false,
        'instrumento': false,
        'categoria': false,
        'otrosAccesos': false,
      };
    }
  }

  /// ********************************************************
  /// Carga instrumentos y categorías desde la base de datos
  ///
  /// - Organiza las categorías según instrumento
  /// - Mantiene consistencia si ya hay un instrumento seleccionado
  /// ********************************************************
  Future<void> cargarInstrumentos() async {
    setState(() => cargando = true);
    try {
      final datos = await ConsultasInstrumentosBD.obtenerInstrumentosYCategorias(widget.bandaId);

      instrumentos = (datos['instrumentos'] as Map<String, String>).entries.map((e) {
        final mapaCategorias = (datos['categorias'] as Map<String, Map<String, String>>)[e.key] ?? {};
        final listaCategorias = mapaCategorias.entries.map((c) => {'categoriaId': c.key, 'nombre': c.value}).toList();
        return <String, dynamic>{'id': e.key, 'nombre': e.value, 'categorias': listaCategorias};
      }).toList()..sort((a, b) => (a['nombre'] as String).compareTo(b['nombre'] as String));

      if (instrumentoSeleccionado != null) {
        final inst = instrumentos.firstWhere(
          (i) => i['id'] == instrumentoSeleccionado,
          orElse: () => <String, dynamic>{'id': '', 'nombre': '', 'categorias': <Map<String, dynamic>>[]},
        );
        categorias = List<Map<String, dynamic>>.from(inst['categorias'] ?? []);
      } else {
        categorias = [];
      }
    } catch (e) {
      categorias = [];
      instrumentos = [];
      if (mounted) context.mostrarSnack('Error al cargar instrumentos: $e', esCorrecto: false);
    }
    setState(() => cargando = false);
  }

  /// ********************************************************
  /// Muestra un diálogo para configurar "Otros accesos"
  ///
  /// - Permite asignar al músico acceso a otros instrumentos o categorías
  /// - Los checkboxes se habilitan según permisos
  /// ********************************************************
  Future<void> mostrarOtrosAccesos() async {
    final permisoEdit = tienePermiso('otrosAccesos');
    final List<Map<String, dynamic>> todosInstrumentos = instrumentos;
    List<Map<String, String>> accesosTemp = List.from(otrosAccesos);

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            //Preparación de lista de instrumento-categoría seleccionables
            final List<Widget> listaCheckboxes = [];

            for (final inst in todosInstrumentos) {
              final List<Map<String, dynamic>> categoriasInst =
                  (inst['categorias'] as List<Map<String, dynamic>>?) ?? [];

              if (categoriasInst.isEmpty) {
                final exists = accesosTemp.any((a) => a['instrumento'] == inst['id'] && a['categoria'] == '');

                listaCheckboxes.add(
                  CheckboxListTile(
                    title: Text(inst['nombre']),
                    value: exists,
                    dense: true,
                    onChanged: permisoEdit
                        ? (v) {
                            setStateDialog(() {
                              if (v == true) {
                                accesosTemp.add({'instrumento': inst['id'], 'categoria': ''});
                              } else {
                                accesosTemp.removeWhere((a) => a['instrumento'] == inst['id'] && a['categoria'] == '');
                              }
                            });
                          }
                        : null,
                  ),
                );
              } else {
                for (final cat in categoriasInst) {
                  final catId = (cat['categoriaId'] ?? '').toString();
                  final exists = accesosTemp.any((a) => a['instrumento'] == inst['id'] && a['categoria'] == catId);

                  listaCheckboxes.add(
                    CheckboxListTile(
                      title: Text('${inst['nombre']} - ${cat['nombre']}'),
                      value: exists,
                      dense: true,
                      onChanged: permisoEdit
                          ? (v) {
                              setStateDialog(() {
                                if (v == true) {
                                  accesosTemp.add({'instrumento': inst['id'], 'categoria': catId});
                                } else {
                                  accesosTemp.removeWhere(
                                    (a) => a['instrumento'] == inst['id'] && a['categoria'] == catId,
                                  );
                                }
                              });
                            }
                          : null,
                    ),
                  );
                }
              }
            }

            // Diálogo de otros accesos a instrumentos
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              content: DialogoBase(
                icono: Icons.lock_outline,
                titulo: 'Otros accesos',
                children: [
                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.maxFinite,
                    height: 350, // altura controlada para scroll elegante
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: listaCheckboxes),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // BOTONES
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancelar"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: BotonPrimarioDialogo(
                          label: "Guardar",
                          icon: Icons.save,
                          onPressed: () {
                            if (permisoEdit) {
                              setState(() {
                                otrosAccesos = accesosTemp;
                              });
                            }
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// ********************************************************
  /// Conversor de fechas
  ///
  /// - Convierte string dd/MM/yyyy a [DateTime]
  /// ********************************************************
  DateTime parseFecha(String v) {
    final p = v.split('/');
    return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
  }

  /// ********************************************************
  /// Carga los datos del músico para edición
  ///
  /// - Datos personales y de banda
  /// - Otros accesos a instrumentos
  /// - Configura dropdowns y listas según selección previa
  /// ********************************************************
  Future<void> cargarDatosMusico() async {
    if (widget.musicoId == null) return;
    setState(() => cargando = true);

    try {
      final datos = await ConsultasMusicosBD.obtenerDatosMusico(widget.bandaId, widget.musicoId!);

      controladorNombre.text = datos.nombre;
      controladorEmail.text = datos.email;
      controladorTelefono.text = datos.telefono;

      if (datos.fechaNacimiento != null) {
        final fn = datos.fechaNacimiento!;
        controladorFechaNacimiento.text =
            "${fn.day.toString().padLeft(2, '0')}/${fn.month.toString().padLeft(2, '0')}/${fn.year}";
      }

      activo = datos.banda.activo;
      instrumentoSeleccionado = datos.banda.instrumento;
      categoriaSeleccionada = datos.banda.categoria;
      anioSemanaSantaSeleccionado = datos.banda.anioPrimeraSemanaSanta?.toString();

      otrosAccesos = datos.otrosAccesos
          .map((a) => {'instrumento': a.instrumentoId, 'categoria': a.categoriaId ?? ''})
          .toList();

      final fechaAlta = datos.banda.fechaAlta;
      controladorFechaAlta.text =
          "${fechaAlta.day.toString().padLeft(2, '0')}/${fechaAlta.month.toString().padLeft(2, '0')}/${fechaAlta.year}";

      if (instrumentoSeleccionado != null) {
        final inst = instrumentos.firstWhere(
          (i) => i['id'] == instrumentoSeleccionado,
          orElse: () => <String, dynamic>{'id': '', 'nombre': '', 'categorias': <Map<String, dynamic>>[]},
        );
        categorias = List<Map<String, dynamic>>.from(inst['categorias'] ?? []);

        if (categorias.isEmpty) {
          categorias = [
            {'categoriaId': '', 'nombre': ''},
          ];
        }
      } else {
        categorias = [];
      }
    } catch (e) {
      if (mounted) context.mostrarSnack("Error al cargar datos del músico: $e", esCorrecto: false);
    }

    setState(() => cargando = false);
  }

  /// ********************************************************
  /// Selección de fechas mediante DatePicker
  ///
  /// - Actualiza el TextEditingController correspondiente
  /// ********************************************************
  Future<void> seleccionarFecha(TextEditingController ctrl, {DateTime? initialDate}) async {
    final ahora = DateTime.now();
    final fechaNacimiento = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime(ahora.year),
      firstDate: DateTime(ahora.year - 100),
      lastDate: DateTime(ahora.year),
      locale: const Locale('es', 'ES'),
    );

    if (fechaNacimiento != null) {
      ctrl.text =
          "${fechaNacimiento.day.toString().padLeft(2, '0')}/${fechaNacimiento.month.toString().padLeft(2, '0')}/${fechaNacimiento.year}";
    }
  }

  /// ********************************************************
  /// Guarda los datos del músico en Firebase
  ///
  /// - Si es un músico existente, actualiza datos
  /// - Si es nuevo, crea usuario y músico
  /// - Valida selección de instrumento y categoría
  /// - Muestra feedback al usuario mediante SnackBar
  /// ********************************************************
  Future<void> guardarDatosMusico() async {
    // VALIDACIÓN INSTRUMENTO / CATEGORÍA
    if (instrumentoSeleccionado != null) {
      final inst = instrumentos.firstWhere(
        (i) => i['id'] == instrumentoSeleccionado,
        orElse: () => <String, dynamic>{'categorias': <Map<String, dynamic>>[]},
      );

      final List<Map<String, dynamic>> categoriasInst = List<Map<String, dynamic>>.from(inst['categorias'] ?? []);

      // Si el instrumento tiene categorías y no se eligió ninguna → error
      if (categoriasInst.isNotEmpty && categoriaSeleccionada == null) {
        context.mostrarSnack("Debe seleccionar una categoría para el instrumento elegido", esCorrecto: false);
        return;
      }
    }

    setState(() => cargando = true);

    try {
      if (widget.musicoId != null) {
        // Guardar datos personales
        await ConsultasUsuariosBD.actualizarUsuario(
          uid: widget.musicoId!,
          nombre: controladorNombre.text.trim(),
          email: controladorEmail.text.trim(),
          telefono: controladorTelefono.text.trim(),
          fechaNacimiento: controladorFechaNacimiento.text.isNotEmpty
              ? parseFecha(controladorFechaNacimiento.text)
              : null,
        );

        // Guardar datos de banda
        await ConsultasMusicosBD.guardarDatosMusico(
          bandaId: widget.bandaId,
          musicoId: widget.musicoId!,
          activo: activo,
          instrumento: instrumentoSeleccionado,
          categoria: categoriaSeleccionada,
          anioPrimeraSemanaSanta: int.tryParse(anioSemanaSantaSeleccionado ?? ''),
          fechaAlta: controladorFechaAlta.text.isNotEmpty ? parseFecha(controladorFechaAlta.text) : null,
          otrosAccesos: otrosAccesos,
        );
      } else {
        // Nuevo usuario
        await ConsultasUsuariosBD.crearUsuarioYMusico(
          bandaId: widget.bandaId,
          nombre: controladorNombre.text.trim(),
          email: controladorEmail.text.trim(),
          password: controladorPassword.text.trim(),
          telefono: controladorTelefono.text.trim(),
          fechaNacimiento: controladorFechaNacimiento.text.isNotEmpty
              ? parseFecha(controladorFechaNacimiento.text)
              : null,
          activo: activo,
          rol: "musico",
          instrumento: instrumentoSeleccionado,
          categoria: categoriaSeleccionada,
          anioPrimeraSemanaSanta: int.tryParse(anioSemanaSantaSeleccionado ?? ''),
          fechaAlta: controladorFechaAlta.text.isNotEmpty ? parseFecha(controladorFechaAlta.text) : null,
          otrosAccesos: otrosAccesos,
        );
      }

      if (!mounted) return;
      context.mostrarSnack('Datos guardados correctamente', esCorrecto: true);
      Navigator.pop(context, true);
    } catch (e) {
      // Cualquier otro error
      if (!mounted) return;
      context.mostrarSnack('Error al guardar', esCorrecto: false);
    } finally {
      setState(() => cargando = false);
    }
  }

  /// ***********************************************
  /// Estilos
  /// ***********************************************
  Color fondoCampo(bool editable) => editable ? Colors.white : Colors.grey.shade200;
  Color colorBloqueado() => Colors.grey.shade500;

  InputDecoration inputDeco(String label, bool editable) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: fondoCampo(editable),
      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      suffixIcon: !editable ? Icon(Icons.lock, size: 16, color: colorBloqueado()) : null,
    );
  }

  /// ********************************************************
  ///                  --- Construir UI ---
  ///
  /// - AppBar dinámico según edición o nuevo músico
  /// - Campos personales y de banda
  /// - Dropdowns de instrumentos, categorías y años
  /// - Botón "Otros Accesos" con diálogo
  /// - Botón Guardar en bottomNavigationBar
  /// - Manejo de estado de carga con CircularProgressIndicator
  /// ********************************************************
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ----------------------------
      //         BARRA SUPERIOR
      // ----------------------------
      appBar: AppBar(title: Text(widget.musicoId == null ? "Nuevo Músico" : "Datos Músico")),

      // ----------------------------
      //       CUERPO PRINCIPAL
      // ----------------------------
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Datos personales", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    AppInput(
                      label: "Nombre",
                      controller: controladorNombre,
                      permiso: 'nombre',
                      tienePermiso: tienePermiso,
                    ),
                    AppInput(
                      label: "Email",
                      controller: controladorEmail,
                      permiso: 'email',
                      tienePermiso: tienePermiso,
                      readOnly: widget.musicoId != null,
                    ),
                    if (widget.musicoId == null)
                      AppInput(
                        label: "Contraseña",
                        controller: controladorPassword,
                        permiso: 'password',
                        tienePermiso: tienePermiso,
                        obscureText: true,
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: AppInput(
                            label: "Teléfono",
                            controller: controladorTelefono,
                            permiso: 'telefono',
                            tienePermiso: tienePermiso,
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AppInput(
                            label: "Fecha nacimiento",
                            controller: controladorFechaNacimiento,
                            permiso: 'fechaNacimiento',
                            tienePermiso: tienePermiso,
                            readOnly: true,
                            onTap: tienePermiso('fechaNacimiento')
                                ? () => seleccionarFecha(controladorFechaNacimiento)
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Datos en la banda", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            const Text("Activo"),
                            Transform.scale(
                              scale: 0.7,
                              child: Switch(
                                value: activo,
                                onChanged: tienePermiso('activo') ? (v) => setState(() => activo = v) : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: AppInput(
                            label: "Fecha alta",
                            controller: controladorFechaAlta,
                            permiso: 'fechaAlta',
                            tienePermiso: tienePermiso,
                            readOnly: true,
                            onTap: tienePermiso('fechaAlta') ? () => seleccionarFecha(controladorFechaAlta) : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: anioSemanaSantaSeleccionado,
                            decoration: inputDeco("Año 1ª Semana Santa", tienePermiso('primerAnoSemanaSanta')),
                            items: aniosSemanaSanta.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                            onChanged: tienePermiso('primerAnoSemanaSanta')
                                ? (v) => setState(() => anioSemanaSantaSeleccionado = v)
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue:
                                instrumentoSeleccionado != null &&
                                    instrumentos.any((i) => i['id'] == instrumentoSeleccionado)
                                ? instrumentoSeleccionado
                                : null, // null si no existe en la lista
                            decoration: inputDeco("Instrumento", tienePermiso('instrumento')),
                            items: [
                              // Opcional: mostrar un item "Sin instrumento" si es null
                              const DropdownMenuItem(value: null, child: Text("Sin instr.")),
                              ...instrumentos.map(
                                (i) => DropdownMenuItem<String>(value: i['id'], child: Text(i['nombre'])),
                              ),
                            ],
                            onChanged: tienePermiso('instrumento')
                                ? (val) {
                                    setState(() {
                                      instrumentoSeleccionado = val;

                                      // Actualizar categorías
                                      if (val != null) {
                                        final inst = instrumentos.firstWhere(
                                          (i) => i['id'] == val,
                                          orElse: () => <String, dynamic>{'categorias': <Map<String, dynamic>>[]},
                                        );
                                        categorias = List<Map<String, dynamic>>.from(inst['categorias'] ?? []);
                                      } else {
                                        categorias = [];
                                      }

                                      categoriaSeleccionada = null; // reset
                                    });
                                  }
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue:
                                  categoriaSeleccionada != null &&
                                      categorias.any((c) => c['categoriaId'] == categoriaSeleccionada)
                                  ? categoriaSeleccionada
                                  : null, // null si no existe
                              decoration: inputDeco("Categoría", tienePermiso('categoria')),
                              items: [
                                const DropdownMenuItem(value: null, child: Text("Sin categoría")),
                                ...categorias.map(
                                  (c) => DropdownMenuItem<String>(value: c['categoriaId'], child: Text(c['nombre'])),
                                ),
                              ],
                              onChanged: tienePermiso('categoria')
                                  ? (val) => setState(() => categoriaSeleccionada = val)
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: BotonAPantalla(
                        label: "OTROS ACCESOS",
                        icon: Icons.lock_outline,
                        onPressed: mostrarOtrosAccesos,
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),

      // ----------------------------
      //       BOTÓN GUARDAR
      // ----------------------------
      bottomNavigationBar: BotonGuardar(enabled: !cargando, onPressed: guardarDatosMusico),
    );
  }
}
