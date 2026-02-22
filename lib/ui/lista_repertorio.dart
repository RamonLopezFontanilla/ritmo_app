import 'package:flutter/material.dart';
import 'package:ritmo_app/consultas_bd/instrumentos.dart';
import 'package:ritmo_app/consultas_bd/musicos.dart';
import 'package:ritmo_app/consultas_bd/partituras.dart';
import 'package:ritmo_app/consultas_bd/repertorios.dart';
import 'package:ritmo_app/modelos/partitura.dart';
import 'package:ritmo_app/modelos/partitura_repertorio.dart';
import 'package:ritmo_app/ui/lista_partituras.dart';
import 'package:ritmo_app/utiles/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// ****************************************************************
/// Página de lista de repertorio de un evento
///
/// Funcionalidades:
/// - Ver partituras asociadas al evento
/// - Seleccionar acceso del músico (si no es admin)
/// - Abrir partituras según el acceso
/// - Administrar repertorio si es admin (agregar, eliminar, mover)
/// ****************************************************************
class PaginaListaRepertorio extends StatefulWidget {
  final String bandaId;
  final bool esAdmin;
  final String eventoId;
  final String musicoId;

  const PaginaListaRepertorio({
    super.key,
    required this.bandaId,
    required this.esAdmin,
    required this.eventoId,
    required this.musicoId,
  });

  @override
  State<PaginaListaRepertorio> createState() => EstadoPaginaListaRepertorio();
}

/// ****************************************************************
/// Estado de la página de repertorio
///
/// Guarda todos los datos que cambian:
/// - Selección de partitura
/// - Selección de acceso del músico
/// - Lista de accesos disponibles
/// - Indicador de carga
/// ****************************************************************
class EstadoPaginaListaRepertorio extends State<PaginaListaRepertorio> {
  String? seleccionadoId;
  String? accesoSeleccionado;
  List<Map<String, dynamic>> accesosDisponibles = [];
  bool cargando = true;

  /// **************************************************************
  /// Inicialización
  ///
  /// Si no es admin, carga los accesos del músico (instrumentos disponibles para ese músico)
  /// **************************************************************
  @override
  void initState() {
    super.initState();
    if (!widget.esAdmin) {
      cargarAccesosMusico();
    } else {
      cargando = false;
    }
  }

  /// **************************************************************
  /// Cargar accesos del músico
  ///
  /// - Obtiene instrumento principal y otros accesos
  /// - Evita duplicados
  /// - Ordena alfabéticamente
  /// **************************************************************
  Future<void> cargarAccesosMusico() async {
    setState(() => cargando = true);

    try {
      // Traemos el documento del músico
      final docMusico = await ConsultasMusicosBD.obtenerDocumentoMusico(
        bandaId: widget.bandaId,
        musicoId: widget.musicoId,
      );

      if (docMusico == null) {
        setState(() {
          accesosDisponibles = [];
          accesoSeleccionado = null;
          cargando = false;
        });
        return;
      }

      // Construimos la lista de accesos (principal + otros)
      final List<Map<String, dynamic>> listaAccesos = [];
      final Set<String> accesosUnicos = {};

      void agregarAcceso({
        required String key,
        required String instrumentoId,
        String? categoriaId,
        required String nombre,
      }) {
        final identificador = '$instrumentoId-${categoriaId ?? ''}';

        if (!accesosUnicos.contains(identificador)) {
          accesosUnicos.add(identificador);

          listaAccesos.add({'key': key, 'instrumentoId': instrumentoId, 'categoriaId': categoriaId, 'nombre': nombre});
        }
      }

      // --- Acceso principal ---
      final String? instrumentoPrincipal = docMusico['instrumento'];
      final String? categoriaPrincipal = docMusico['categoria'];

      if (instrumentoPrincipal != null) {
        final nombre = await ConsultasInstrumentosBD.obtenerNombreInstrumentoCategoria(
          instrumentoPrincipal,
          categoriaPrincipal,
          widget.bandaId,
        );

        agregarAcceso(
          key: 'principal',
          instrumentoId: instrumentoPrincipal,
          categoriaId: categoriaPrincipal,
          nombre: nombre,
        );
      }

      // --- Otros accesos ---
      final List otrosAccesos = docMusico['otrosAccesos'] ?? [];
      for (int i = 0; i < otrosAccesos.length; i++) {
        final acceso = otrosAccesos[i];
        final String? instrumentoId = acceso['instrumento'];
        final String? categoriaId = acceso['categoria'];

        if (instrumentoId != null) {
          final nombre = await ConsultasInstrumentosBD.obtenerNombreInstrumentoCategoria(
            instrumentoId,
            categoriaId,
            widget.bandaId,
          );

          agregarAcceso(key: 'otros_$i', instrumentoId: instrumentoId, categoriaId: categoriaId, nombre: nombre);
        }
      }

      // Orden alfabético
      listaAccesos.sort((a, b) => (a['nombre'] ?? '').compareTo(b['nombre'] ?? ''));

      setState(() {
        accesosDisponibles = listaAccesos;
        accesoSeleccionado = 'principal'; // seleccionamos el principal
        cargando = false;
      });
    } catch (e) {
      debugPrint('Error cargando accesos: $e');
      setState(() {
        accesosDisponibles = [];
        accesoSeleccionado = null;
        cargando = false;
      });
    }
  }

