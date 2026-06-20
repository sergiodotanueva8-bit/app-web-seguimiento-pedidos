package com.mrbarril.pedidos

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "mrbarril/whatsapp"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "abrirWhatsappBusiness") {
                val telefono = call.argument<String>("telefono") ?: ""
                val mensaje = call.argument<String>("mensaje") ?: ""
                result.success(abrirWhatsappBusiness(telefono, mensaje))
            } else {
                result.notImplemented()
            }
        }
    }

    /**
     * Intenta abrir específicamente WhatsApp Business (com.whatsapp.w4b)
     * con un Intent explícito (setPackage), en vez de dejar que Android
     * elija la app por defecto para el link wa.me.
     * Devuelve true si lo logró, false si WhatsApp Business no está
     * instalado (para que el lado Dart haga fallback al wa.me normal,
     * que abrirá el WhatsApp normal si existe).
     */
    private fun abrirWhatsappBusiness(telefono: String, mensaje: String): Boolean {
        return try {
            val uri = Uri.parse("https://wa.me/$telefono?text=${Uri.encode(mensaje)}")
            val intent = Intent(Intent.ACTION_VIEW, uri)
            intent.setPackage("com.whatsapp.w4b")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (e: Exception) {
            // ActivityNotFoundException si WhatsApp Business no está instalado
            false
        }
    }
}
