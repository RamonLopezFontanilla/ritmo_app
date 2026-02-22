import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:ritmo_app/consultas_bd/ubicaciones.dart';
import 'package:ritmo_app/modelos/ubicacion.dart';
import 'package:ritmo_app/utiles/widgets.dart';

/// ****************************************************************
/// Página de creación y edición de una ubicación.
///
/// Permite:
/// - Crear un nuevo sitio asociado a la banda.
/// - Editar una ubicación existente.
/// - Buscar direcciones usando Nominatim (OpenStreetMap).
/// - Obtener coordenadas desde una dirección seleccionada.
/// - Obtener ubicación actual del dispositivo (GPS).
/// - Guardar nombre, dirección, latitud y longitud.
///
/// Es un [StatefulWidget] porque:
/// - Mantiene controladores de texto.
/// - Gestiona estado de carga.
/// - Gestiona resultados dinámicos de búsqueda.
/// - Utiliza debounce para evitar llamadas excesivas a la API.
/// ****************************************************************
class PaginaDatosUbicacion extends StatefulWidget {
  final String bandaId;
  final Ubicacion? ubicacion;

  const PaginaDatosUbicacion({super.key, required this.bandaId, this.ubicacion});

  @override
  State<PaginaDatosUbicacion> createState() => EstadoPaginaDatosUbicacion();
}

/// ****************************************************************
/// Estado de la página de datos de una ubicación.
///
/// Responsabilidades:
/// - Inicializar datos en modo edición.
/// - Gestionar búsqueda de direcciones con debounce.
/// - Gestionar permisos y captura de ubicación GPS.
/// - Validar datos antes de guardar.
/// - Construir objeto [Ubicacion] y persistirlo.
/// ****************************************************************
class EstadoPaginaDatosUbicacion extends State<PaginaDatosUbicacion> {
  final TextEditingController controladorNombre = TextEditingController();
  final TextEditingController controladorDireccion = TextEditingController();
  final TextEditingController controladorLatitud = TextEditingController();
  final TextEditingController controladorLongitud = TextEditingController();
  bool get esEdicion => widget.ubicacion != null;

  List<Map<String, dynamic>> resultados = [];
  bool cargando = false;
  Timer? debounce;

  /// ***********************************************
  /// Inicialización
  /// Si estamos editando se cargan los datos existentes en los controladores.
  ///************************************************
  @override
  void initState() {
    super.initState();

    if (widget.ubicacion != null) {
      controladorNombre.text = widget.ubicacion!.nombre;
      controladorDireccion.text = widget.ubicacion!.direccion;
      controladorLatitud.text = widget.ubicacion!.latitud.toString();
      controladorLongitud.text = widget.ubicacion!.longitud.toString();
    }
  }

  /// ***********************************************
  /// Liberación de memoria
  /// - Cancela el debounce activo.
  /// - Libera todos los controladores.
  /// - Evita fugas de memoria.
  ///************************************************
  @override
  void dispose() {
    debounce?.cancel();
    controladorNombre.dispose();
    controladorDireccion.dispose();
    controladorLatitud.dispose();
    controladorLongitud.dispose();
    super.dispose();
  }

