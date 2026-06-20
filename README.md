# Mr Barril — App de gestión de pedidos (Flutter / Android)

App multi-tienda para gestionar pedidos: lista, detalle, cambio de estados
(pago y envío), copiar mensaje + abrir WhatsApp con un tap, dashboard con
gráficos y notificaciones push de pedidos nuevos.

## 1. Requisitos previos

- Flutter SDK instalado (3.22 o superior): https://docs.flutter.dev/get-started/install
- Android Studio (para el SDK de Android y para generar el APK firmado)
- Una cuenta de Firebase (gratis) si quieres notificaciones push

Verifica que todo esté bien instalado:
```bash
flutter doctor
```

## 2. Configurar las credenciales de Supabase

Edita el archivo `.env` en la raíz de este proyecto (ya viene con los datos
de tu proyecto actual, verifica que sean correctos):
```
SUPABASE_URL=https://TU-PROYECTO.supabase.co
SUPABASE_ANON_KEY=tu-anon-key-publica
```

## 3. Instalar dependencias

```bash
cd flutter_app
flutter pub get
```

La primera vez, Flutter va a generar `android/local.properties`
automáticamente con la ruta de tu SDK. Si no lo hace, créalo a mano
copiando `android/local.properties.example` y completando las rutas.

## 4. Configurar Firebase (para notificaciones push)

1. Ve a https://console.firebase.google.com y crea un proyecto (gratis).
2. Agrega una app Android con el package name exacto: `com.mrbarril.pedidos`
3. Descarga el archivo `google-services.json` que te da Firebase.
4. Remplaza el archivo placeholder que ya existe en:
   `android/app/google-services.json`
5. En Firebase Console → Configuración del proyecto → Cuentas de servicio,
   genera una clave privada nueva (JSON). La vas a necesitar para la
   Edge Function de Supabase que envía las notificaciones — ver
   `../supabase/edge-functions/notificar-pedido/index.ts`.

Si por ahora NO quieres configurar Firebase, no pasa nada: la app
compila y funciona igual, solo no llegarán notificaciones push hasta
que reemplaces el `google-services.json`.

## 5. Probar la app mientras desarrollas

Con tu celular Android conectado por USB (con "Depuración USB" activada)
o un emulador corriendo:
```bash
flutter run
```

## 6. Generar el APK para instalar directo en los celulares

```bash
flutter build apk --release
```

El archivo queda en:
```
build/app/outputs/flutter-apk/app-release.apk
```

Pásalo al celular (WhatsApp, Drive, cable USB, lo que prefieras) y
ábrelo para instalar. Android pedirá permitir "instalar apps de
orígenes desconocidos" la primera vez — es normal, dale aceptar.

> Nota sobre la firma: este proyecto viene configurado para firmar el
> `release` con la misma clave de debug, así puedes generar APKs sin
> fricción desde el día uno. Para producción más formal a futuro
> (o si algún día subes a Play Store), genera tu propio keystore con
> `keytool` y actualiza `android/app/build.gradle` → `signingConfigs`.

## 7. Crear usuarios (tiendas) que pueden entrar a la app

Esto se hace desde el dashboard de Supabase, no desde la app (por
diseño: solo tú, como super-admin, das de alta tiendas nuevas).
Ver la guía completa en `../supabase/GUIA_ALTA_TIENDA.md`.

## 8. Estructura del proyecto

```
lib/
  core/        -> constantes, tema visual, lógica de estados (Lima/Provincia)
  models/      -> Pedido, Tienda, ResumenDashboard
  services/    -> Supabase, Auth, Pedidos (CRUD + realtime), Notificaciones push
  screens/     -> Login, Lista de pedidos, Detalle, Dashboard, Shell de navegación
  widgets/     -> Badge de estado, tarjeta de pedido, selector de estado
```

Cada pantalla y cada módulo vive en su propio archivo: si más adelante
quieres agregar una pantalla nueva (por ejemplo "Clientes recurrentes"),
se agrega como un archivo más en `screens/` sin tocar las existentes.

## 9. iOS (a futuro)

El mismo código Dart funciona para iOS. Mientras no compres la cuenta
de Apple Developer (US$99/año), puedes probar la app gratis en iPhone
usando la app "Expo Go"... espera, esa es para Expo — en Flutter el
equivalente gratuito es ejecutar `flutter run` con tu iPhone conectado
a una Mac con Xcode (igual no requiere pago para *probar*, solo para
*distribuir* sin cable). Para una build standalone instalable en
iPhones sin Mac/cable permanentemente, sí necesitas la cuenta de Apple
Developer — eso no cambia, es una política de Apple.
