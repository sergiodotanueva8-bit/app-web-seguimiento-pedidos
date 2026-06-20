import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Constantes globales de la app. Las credenciales sensibles
/// se leen desde el archivo `.env` (ver flutter_dotenv en main.dart).
class AppConstants {
  AppConstants._();

  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  static const String nombreApp = 'Mr Barril — Pedidos';
}