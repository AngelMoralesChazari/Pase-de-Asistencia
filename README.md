# 🏫 Pase de Asistencia - Control de Clases y Maestros

Esta aplicación móvil, desarrollada con Flutter y Firebase, está diseñada para facilitar la gestión y consulta de horarios de clases y la toma de asistencia de maestros en tiempo real.

## ✨ Características Principales

*   **Búsqueda Inteligente de Clases:**
    *   Filtra clases por **Edificio**, **Turno (AM/PM)** y **Hora específica**.
    *   Resultados adaptados al **día actual de la semana** (Lunes a Sábado).
    *   Manejo de días no hábiles (ej. Domingo) con mensajes claros.
*   **Agrupación de Horarios Consecutivos:**
    *   Si un maestro tiene clases seguidas en la misma aula y materia, el horario se muestra como un **rango unificado** (ej. "7:00 a 9:30").
*   **Información Detallada del Maestro:**
    *   Al seleccionar un maestro, se despliega un panel con su horario, aula, grupo y materia.
*   **Registro de Asistencia Rápido:**
    *   Botones intuitivos de "Asistió" y "Faltó" para registrar la presencia del maestro. (¡Próximamente con persistencia en Firebase para reportes administrativos!)
*   **Interfaz de Usuario Intuitiva:**
    *   Diseño limpio y fácil de usar para una navegación eficiente.
    *   Indicador de carga visual mientras se obtienen los datos de Firebase.
    *   Los paneles de información se cierran automáticamente al realizar una nueva búsqueda para una mejor experiencia de usuario.
*   **Integración con Firebase:**
    *   Autenticación de usuarios para acceso seguro.
    *   Carga dinámica de filtros (edificios, horas) directamente desde tu base de datos en tiempo real.
    *   Almacenamiento y recuperación eficiente de los datos de clases.

## 🚀 Cómo Empezar

Este proyecto es un punto de partida para una aplicación Flutter. Para ponerlo en marcha en tu entorno local:

### Requisitos

*   [Flutter SDK](https://flutter.dev/docs/get-started/install) instalado.
*   Una cuenta de Firebase y un proyecto configurado con Realtime Database.
*   Configuración de Firebase para tu proyecto Flutter (google-services.json para Android, GoogleService-Info.plist para iOS).

### Pasos de Instalación

1.  **Clona el repositorio:**
    ```bash
    git clone [URL_DE_TU_REPOSITORIO]
    cd pase_de_asistencia
    ```
2.  **Instala las dependencias:**
    ```bash
    flutter pub get
    ```
3.  **Configura Firebase:**
    *   Asegúrate de tener tu archivo `google-services.json` (Android) o `GoogleService-Info.plist` (iOS) en las ubicaciones correctas de tu proyecto.
    *   Verifica que la URL de tu Realtime Database en `lib/screens/home_screen.dart` sea la correcta
      
4.  **Ejecuta la aplicación:**
    ```bash
    flutter run
    ```