  /// ***********************************************
  /// Buscar direcciones (API Nominatim)
  ///
  /// Flujo:
  /// - Si query vacío → no busca.
  /// - Primer intento acotado a España (viewbox).
  /// - Si no hay resultados → búsqueda global.
  /// - Devuelve lista de mapas con lat, lon y display_name.
  ///
  /// Se usa OpenStreetMap Nominatim.
  ///
  /// ************************************************
  Future<List<Map<String, dynamic>>> buscarDirecciones(String query) async {
    if (query.isEmpty) return [];

    try {
      final viewbox = '-9.5,36.0,4.5,43.9';
      var url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&viewbox=$viewbox&bounded=1',
      );

      var response = await http.get(url, headers: {'User-Agent': 'ritmo_app_flutter'});

      if (response.statusCode == 200) {
        final List datos = jsonDecode(response.body);
        if (datos.isNotEmpty) return datos.cast<Map<String, dynamic>>();
      }

      url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1');

      response = await http.get(url, headers: {'User-Agent': 'ritmo_app_flutter'});

      if (response.statusCode == 200) {
        final List datos = jsonDecode(response.body);
        return datos.cast<Map<String, dynamic>>();
      }

      return [];
    } catch (e) {
      debugPrint('Error: $e');
      return [];
    }
  }

  /// ************************************************
  /// Debounce búsqueda
  ///
  /// Evita hacer peticiones por cada pulsación.
  /// Espera 600ms tras la última escritura.
  /// ************************************************
  void buscar(String texto) {
    debounce?.cancel();

    debounce = Timer(const Duration(milliseconds: 600), () async {
      if (texto.length < 3) return;

      setState(() => cargando = true);

      final busquedaDirecciones = await buscarDirecciones(texto);

      if (!mounted) return;
      setState(() {
        resultados = busquedaDirecciones;
        cargando = false;
      });

      if (busquedaDirecciones.isEmpty) {
        context.mostrarSnack('No se encontraron resultados', esCorrecto: false);
      }
    });
  }

  /// ***********************************************
  /// Guardar ubicación
  ///
  /// Validaciones:
  /// - Nombre obligatorio
  /// - Dirección obligatoria
  /// - Latitud y longitud válidas
  ///
  /// Construye objeto [Ubicacion] y lo persiste.
  /// ***********************************************
  Future<void> guardarDatosUbicacion() async {
    final nombre = controladorNombre.text.trim();
    final direccion = controladorDireccion.text.trim();
    final lat = double.tryParse(controladorLatitud.text.trim().replaceAll(',', '.'));
    final lng = double.tryParse(controladorLongitud.text.trim().replaceAll(',', '.'));

    if (nombre.isEmpty || direccion.isEmpty || lat == null || lng == null) {
      context.mostrarSnack('Todos los campos son obligatorios y válidos', esCorrecto: false);
      return;
    }

    final ubic = Ubicacion(
      id: widget.ubicacion?.id ?? '',
      nombre: nombre,
      direccion: direccion,
      latitud: lat,
      longitud: lng,
    );

    try {
      await ConsultasUbicacionesBD.guardarUbicacion(
        bandaId: widget.bandaId,
        ubicacionId: esEdicion ? widget.ubicacion!.id : null,
        ubicacion: ubic,
      );

      if (!mounted) return;
      context.mostrarSnack(esEdicion ? 'Sitio actualizado' : 'Sitio añadido', esCorrecto: true);
      Navigator.pop(context);
    } catch (e) {
      context.mostrarSnack('Error guardando sitio', esCorrecto: false);
    }
  }

  /// *******************************************************
  /// Obtener ubicación actual del dispositivo
  ///
  /// Flujo:
  /// - Verifica que GPS esté activado.
  /// - Comprueba permisos.
  /// - Solicita permisos si es necesario.
  /// - Obtiene coordenadas con alta precisión.
  /// - Realiza reverse geocoding para obtener dirección a partir de coordenadas.
  /// *******************************************************
  Future<void> obtenerUbicacionActual() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      if (!serviceEnabled) {
        context.mostrarSnack('El GPS está desactivado', esCorrecto: false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!mounted) return;
        if (permission == LocationPermission.denied) {
          context.mostrarSnack('Permiso de ubicación denegado', esCorrecto: false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        context.mostrarSnack('Permisos de ubicación bloqueados', esCorrecto: false);
        return;
      }

      setState(() => cargando = true);

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      controladorLatitud.text = position.latitude.toStringAsFixed(6);
      controladorLongitud.text = position.longitude.toStringAsFixed(6);

      // Obtener dirección a partir de coordenadas
      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        controladorDireccion.text = '${p.street}, ${p.locality}, ${p.administrativeArea}, ${p.country}';
      }
      if (!mounted) return;
      context.mostrarSnack('Ubicación actual capturada', esCorrecto: true);
    } catch (e) {
      context.mostrarSnack('Error obteniendo ubicación: $e', esCorrecto: false);
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  /// ***********************************************
  ///              --- Construcción UI ---
  ///
  /// Estructura:
  /// - AppBar dinámico (crear / editar)
  /// - Formulario con:
  ///     - Nombre
  ///     - Dirección (con búsqueda)
  ///     - Latitud / Longitud
  ///     - Botón usar ubicación actual
  /// - Lista dinámica de resultados
  /// - Botón guardar fijo inferior
  /// ***********************************************
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ----------------------------
      //         BARRA SUPERIOR
      // ----------------------------
      appBar: AppBar(title: Text(esEdicion ? 'Editar Sitio' : 'Añadir Sitio')),

      // ----------------------------
      //       CUERPO PRINCIPAL
      // ----------------------------
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              children: [
                AppInput(controller: controladorNombre, label: 'Nombre'),
                const SizedBox(height: 8),

                AppInput(controller: controladorDireccion, label: 'Dirección', onChanged: buscar),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: AppInput(
                        controller: controladorLatitud,
                        label: 'Latitud',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AppInput(
                        controller: controladorLongitud,
                        label: 'Longitud',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                BotonAPantalla(
                  icon: Icons.my_location,
                  label: 'Usar mi ubicación actual',
                  onPressed: obtenerUbicacionActual,
                ),

                const SizedBox(height: 16),
                if (cargando) const CircularProgressIndicator(),

                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: resultados.length,
                  itemBuilder: (context, index) {
                    final item = resultados[index];
                    return ListTile(
                      title: Text(item['display_name'] ?? ''),
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        setState(() {
                          controladorDireccion.text = item['display_name'];
                          controladorLatitud.text = item['lat'].toString();
                          controladorLongitud.text = item['lon'].toString();
                          resultados.clear();
                        });
                      },
                    );
                  },
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),

      // ----------------------------
      //       BOTÓN GUARDAR
      // ----------------------------
      bottomNavigationBar: BotonGuardar(enabled: !cargando, onPressed: guardarDatosUbicacion),
    );
  }
}
