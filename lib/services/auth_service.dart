import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AuthService {
  static SupabaseClient get _db => SupabaseService.client;

  static Stream<AuthState> get cambiosSesion => _db.auth.onAuthStateChange;

  static User? get usuarioActual => _db.auth.currentUser;

  static bool get estaLogueado => usuarioActual != null;

  static Future<void> iniciarSesion({required String email, required String password}) async {
    await _db.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> cerrarSesion() async {
    await _db.auth.signOut();
  }

  /// Devuelve { 'tienda_id': ..., 'rol': ..., 'nombre_tienda': ... }
  /// para el usuario logueado, usando la relación usuarios_tienda → tiendas.
  static Future<Map<String, dynamic>?> obtenerPerfilTienda() async {
    final userId = usuarioActual?.id;
    if (userId == null) return null;

    final fila = await _db
        .from('usuarios_tienda')
        .select('rol, tienda_id, tiendas(nombre, slug, whatsapp)')
        .eq('user_id', userId)
        .maybeSingle();

    if (fila == null) return null;

    final tienda = fila['tiendas'] as Map<String, dynamic>?;
    return {
      'rol': fila['rol'],
      'tienda_id': fila['tienda_id'],
      'nombre_tienda': tienda?['nombre'],
      'slug_tienda': tienda?['slug'],
      'whatsapp_tienda': tienda?['whatsapp'],
    };
  }
}
