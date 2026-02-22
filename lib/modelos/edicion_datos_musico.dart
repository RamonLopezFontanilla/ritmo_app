import 'package:ritmo_app/modelos/musico_en_banda.dart';
import 'package:ritmo_app/modelos/otros_accesos_musico.dart';

class EdicionDatosMusico {
  final String uid;
  final String nombre;
  final String email;
  final String telefono;
  final DateTime? fechaNacimiento;

  final MusicoEnBanda banda;

  final List<AccesoInstrumento> otrosAccesos;

  // Constructor
  EdicionDatosMusico({
    required this.uid,
    required this.nombre,
    required this.email,
    required this.telefono,
    this.fechaNacimiento,
    required this.banda,
    required this.otrosAccesos,
  });
}
