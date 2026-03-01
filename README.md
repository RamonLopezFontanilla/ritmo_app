# Ritmo App

Aplicación móvil desarrollada en **Flutter** para la gestión integral de bandas de música.

Ritmo App permite administrar músicos, asistencias y temporadas de forma organizada, moderna y en tiempo real.


## Descripción del Proyecto

Ritmo App nace con el objetivo de digitalizar la gestión interna de bandas de música, facilitando la organización tanto para administradores como para músicos.

La aplicación permite:

Para Administradores:
- Publicación de novedades para ser leídas por los músicos.
- Gestión de la plantilla:
   - Operaciones CRUD sobre el músico.
   - Consulta de asistencias.
- Gestión de eventos:
   - Operaciones CRUD sobre el evento.
   - Consultar/añadir repertorio de partituras al evento.
   - Consultar la previsión de asistencias/ausencias de músicos.
   - Pasar lista o corregir las asistencias a un evento.
   - Consultar como llegar a la ubicación del mismo. 
- Gestión de la liquidación (parámetros generales de la temporada y parámetros particulares del músico).
- Gestión de instrumentos/categorías disponibles.
- Gestión de partituras de la banda.
- Gestión de sitios (ubicaciones) para los eventos.

Para Músicos:
   - Consulta de novedades o noticias.
   - Fichar la asistencia al evento activo.
   - Consulta de partituras disponibles.
   - Consulta de eventos pasados, presentes y futuros, pudiendo ver su ubicación y repertorio, y pudiendo informar de su asistencia/ausencia al mismo.
   - Consulta de sus asistencias/ausencias en la temporada seleccionada pudiendo usar filtros de las mismas e imprimir un informe en PDF.
   - Consulta de su liquidación en la temporada seleccionada (si está disponible).

## Arquitectura y Tecnologías

### Frontend
- **Flutter**
- Material Design
- StatefulWidgets + StreamBuilder
- Componentes reutilizables personalizados

### Backend
- Firebase (Firestore en tiempo real)
- Firebase Authentication

### Estructura del Proyecto
El proyecto se ha organizado por capas para mantener:
- Separación de responsabilidades
- Escalabilidad
- Mantenimiento sencillo
- Código limpio y modular
La estructura existente es:<br>
  lib/<br>
  ├── consultas_bd/        --> Acceso y lógica de base de datos<br>
  ├── modelos/             --> Modelos de datos<br>
  ├── ui/                  --> Pantallas principales<br>
  ├── tutoriales/          --> Pasos y explicaciones del recorrido de cada tutorial<br>
  ├── utiles/              --> Widgets reutilizables y helpers<br>

### Autor
Desarrollado como proyecto final del Ciclo de Grado Superior de Desarrollo de Aplicaciones Multiplataforma (en la modalidad de distancia), cursado por **Ramón López Fontanilla**, y dependiente del IES Aguadulce de la Localidad de Roquetas de Mar (Almería). Durante el curso 2025/26.
