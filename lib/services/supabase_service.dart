import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';

/// Wrapper simple sobre el cliente de Supabase, para no repetir
/// `Supabase.instance.client` por toda la app.
class SupabaseService {
  static Future<void> inicializar() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      publishableKey: AppConstants.supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}