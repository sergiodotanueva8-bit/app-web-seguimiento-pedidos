import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre un chat de WhatsApp con el cliente.
///
/// En Android intenta abrir específicamente **WhatsApp Business**
/// (com.whatsapp.w4b) usando un canal nativo (ver MainActivity.kt).
/// Si WhatsApp Business no está instalado, o estamos en iOS/Web,
/// cae de vuelta al link genérico `wa.me`.
///
/// IMPORTANTE sobre iOS: Apple no permite elegir qué app abre un
/// link cuando hay dos apps registradas para el mismo esquema/dominio
/// universal (WhatsApp normal y Business comparten `wa.me` y
/// `whatsapp://`). No existe una forma pública de forzar Business
/// específicamente en iOS — el sistema decide. Si en tu iPhone usas
/// solo WhatsApp Business (sin tener instalado el normal), igual
/// abrirá correctamente porque es la única app que puede manejarlo.
class WhatsappService {
  static const _channel = MethodChannel('mrbarril/whatsapp');

  static Future<void> abrirChat({required String telefono, String mensaje = ''}) async {
    final telefonoLimpio = telefono.replaceAll(RegExp(r'[^0-9]'), '');

    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final abierto = await _channel.invokeMethod<bool>('abrirWhatsappBusiness', {
          'telefono': telefonoLimpio,
          'mensaje': mensaje,
        });
        if (abierto == true) return;
      } on PlatformException {
        // Seguimos al fallback de abajo
      } on MissingPluginException {
        // Canal no registrado todavía (ej. hot reload viejo): fallback
      }
    }

    final query = mensaje.isNotEmpty ? '?text=${Uri.encodeComponent(mensaje)}' : '';
    final uri = Uri.parse('https://wa.me/$telefonoLimpio$query');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
