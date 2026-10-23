# BarroControl · Flutter

Frontend con Flutter y Dart para `Backend-Punto-de-Venta` (Spring Boot).
La pantalla inicial consulta `GET /api/health`, muestra el resultado y permite
reintentar. Productos, autenticación, ventas e inventario aún requieren sus
endpoints de negocio; no se simulan operaciones ni se conecta Flutter a PostgreSQL.

## Ejecutar desde PowerShell

1. Inicia el backend con Java 21 y las variables de PostgreSQL indicadas en su README.
2. Desde esta carpeta ejecuta:

```powershell
.\scripts\run.ps1
```

Usa Chrome y el puerto **5173**, permitido por el CORS del backend.
También puedes usar `-Target edge`, `-Target windows` o `-Target android`.
Android necesita Android SDK y un emulador iniciado; Windows necesita Visual Studio
con las herramientas de desarrollo de escritorio C++. iOS se compila desde macOS
con Xcode. El SDK local está en `../.tools/flutter`; si no existe se usa Flutter
del PATH. La carpeta `.tools` es local y no forma parte de ninguno de los repositorios.

Comando equivalente si Flutter está en tu PATH:

```powershell
flutter pub get
flutter run -d chrome --web-port=5173 --dart-define=API_BASE_URL=http://localhost:8080
```

## Dirección de la API

| Plataforma | URL predeterminada |
| --- | --- |
| Web y escritorio | `http://localhost:8080` |
| Emulador Android estándar | `http://10.0.2.2:8080` |
| Celular físico | Usa la IP LAN de la computadora con el backend |

Para un celular conectado a la misma red Wi-Fi:

```powershell
.\scripts\run.ps1 -Target android -ApiBaseUrl http://192.168.1.100:8080
```

Sustituye la IP por la de tu computadora y permite el puerto 8080 en su firewall
si hace falta. En un celular `localhost` es el propio celular. El permiso HTTP
de Android se habilita únicamente en debug; para distribución usa una API HTTPS.

Para una API desplegada:

```powershell
.\scripts\run.ps1 -ApiBaseUrl https://tu-backend.example.com
```

En el backend configura `APP_CORS_ALLOWED_ORIGINS` con los orígenes del frontend
separados por comas. Por defecto solo se aceptan `http://localhost:5173` y
`http://127.0.0.1:5173`. La URL de API es pública: no pongas credenciales de
PostgreSQL ni secretos en `--dart-define`.

## Arquitectura hexagonal: puertos y adaptadores

Cada funcionalidad se organiza en `domain`, `application` e `infrastructure`.
Las dependencias apuntan al interior. El dominio no importa Flutter, HTTP ni
infraestructura. La aplicación define los puertos y ejecuta los casos de uso.

En `lib/features/connection`:

- `domain`: `BackendHealth` y `ConnectionFailure`, tipos Dart independientes.
- `application/ports/inbound`: `CheckConnectionUseCase`, contrato para la UI.
- `application/services`: `CheckConnection`, implementación del caso de uso.
- `application/ports/outbound`: `HealthGateway`, contrato que requiere el caso de uso.
- `infrastructure/adapters/inbound/flutter`: `ConnectionPage`, adaptador de entrada.
- `infrastructure/adapters/outbound/http`: `HttpHealthGateway`, adaptador de salida
  que implementa `HealthGateway` y convierte JSON/errores HTTP a tipos del dominio.

`lib/main.dart` ensambla las implementaciones mediante inyección por constructor.
Solo este punto de composición conoce simultáneamente las implementaciones de
aplicación e infraestructura. `lib/core/infrastructure` contiene la configuración
de plataforma y el cliente HTTP compartido. La pantalla recibe el puerto de entrada;
no crea clientes HTTP ni conoce el adaptador de salida.

Las pruebas del caso de uso sustituyen el puerto de salida por una implementación
en memoria. Las de pantalla sustituyen el puerto de entrada sin usar HTTP.
Las del adaptador HTTP comprueban el contrato REST y la traducción de errores.

Para productos, ventas e inventario, conserva esta organización por funcionalidad.
Agrega únicamente los puertos y adaptadores que necesite cada caso de uso.
No coloques llamadas HTTP en widgets ni dependencias Flutter en el dominio.

## Verificación

```powershell
flutter analyze
flutter test
flutter build web
```

El endpoint confirma que Spring responde HTTP; no consulta la base de datos.
La aplicación Spring sí necesita su configuración PostgreSQL para arrancar.

Referencias: [Networking](https://docs.flutter.dev/data-and-backend/networking)
y [crear un proyecto](https://docs.flutter.dev/reference/create-new-app).
