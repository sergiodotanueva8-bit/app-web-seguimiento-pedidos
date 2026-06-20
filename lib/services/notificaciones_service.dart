import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'supabase_service.dart';

/// Maneja el registro del token FCM del dispositivo y la
/// visualización de notificaciones cuando la app está en primer plano.
///
/// IMPORTANTE: para que esto funcione necesitas:
///  1. Crear un proyecto en Firebase y agregar tu app Android
///     (com.mrbarril.pedidos) — descarga `google-services.json` y
///     ponlo en android/app/google-services.json
///  2. Haber desplegado la Edge Function `notificar-pedido` y
///     conectado el Database Webhook en Supabase.
///  3. Que la Edge Function mande el payload con la clave
///     "notification" (title/body) y NO solo "data". Si manda
///     solo "data", Android no muestra nada automáticamente con
///     la app cerrada o en background — hace falta manejarlo a
///     mano (ver _firebaseMessagingBackgroundHandler de abajo).
class NotificacionesService {
  static final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  static Future<void> inicializar() async {
    // En WEB no se inicializa nada de esto: ni se piden permisos push
    // del SO, ni se usa flutter_local_notifications (ese plugin es
    // solo para Android/iOS y no compila/funciona en navegador).
    // El usuario de la versión web simplemente ve los pedidos en vivo
    // gracias a Supabase Realtime, sin necesidad de push.
    if (kIsWeb) return;

    // Pide permiso de notificaciones (Android 13+ lo requiere explícitamente)
    final settings = await FirebaseMessaging.instance
        .requestPermission(alert: true, badge: true, sound: true);

    // Útil para depurar: si esto imprime "denied", el usuario rechazó
    // el permiso y NUNCA va a recibir push hasta que lo habilite a mano
    // desde Ajustes del sistema > Apps > Mr Barril Pedidos > Notificaciones.
    // ignore: avoid_print
    print('[Push] Estado de permiso: ${settings.authorizationStatus}');

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _local.initialize(const InitializationSettings(android: androidInit));

    // Registra el handler para cuando la app está en BACKGROUND o
    // CERRADA. Debe ser una función de nivel superior (ver abajo) y
    // se registra una sola vez, idealmente apenas se inicializa Firebase
    // en main(). Lo dejamos también aquí por si acaso, no hace daño
    // registrarlo dos veces.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Notificación en PRIMER PLANO (Android no la muestra sola por defecto
    // cuando la app está abierta, por eso se reconstruye con flutter_local_notifications)
    FirebaseMessaging.onMessage.listen((RemoteMessage mensaje) {
      _mostrarNotificacionLocal(mensaje);
    });
  }

  static Future<void> _mostrarNotificacionLocal(RemoteMessage mensaje) async {
    // Soporta tanto mensajes con "notification" como mensajes
    // "data-only" (en ese caso arma el título/cuerpo desde data).
    final notif = mensaje.notification;
    final titulo = notif?.title ?? mensaje.data['title'] ?? 'Nuevo pedido';
    final cuerpo = notif?.body ?? mensaje.data['body'] ?? 'Tienes un pedido nuevo';

    await _local.show(
      mensaje.hashCode,
      titulo,
      cuerpo,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'pedidos_nuevos',
          'Pedidos nuevos',
          channelDescription: 'Notificaciones de pedidos nuevos',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  /// Registra (o actualiza) el token FCM del dispositivo actual,
  /// asociado al usuario y tienda logueados. Llamar justo después
  /// de iniciar sesión.
  static Future<void> registrarTokenDelDispositivo(String userId, String tiendaId) async {
    // En web no hay token FCM que registrar (no se inicializó push).
    if (kIsWeb) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) {
      // ignore: avoid_print
      print('[Push] No se pudo obtener el token FCM del dispositivo');
      return;
    }

    await SupabaseService.client.from('push_tokens').upsert(
      {
        'user_id': userId,
        'tienda_id': tiendaId,
        'token': token,
        'plataforma': 'android',
      },
      onConflict: 'token',
    );

    // Si el token se renueva (puede pasar), lo actualizamos también
    FirebaseMessaging.instance.onTokenRefresh.listen((nuevoToken) async {
      await SupabaseService.client.from('push_tokens').upsert(
        {
          'user_id': userId,
          'tienda_id': tiendaId,
          'token': nuevoToken,
          'plataforma': 'android',
        },
        onConflict: 'token',
      );
    });
  }
}

/// Handler de mensajes en BACKGROUND / app cerrada.
/// Tiene que ser una función de nivel superior (top-level) o estática,
/// marcada con @pragma('vm:entry-point'), porque Android la ejecuta
/// en un isolate aparte, separado del resto de la app.
///
/// Si tu Edge Function manda el push con "notification: {title, body}",
/// Android YA lo muestra automáticamente en la barra de notificaciones
/// sin necesidad de este handler. Este handler es necesario sobre todo
/// si el payload es "data-only", o si más adelante quieres hacer algo
/// extra (ej. actualizar un badge, loggear, etc).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage mensaje) async {
  // No hace falta Firebase.initializeApp() aquí en versiones recientes
  // de firebase_messaging si el plugin nativo ya está configurado
  // (google-services.json presente). Lo dejamos vacío a propósito:
  // si tu Edge Function ya manda "notification", este handler no
  // necesita hacer nada extra, Android se encarga solo.
}
