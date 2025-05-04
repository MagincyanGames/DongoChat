# DonGo Chat

![DonGo Chat Logo](assets/logo.png)

## Descripción del Proyecto

DonGo Chat es una aplicación de mensajería desarrollada con Flutter que permite la comunicación en tiempo real entre usuarios. 

## Tabla de Contenidos

- Instalación
- Arquitectura
- Módulos
- Comandos Útiles
- Estructura del Proyecto
- Características
- Contribución
- Licencia

## Instalación

### Requisitos Previos

- Flutter SDK (Versión 3.7.2 o superior)
- Dart SDK (compatible con Flutter 3.7.2 o superior)
- Git
- Android Studio / VS Code
- Dependencias del proyecto (mongo_dart, provider, firebase_core, etc.)

### Configuración del Entorno

```bash
# Clonar el repositorio
git clone https://github.com/yourname/dongo_chat.git

# Navegar al directorio del proyecto
cd dongo_chat

# Instalar dependencias
flutter pub get
```

### Configuración de Firebase

1. Crea un proyecto en la consola de Firebase
2. Configura tu app para Android/iOS/Web según corresponda
3. Descarga el archivo `google-services.json` para Android o `GoogleService-Info.plist` para iOS
4. Coloca estos archivos en las carpetas correspondientes del proyecto
5. Asegúrate de tener el archivo `credentials.json` en la carpeta assets para las notificaciones

## Arquitectura

[Aquí se incluirá un diagrama y descripción de la arquitectura del proyecto]

## Módulos

### Módulo de Autenticación
[Descripción del módulo de autenticación]

### Módulo de Chat
[Descripción del módulo de chat]

### Base de Datos
[Descripción del manejo de la base de datos]

### API Firebase
[Descripción de la integración con Firebase]

### Tema y UI
[Descripción del sistema de temas y componentes UI]

## Comandos Útiles

### Comandos de Flutter

```bash
# Instalación de dependencias
flutter pub get

# Actualización de dependencias
flutter pub upgrade

# Verificar estado del entorno Flutter
flutter doctor

# Ejecutar la aplicación en modo debug
flutter run

# Ejecutar en un dispositivo específico
flutter run -d [device_id]

# Compilar APK para Android
flutter build apk

# Compilar APK split por ABI (más pequeñas)
flutter build apk --split-per-abi

# Compilar Bundle para Google Play
flutter build appbundle

# Compilar para iOS
flutter build ios

# Compilar para Windows
flutter build windows

# Compilar para macOS
flutter build macos

# Compilar para Web
flutter build web

# Analizar código
flutter analyze

# Ejecutar pruebas
flutter test

# Limpiar la build
flutter clean
```

### Comandos de Git

```bash
# Ver estado del repositorio
git status

# Añadir cambios
git add .

# Commit de cambios
git commit -m "Descripción del cambio"

# Subir cambios al repositorio remoto
git push origin [branch]

# Descargar cambios
git pull origin [branch]

# Crear una nueva rama
git checkout -b [new_branch]

# Cambiar a otra rama
git checkout [branch]

# Generar changelog automático
git-chlog -o CHANGELOG.md
```

### Comandos de Desarrollo

```bash
# Generar código (para json_serializable, built_value, etc.)
flutter pub run build_runner build

# Generar código continuamente
flutter pub run build_runner watch

# Generar iconos de la aplicación
flutter pub run flutter_launcher_icons:main

# Generar splash screen
flutter pub run flutter_native_splash:create

# Actualizar versión de la app
flutter pub run version_updater
```

## Estructura del Proyecto

```
dongo_chat/
├── android/          # Código específico de Android
├── ios/              # Código específico de iOS
├── windows/          # Código específico de Windows
├── lib/              # Código fuente principal
│   ├── api/          # Integración con APIs externas
│   ├── database/     # Manejo de base de datos
│   ├── models/       # Modelos de datos
│   ├── providers/    # Proveedores de estado
│   ├── screens/      # Pantallas de la aplicación
│   │   ├── chat/     # Pantallas de chat
│   │   └── login/    # Pantallas de autenticación
│   ├── theme/        # Definición de temas
│   ├── utils/        # Utilidades y helpers
│   ├── widgets/      # Widgets reutilizables
│   └── main.dart     # Punto de entrada principal
├── test/             # Pruebas unitarias e integración
├── assets/           # Recursos (imágenes, fuentes, etc.)
└── pubspec.yaml      # Configuración del proyecto
```

## Características

- [Lista de características principales]

## Contribución

[Guía de contribución al proyecto]

## Licencia

[Información sobre la licencia]