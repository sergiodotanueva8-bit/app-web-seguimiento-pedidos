import 'package:flutter/material.dart';

/// Paleta y tema centralizados. Cambia aquí los colores de marca
/// y se reflejan en toda la app sin tocar las pantallas.
class AppTheme {
  AppTheme._();

  static const Color primario = Color(0xFF1A3C6E); // azul Mr Barril
  static const Color acento = Color(0xFFE8A33D); // dorado/ámbar
  static const Color fondo = Color(0xFFF5F6FA);
  static const Color superficie = Color(0xFFFFFFFF);
  static const Color exito = Color(0xFF2E9E5B);
  static const Color advertencia = Color(0xFFE0A100);
  static const Color peligro = Color(0xFFD64545);
  static const Color textoSecundario = Color(0xFF6B7280);

  static ThemeData get tema {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: fondo,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primario,
        primary: primario,
        secondary: acento,
        surface: superficie,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primario,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        color: superficie,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primario,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF0F1F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      fontFamily: 'Roboto',
    );
  }

  /// Colores por estado de pago
  static Color colorEstadoPago(String estado) {
    switch (estado) {
      case 'pagado':
        return exito;
      case 'no_cobrado':
        return peligro;
      case 'cancelado':
        return textoSecundario;
      default: // pendiente
        return advertencia;
    }
  }

  /// Colores por estado de envío (mismo set de colores para ambos flujos)
  static Color colorEstadoEnvio(String estado) {
    switch (estado) {
      case 'entregado':
      case 'en_destino':
        return exito;
      case 'en_camino':
      case 'en_transito':
        return primario;
      case 'archivado':
        return textoSecundario;
      case 'cancelado':
        return peligro;
      default: // nuevo, en_origen
        return advertencia;
    }
  }
}