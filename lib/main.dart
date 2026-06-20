import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/notificaciones_service.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  await initializeDateFormatting('es_PE');
  await SupabaseService.inicializar();

  // Firebase (push) es solo para Android/iOS. En WEB no se inicializa
  // en absoluto: no hace falta google-services.json/GoogleService-Info,
  // ni pedir permisos de notificación del navegador — el usuario web
  // simplemente ve los pedidos en vivo vía Supabase Realtime.
  if (!kIsWeb) {
    // Firebase es opcional: si no has configurado google-services.json
    // todavía, la app sigue funcionando (solo sin notificaciones push).
    try {
      await Firebase.initializeApp();

      // Tiene que registrarse ANTES de runApp() y a nivel top del archivo
      // (ver notificaciones_service.dart), si no, los mensajes que llegan
      // con la app en background o cerrada no se procesan.
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await NotificacionesService.inicializar();
    } catch (e) {
      debugPrint('Firebase no inicializado todavía (push deshabilitado): $e');
    }
  }

  runApp(const MrBarrilApp());
}

class MrBarrilApp extends StatefulWidget {
  const MrBarrilApp({super.key});

  @override
  State<MrBarrilApp> createState() => _MrBarrilAppState();
}

class _MrBarrilAppState extends State<MrBarrilApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mr Barril — Pedidos',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.tema,
      // Necesario para que el selector de rango de fechas (dashboard,
      // ventas por periodo) se muestre en español en vez de inglés.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'PE'),
        Locale('es'),
      ],
      locale: const Locale('es', 'PE'),
      home: const _PuertaDeEntrada(),
    );
  }
}

/// Decide si mostrar Login o el panel principal, según el estado
/// de sesión de Supabase Auth.
class _PuertaDeEntrada extends StatefulWidget {
  const _PuertaDeEntrada();

  @override
  State<_PuertaDeEntrada> createState() => _PuertaDeEntradaState();
}

class _PuertaDeEntradaState extends State<_PuertaDeEntrada> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService.cambiosSesion,
      builder: (context, snapshot) {
        final logueado = AuthService.estaLogueado;

        if (!logueado) {
          return const LoginScreen();
        }

        return FutureBuilder<Map<String, dynamic>?>(
          future: AuthService.obtenerPerfilTienda(),
          builder: (context, perfilSnapshot) {
            if (perfilSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final perfil = perfilSnapshot.data;
            if (perfil == null) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Tu usuario no está vinculado a ninguna tienda todavía.\n'
                          'Pide al administrador que te agregue en la tabla usuarios_tienda.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }

            // Registrar el token de notificaciones push para este usuario/tienda
            NotificacionesService.registrarTokenDelDispositivo(
              AuthService.usuarioActual!.id,
              perfil['tienda_id'] as String,
            );

            return HomeShell(nombreTienda: perfil['nombre_tienda'] as String? ?? 'Mis pedidos');
          },
        );
      },
    );
  }
}