  /// **************************************************************
  /// Obtener instrumentoId y categoriaId desde la key seleccionada
  /// **************************************************************
  Map<String, String?> obtenerIdsDesdeKey(String key) {
    final acceso = accesosDisponibles.firstWhere((a) => a['key'] == key, orElse: () => {});

    return {'instrumentoId': acceso['instrumentoId'], 'categoriaId': acceso['categoriaId']};
  }

  /// **************************************************************
  /// Abrir partitura según el acceso del músico
  /// **************************************************************
  Future<void> abrirPartitura(PartituraRepertorio item) async {
    if (widget.esAdmin || accesoSeleccionado == null) return;

    // Obtenemos los IDs reales
    final ids = obtenerIdsDesdeKey(accesoSeleccionado!);
    final instrumentoId = ids['instrumentoId'];
    final categoriaId = ids['categoriaId'];

    if (instrumentoId == null) return;

    final instrumentoCat = '$instrumentoId|${categoriaId ?? ''}';

    // Obtenemos la partitura desde Firestore
    final partitura = await ConsultasPartiturasBD.obtenerPartitura(widget.bandaId, item.partituraId);

    if (partitura == null) {
      if (!mounted) return;
      context.mostrarSnack('No se encontró la partitura', esCorrecto: false);
      return;
    }

    // Obtenemos la URI
    final uri = await ConsultasPartiturasBD.obtenerUriPartitura(
      bandaId: widget.bandaId,
      archivo: partitura.archivo,
      instrumentoCat: instrumentoCat,
    );

    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      context.mostrarSnack('No se pudo abrir la partitura ${partitura.titulo}', esCorrecto: false);
    }
  }

  /// **************************************************************
  /// Mover partitura en la lista de repertorio
  ///
  /// Solo admins:
  /// - Se intercambian dos partituras adyacentes.
  /// - Se actualiza el orden en BD.
  /// **************************************************************
  Future<void> mover(List<PartituraRepertorio> lista, int i, int dir) async {
    final a = lista[i];
    final b = lista[i + dir];

    // Aquí debes llamar a tu método en ConsultasBD que intercambia los órdenes
    await ConsultasRepertoriosBD.moverRepertorio(
      bandaId: widget.bandaId,
      eventoId: widget.eventoId,
      docIdA: a.docId,
      ordenA: a.orden,
      docIdB: b.docId,
      ordenB: b.orden,
    );

    setState(() {
      lista[i] = b;
      lista[i + dir] = a;
    });
  }

  /// **************************************************************
  ///                  --- Construir UI ---
  ///
  /// - AppBar: barra superior con el título.
  /// - Botón flotante (solo admins): permite agregar nuevas partituras al repertorio.
  /// - Cuerpo principal:
  ///    a) Dropdown de accesos (solo para músicos, no admins) para filtrar partituras según instrumento/categoría.
  ///    b) Lista de partituras en tiempo real, utilizando StreamBuilder para escuchar cambios en Firestore.
  ///       - Admins: pueden seleccionar, mover y eliminar partituras.
  ///       - Músicos: pueden abrir partituras según su acceso seleccionado.
  /// **************************************************************
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ----------------------------
      //         BARRA SUPERIOR
      // ----------------------------
      appBar: AppBar(title: const Text('Repertorio del evento')),

      // ----------------------------
      //         BOTÓN FLOTANTE
      // ----------------------------
      floatingActionButton: widget.esAdmin
          ? FloatingActionButton(
              child: const Icon(Icons.add),
              onPressed: () async {
                final resultado = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PaginaListaPartituras(
                      bandaId: widget.bandaId,
                      esAdmin: true,
                      musicoId: widget.musicoId,
                      modoSeleccion: true,
                    ),
                  ),
                );

                if (resultado == null) return;

                final Partitura partitura = resultado['datos'] as Partitura;

                // Calcular el orden automáticamente dentro de ConsultasBD
                await ConsultasRepertoriosBD.agregarPartituraAlRepertorio(
                  bandaId: widget.bandaId,
                  eventoId: widget.eventoId,
                  partitura: partitura,
                  orden: await ConsultasRepertoriosBD.obtenerSiguienteOrden(widget.bandaId, widget.eventoId),
                );
              },
            )
          : null,

      // ----------------------------
      //       CUERPO PRINCIPAL
      // ----------------------------
      body: Column(
        children: [
          if (!widget.esAdmin)
            Padding(
              padding: const EdgeInsets.all(12),
              child: cargando
                  ? const LinearProgressIndicator()
                  : accesosDisponibles.isEmpty
                  ? const Text("No hay accesos disponibles")
                  : AppDropdown<String>(
                      value: accesoSeleccionado,
                      label: 'Acceso',
                      items: accesosDisponibles
                          .map((a) => DropdownMenuItem<String>(value: a['key'], child: Text(a['nombre'] ?? '')))
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          accesoSeleccionado = v;
                        });
                      },
                    ),
            ),

          // ---------------------------------------
          //       LISTA PARTITURAS REPERTORIO
          // ---------------------------------------
          Expanded(
            child: StreamBuilder<List<PartituraRepertorio>>(
              stream: ConsultasRepertoriosBD.streamRepertorio(widget.bandaId, widget.eventoId),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());

                final lista = widget.esAdmin
                    ? snap.data!
                    : snap.data!.where((p) => p.accesoKey == '' || p.accesoKey == accesoSeleccionado).toList();

                return ListView.builder(
                  itemCount: lista.length,
                  itemBuilder: (context, i) {
                    final item = lista[i];
                    final seleccionado = item.docId == seleccionadoId;

                    return InkWell(
                      onTap: () {
                        if (widget.esAdmin) {
                          setState(() => seleccionadoId = seleccionado ? null : item.docId);
                        } else {
                          abrirPartitura(item);
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: seleccionado ? Colors.blue.shade50 : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border(left: BorderSide(color: seleccionado ? Colors.green : Colors.blue, width: 6)),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(2, 3))],
                        ),
                        child: Row(
                          children: [
                            Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(item.titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            if (widget.esAdmin && seleccionado)
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_upward),
                                    onPressed: i > 0 ? () => mover(lista, i, -1) : null,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.arrow_downward),
                                    onPressed: i < lista.length - 1 ? () => mover(lista, i, 1) : null,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () async {
                                      await ConsultasRepertoriosBD.eliminarPartituraDelRepertorio(
                                        bandaId: widget.bandaId,
                                        eventoId: widget.eventoId,
                                        docId: item.docId,
                                      );
                                      setState(() => seleccionadoId = null);
                                    },
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
