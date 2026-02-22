import 'dart:math';

import 'package:flutter/material.dart';

/// *******************************************************
///          -- Cuadro de texto unificado --
/// *******************************************************
class AppInput extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final bool readOnly;
  final Widget? suffixIcon;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final TextInputType keyboardType;
  final int maxLines;
  final bool enabled;
  final String? Function(String?)? validator;
  final bool obscureText;
  final String? permiso;
  final bool Function(String permiso)? tienePermiso;

  const AppInput({
    super.key,
    required this.label,
    this.controller,
    this.readOnly = false,
    this.suffixIcon,
    this.onTap,
    this.onChanged,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.enabled = true,
    this.obscureText = false,
    this.permiso,
    this.tienePermiso,
  });

  bool get esEditable {
    if (permiso == null || tienePermiso == null) return enabled;
    return tienePermiso!(permiso!);
  }

  @override
  Widget build(BuildContext context) {
    final editable = esEditable;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly || !editable,
        onTap: editable ? onTap : null,
        obscureText: obscureText,
        keyboardType: keyboardType,
        maxLines: maxLines,
        onChanged: onChanged,
        validator: validator,
        enabled: enabled,
        style: TextStyle(color: editable ? Colors.black87 : Colors.grey.shade600),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: editable ? Colors.white : Colors.grey.shade200,
          suffixIcon: !editable ? const Icon(Icons.lock, size: 16, color: Colors.grey) : suffixIcon,
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }
}

/// *******************************************************
///       -- Cuadro con lista desplegable unificado --
/// *******************************************************
class AppDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final FormFieldValidator<T?>? validator;

  const AppDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        items: items,
        onChanged: onChanged,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }
}

/// *******************************************************
///            -- Cuadro de búsqueda unificado --
/// *******************************************************
class CuadroBusqueda extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final double borderRadius;
  final IconData prefixIcon;

  const CuadroBusqueda({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Buscar...',
    this.borderRadius = 12,
    this.prefixIcon = Icons.search,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(prefixIcon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(borderRadius)),
      ),
      onChanged: onChanged,
    );
  }
}

/// *******************************************************
///            -- Botón inferior Guardar unificado--
/// *******************************************************
class BotonGuardar extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;
  const BotonGuardar({super.key, required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.save, size: 18),
            label: const Text("GUARDAR", style: TextStyle(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: enabled ? onPressed : null,
          ),
        ),
      ),
    );
  }
}

/// *******************************************************
///            -- Botón a Pantalla unificado --
/// *******************************************************
class BotonAPantalla extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final IconData icon;

  const BotonAPantalla({super.key, required this.onPressed, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: Icon(icon, size: 18),
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

/// *******************************************************
///                 -- Etiqueta unificada --
/// *******************************************************
class CampoEtiqueta extends StatelessWidget {
  final String label;
  final String value;

  const CampoEtiqueta({super.key, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

/// *******************************************************
///    --- Mostrar diálogo de confirmación unificado ---
/// *******************************************************
Future<bool> mostrarDialogoConfirmacion({
  required BuildContext context,
  required String titulo,
  required String mensaje,
  IconData icono = Icons.warning_amber_rounded,
  Color colorIcono = Colors.red,
  String textoConfirmar = 'Eliminar',
  String textoCancelar = 'Cancelar',
}) async {
  final resultado = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 48, color: colorIcono),
            const SizedBox(height: 12),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        actions: [
          SizedBox(
            height: 40,
            child: TextButton(
              style: TextButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
              onPressed: () => Navigator.pop(context, false),
              child: Text(textoCancelar),
            ),
          ),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorIcono,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(textoConfirmar),
            ),
          ),
        ],
      );
    },
  );

  return resultado ?? false;
}

/// *******************************************************
///          --- Minicalendario para tarjetas ---
/// *******************************************************
class MiniCalendario extends StatelessWidget {
  final DateTime fecha;
  final Color colorCalendario;

  const MiniCalendario({super.key, required this.fecha, required this.colorCalendario});

