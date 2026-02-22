import 'package:ritmo_app/modelos/parametros_banda.dart';

class Banda {
  final String id;
  final String nombre;
  final String administradorId;
  final String administradorEmail;
  final String novedades;
  final String direccion;
  final String cif;
  final String localidad;
  final String provincia;
  final String cPostal;
  final String telefono;
  final String email;
  final int distancia;
  final int retraso;
  final String rutaPartituras;
  final ParametrosBanda parametros;

  // Constructor
  const Banda({
    required this.id,
    required this.nombre,
    required this.administradorId,
    required this.administradorEmail,
    this.novedades = '',
    this.direccion = '',
    this.cif = '',
    this.localidad = '',
    this.provincia = '',
    this.cPostal = '',
    this.telefono = '',
    this.email = '',
    this.distancia = 0,
    this.retraso = 0,
    this.rutaPartituras = '',
    this.parametros = const ParametrosBanda(),
  });

  /// Crear desde un Map genérico
  factory Banda.fromMap(String id, Map<String, dynamic> data) {
    return Banda(
      id: id,
      nombre: data['nombre'] ?? '',
      administradorId: data['administrador'] ?? '',
      administradorEmail: data['administradorEmail'] ?? '',
      novedades: data['novedades'] ?? '',
      direccion: data['direccion'] ?? '',
      cif: data['cif'] ?? '',
      localidad: data['localidad'] ?? '',
      provincia: data['provincia'] ?? '',
      cPostal: data['cPostal'] ?? '',
      telefono: data['telefono'] ?? '',
      email: data['email'] ?? '',
      distancia: data['distancia'] ?? 0,
      retraso: data['retraso'] ?? 0,
      rutaPartituras: data['rutaPartituras'] ?? '',
      parametros: ParametrosBanda.fromMap(data['parametros'] ?? {}),
    );
  }

  /// Convertir a Map para subir a la base de datos
  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'administrador': administradorId,
      'administradorEmail': administradorEmail,
      'novedades': novedades,
      'direccion': direccion,
      'cif': cif,
      'localidad': localidad,
      'provincia': provincia,
      'cPostal': cPostal,
      'telefono': telefono,
      'email': email,
      'distancia': distancia,
      'retraso': retraso,
      'rutaPartituras': rutaPartituras,
      'parametros': parametros.toMap(),
    };
  }

  /// Clonar un objeto Banda para modificar sólo algunos campos
  Banda copyWith({
    String? nombre,
    String? administradorId,
    String? administradorEmail,
    String? novedades,
    String? direccion,
    String? cif,
    String? localidad,
    String? provincia,
    String? cPostal,
    String? telefono,
    String? email,
    int? distancia,
    int? retraso,
    String? rutaPartituras,
    ParametrosBanda? parametros,
  }) {
    return Banda(
      id: id,
      nombre: nombre ?? this.nombre,
      administradorId: administradorId ?? this.administradorId,
      administradorEmail: administradorEmail ?? this.administradorEmail,
      novedades: novedades ?? this.novedades,
      direccion: direccion ?? this.direccion,
      cif: cif ?? this.cif,
      localidad: localidad ?? this.localidad,
      provincia: provincia ?? this.provincia,
      cPostal: cPostal ?? this.cPostal,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      distancia: distancia ?? this.distancia,
      retraso: retraso ?? this.retraso,
      rutaPartituras: rutaPartituras ?? this.rutaPartituras,
      parametros: parametros ?? this.parametros,
    );
  }
}
