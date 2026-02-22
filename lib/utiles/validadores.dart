/// **********************************************************
/// Valida que el email tenga un formato básico válido
/// **********************************************************
bool esEmailValido(String email) {
  final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  return regex.hasMatch(email);
}

/// **********************************************************
/// Valida que el teléfono tenga un formato básico válido
/// **********************************************************
bool esTelefonoValido(String telefono) {
  final limpio = telefono.replaceAll(RegExp(r'\s+'), '');
  return RegExp(r'^\+?\d{9,15}$').hasMatch(limpio);
}

/// **********************************************************
/// Valida que el DNI/CIF tenga un formato básico válido
/// **********************************************************
bool esDniValido(String dni) {
  final regex = RegExp(r'^\d{8}[A-Z]$');
  if (!regex.hasMatch(dni)) return false;

  const letras = 'TRWAGMYFPDXBNJZSQVHLCKE';
  final numero = int.parse(dni.substring(0, 8));
  final letra = dni[8];

  return letras[numero % 23] == letra;
}

/// **********************************************************
/// Valida que el NIE tenga un formato básico válido
/// **********************************************************
bool esNieValido(String nie) {
  final regex = RegExp(r'^[XYZ]\d{7}[A-Z]$');
  if (!regex.hasMatch(nie)) return false;

  const letras = 'TRWAGMYFPDXBNJZSQVHLCKE';

  final mapa = {'X': '0', 'Y': '1', 'Z': '2'};
  final numero = int.parse(mapa[nie[0]]! + nie.substring(1, 8));
  final letra = nie[8];

  return letras[numero % 23] == letra;
}

/// **********************************************************
/// Valida que el código postal tenga un formato básico válido
/// **********************************************************
bool esCodigoPostalValido(String cp) {
  if (!RegExp(r'^\d{5}$').hasMatch(cp)) return false;

  final provincia = int.parse(cp.substring(0, 2));
  return provincia >= 1 && provincia <= 52;
}