  static const List<String> meses = [
    "ENE",
    "FEB",
    "MAR",
    "ABR",
    "MAY",
    "JUN",
    "JUL",
    "AGO",
    "SEP",
    "OCT",
    "NOV",
    "DIC",
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: colorCalendario,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
            ),
            child: Text(
              meses[fecha.month - 1],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                fecha.day.toString(),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// *******************************************************
///          --- Mini Avatar para tarjetas ---
/// *******************************************************
class MiniAvatar extends StatelessWidget {
  final String inicial;

  const MiniAvatar({super.key, required this.inicial});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Center(
        child: Text(inicial, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

/// *******************************************************
///          --- Tarjeta para listas Unificada ---
/// *******************************************************
class Tarjeta extends StatelessWidget {
  final IconData? icono;
  final Widget? iconoWidget;
  final Color colorIcono;
  final String titulo;
  final String? subtitulo;
  final Widget? subtituloWidget;
  final VoidCallback? onTap;

  const Tarjeta({
    super.key,
    this.icono,
    this.iconoWidget,
    this.colorIcono = Colors.indigo,
    required this.titulo,
    this.subtitulo,
    this.subtituloWidget,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: colorIcono, width: 6)),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Row(
          children: [
            // CUADRO DEL ICONO
            Container(
              width: iconoWidget is MiniAvatar ? 40 : 50,
              height: iconoWidget is MiniCalendario ? 60 : 50,
              decoration: BoxDecoration(color: colorIcono, borderRadius: BorderRadius.circular(8)),
              child: buildIcono(),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  if (subtituloWidget != null)
                    subtituloWidget!
                  else if (subtitulo != null)
                    Text(subtitulo!, style: const TextStyle(color: Colors.black54, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// *******************************************************
  ///          --- Icono ---
  /// *******************************************************
  Widget buildIcono() {
    if (iconoWidget != null) {
      // Widget personalizado (MiniCalendario, MiniAvatar…)
      return Center(child: iconoWidget!);
    }

    // Icono fijo por defecto
    return Icon(icono ?? Icons.event, color: Colors.white, size: 28);
  }
}

/// *******************************************************
///          --- Cuadro Diálogo base ---
/// *******************************************************
class DialogoBase extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final List<Widget> children;

  const DialogoBase({super.key, required this.icono, required this.titulo, required this.children});

  @override
  Widget build(BuildContext context) {
    final anchoPantalla = MediaQuery.of(context).size.width;

    return SizedBox(
      width: min(anchoPantalla, 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 48, color: Colors.indigo),
          const SizedBox(height: 8),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}

/// *******************************************************
///          --- Botón primario para Diálogo ---
/// *******************************************************
class BotonPrimarioDialogo extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final IconData? icon;

  const BotonPrimarioDialogo({super.key, required this.onPressed, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: icon != null ? Icon(icon, size: 18) : const SizedBox.shrink(),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          elevation: 1,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        onPressed: onPressed,
      ),
    );
  }
}

/// *******************************************
///          --- Tarjeta Fichar ---
/// *******************************************
Widget tarjetaFichar({
  required DateTime fecha,
  required String titulo,
  required String horario,
  required String lugar,
  VoidCallback? onTap,
  Color fondo = const Color.fromARGB(255, 201, 200, 200),
  required GlobalKey<State<StatefulWidget>> key,
}) {
  final bool activo = fondo != const Color.fromARGB(255, 201, 200, 200);

  return InkWell(
    onTap: onTap,
    child: Container(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Colors.blueGrey, blurRadius: 6, offset: Offset(2, 3))],
      ),
      child: Row(
        children: [
          // --- USANDO MINI CALENDARIO ---
          MiniCalendario(fecha: fecha, colorCalendario: activo ? Colors.red : Colors.blueGrey),

          const SizedBox(width: 12),

          // --- Texto del evento ---
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: activo ? Colors.white : Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(horario, style: TextStyle(color: activo ? Colors.white : Colors.black, fontSize: 14)),
                Text(lugar, style: TextStyle(color: activo ? Colors.white : Colors.black, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// ***********************************************************************************
///      --- Botón de opciones Gestión para administradore y músicos unificado ---
/// ***********************************************************************************
class BotonAccion extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Key? widgetKey;

  const BotonAccion({super.key, required this.icon, required this.label, required this.onTap, this.widgetKey});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      key: widgetKey,
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 250, 250, 250),
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Colors.blueAccent, Colors.lightBlueAccent]),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// ***********************************************
///  --- Título de sección para página de menú---
/// ***********************************************
class TituloApartado extends StatelessWidget {
  final String text;
  const TituloApartado(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
    );
  }
}

/// ***********************************************
///  --- Mensajes de confirmación o error ---
/// ***********************************************
extension SnackBarExtension on BuildContext {
  void mostrarSnack(String texto, {required bool esCorrecto}) {
    final messenger = ScaffoldMessenger.of(this);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(texto), backgroundColor: esCorrecto ? Colors.green.shade600 : Colors.red.shade600),
      );
  }
}
